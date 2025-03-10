//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/06/2022.
//

import Foundation
import CoreData

class CoreDataManager {
  private let coreDataStack: CoreDataStack
  private let backgroundContext: NSManagedObjectContext

  init(coreDataStack: CoreDataStack = CoreDataStack()) {
    self.coreDataStack = coreDataStack
    backgroundContext = coreDataStack.persistentContainer.newBackgroundContext()
  }

  func saveEventData(
    _ eventData: EventData,
    completion: ((ManagedEventData) -> Void)? = nil
  ) {
    backgroundContext.perform { [weak self] in
      guard let self = self else {
        return
      }
      let data = try? JSONEncoder().encode(eventData.parameters)
      guard let managedEventData = ManagedEventData(
        context: self.backgroundContext,
        id: eventData.id,
        createdAt: eventData.createdAt,
        name: eventData.name,
        parameters: data ?? Data()
      ) else {
        return
      }

      self.coreDataStack.saveContext(self.backgroundContext) {
        completion?(managedEventData)
      }
    }
  }

  func save(
    triggerRuleOccurrence ruleOccurence: TriggerRuleOccurrence,
    completion: ((ManagedTriggerRuleOccurrence) -> Void)? = nil
  ) {
    backgroundContext.perform { [weak self] in
      guard let self = self else {
        return
      }
      guard let managedRuleOccurrence = ManagedTriggerRuleOccurrence(
        context: self.backgroundContext,
        createdAt: Date(),
        occurrenceKey: ruleOccurence.key
      ) else {
        return
      }

      self.coreDataStack.saveContext(self.backgroundContext) {
        completion?(managedRuleOccurrence)
      }
    }
  }

  func deleteAllEntities() {
    let eventDataRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
      entityName: ManagedEventData.entityName
    )
    let deleteEventDataRequest = NSBatchDeleteRequest(fetchRequest: eventDataRequest)

    let occurrenceRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
      entityName: ManagedTriggerRuleOccurrence.entityName
    )
    let deleteOccurrenceRequest = NSBatchDeleteRequest(fetchRequest: occurrenceRequest)

    backgroundContext.performAndWait { [weak self] in
      guard let self = self else {
        return
      }
      do {
        try self.backgroundContext.executeAndMergeChanges(using: deleteEventDataRequest)
        try self.backgroundContext.executeAndMergeChanges(using: deleteOccurrenceRequest)
      } catch {
        Logger.debug(
          logLevel: .error,
          scope: .coreData,
          message: "Could not delete core data.",
          error: error
        )
      }
    }
  }

  func countTriggerRuleOccurrences(
    for ruleOccurrence: TriggerRuleOccurrence
  ) -> Int {
    let fetchRequest = ManagedTriggerRuleOccurrence.fetchRequest()
    fetchRequest.fetchLimit = ruleOccurrence.maxCount

    switch ruleOccurrence.interval {
    case .minutes(let minutes):
      guard let date = Calendar.current.date(
        byAdding: .minute,
        value: -minutes,
        to: Date()
      ) else {
        Logger.debug(
          logLevel: .error,
          scope: .coreData,
          message: "Calendar couldn't calculate date by adding \(minutes) minutes and returned nil."
        )
        return .max
      }
      fetchRequest.predicate = NSPredicate(
        format: "createdAt >= %@ AND occurrenceKey == %@",
        date as NSDate,
        ruleOccurrence.key
      )
      return coreDataStack.count(for: fetchRequest)
    case .infinity:
      fetchRequest.predicate = NSPredicate(format: "occurrenceKey == %@", ruleOccurrence.key)
      return coreDataStack.count(for: fetchRequest)
    }
  }
}
