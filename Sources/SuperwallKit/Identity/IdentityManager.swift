//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//

// ********************** How to use this class **********************
//
// For variables and functions that could have race conditions, a private
// variable/function is created with an underscore. Access to this is
// synchronised via a dispatch queue. When writing, use queue.async, when
// reading use a computed var with a queue.sync block. You do not need to
// use the queue during init.
//
// *******************************************************************

import Foundation
import Combine

class IdentityManager {
  /// The appUserId or the aliasId, depending on whether the user is logged in
  /// or not.
  var userId: String {
    return queue.sync { [unowned self] in
      return self.appUserId ?? self.aliasId
    }
  }

  /// The userId passed to the SDK.
  var appUserId: String? {
    queue.sync { [unowned self] in
      return self._appUserId
    }
  }
  private var _appUserId: String? {
    didSet {
      saveIds()
    }
  }

  /// User attributes that belong to the user.
  var userAttributes: [String: Any] {
    queue.sync { [unowned self] in
      return self._userAttributes
    }
  }
  private var _userAttributes: [String: Any] = [:]

  /// The randomly generated aliasId used to identify an anonymous user.
  var aliasId: String {
    queue.sync { [unowned self] in
      return self._aliasId
    }
  }
  private var _aliasId: String {
    didSet {
      saveIds()
    }
  }

  /// Indicates whether the user has logged in or not.
  var isLoggedIn: Bool {
    return appUserId != nil
  }

  /// A Publisher that only emits when `identitySubject` is `true`. When `true`,
  /// it means the SDK is ready to fire triggers.
  var hasIdentity: AnyPublisher<Bool, Error> {
    identitySubject
      .filter { $0 == true }
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }


  /// Indicates whether the identity (i.e. anonymous or logged in with
  /// assignments) has been retrieved.
  ///
  /// When `false`, the SDK is unable to present paywalls.
  private let identitySubject = CurrentValueSubject<Bool, Never>(false)
  private let queue = DispatchQueue(label: "com.superwall.identitymanager")

  private unowned let deviceHelper: DeviceHelper
  private unowned let storage: Storage
  private unowned let configManager: ConfigManager

  init(
    deviceHelper: DeviceHelper,
    storage: Storage,
    configManager: ConfigManager
  ) {
    self.deviceHelper = deviceHelper
    self.storage = storage
    self.configManager = configManager
    self._appUserId = storage.get(AppUserId.self)
    self._aliasId = storage.get(AliasId.self) ?? IdentityLogic.generateAlias()
    self._userAttributes = storage.get(UserAttributes.self) ?? [:]
  }

  /// Checks for static config upgrade before setting identity.
  func configure() async {
    let neverCalledStaticConfig = storage.neverCalledStaticConfig
    let isFirstAppOpen = !(storage.get(DidTrackFirstSeen.self) ?? false)

    if IdentityLogic.shouldGetAssignments(
      isLoggedIn: isLoggedIn,
      neverCalledStaticConfig: neverCalledStaticConfig,
      isFirstAppOpen: isFirstAppOpen
    ) {
      await configManager.getAssignments()
    }

    didSetIdentity()
  }

  /// Creates an account and may or may not wait for assignments before
  /// returning.
  func identify(
    userId: String,
    options: IdentityOptions?
  ) {
    guard let userId = IdentityLogic.sanitize(userId: userId) else {
      Logger.debug(
        logLevel: .error,
        scope: .identityManager,
        message: "The provided userId was empty."
      )
      return
    }

    queue.async { [weak self] in
      guard let self = self else {
        return
      }
      // If they're sending the same userId as before, then they're
      // already logged in.
      if self._appUserId == userId {
        return
      }

      self.identitySubject.send(false)

      let oldUserId = self._appUserId

      // If user already logged in but identifying with a
      // different userId, reset everything first.
      if oldUserId != nil,
        userId != oldUserId {
        Superwall.shared.reset(duringIdentify: true)
      }

      self._appUserId = userId

      func getAssignmentsAsync() {
        Task.detached {
          await self.configManager.getAssignments()
        }
        self.didSetIdentity()
      }

      // If they have set restore paywall assignments to true,
      // Wait for assignments before setting identity. Otherwise,
      // get assignments in the background.

      if let options = options {
        if options.restorePaywallAssignments {
          Task {
            await self.configManager.getAssignments()
            self.didSetIdentity()
          }
        } else {
          getAssignmentsAsync()
        }
      } else {
        getAssignmentsAsync()
      }
    }
  }

  /// Sends a `true` value to the `identitySubject` in order to fire
  /// triggers after reset.
  func didSetIdentity() {
    identitySubject.send(true)
  }

  /// Saves the aliasId and appUserId to storage and user attributes.
  private func saveIds() {
    // This is not wrapped in an async block because is
    // called from the didSet of vars, who are already
    // being set within the queue.
    if let appUserId = _appUserId {
      storage.save(appUserId, forType: AppUserId.self)
    }

    storage.save(_aliasId, forType: AliasId.self)

    var newUserAttributes = [
      "aliasId": _aliasId
    ]
    if let appUserId = _appUserId {
      newUserAttributes["appUserId"] = appUserId
    }

    mergeUserAttributes(newUserAttributes)
  }
}

// MARK: - Reset
extension IdentityManager {
  /// Clears all stored user-specific variables.
  ///
  /// - Parameters:
  ///   - duringIdentify: A boolean that indicates whether the reset
  ///   call is happening during a call to `identify(userId:)`. If `fasle`,
  ///   this happens
  func reset(duringIdentify: Bool) {
    identitySubject.send(false)

    if duringIdentify {
      self._reset()
    } else {
      queue.async { [weak self] in
        self?._reset()
        self?.didSetIdentity()
      }
    }
  }

  /// Resets user values
  private func _reset() {
    _appUserId = nil
    _aliasId = IdentityLogic.generateAlias()
    _userAttributes = [:]
  }
}

// MARK: - User Attributes
extension IdentityManager {
  /// Merges the attributes on an async queue
  func mergeUserAttributes(_ newUserAttributes: [String: Any?]) {
    queue.async { [weak self] in
      self?._mergeUserAttributes(newUserAttributes)
    }
  }

  /// Merges the provided user attributes with existing attributes then saves them.
  private func _mergeUserAttributes(_ newUserAttributes: [String: Any?]) {
    let mergedAttributes = IdentityLogic.mergeAttributes(
      newUserAttributes,
      with: _userAttributes,
      appInstalledAtString: deviceHelper.appInstalledAtString
    )

    Task {
      let trackableEvent = InternalSuperwallEvent.Attributes(
        customParameters: mergedAttributes
      )
      await Superwall.shared.track(trackableEvent)
    }

    storage.save(mergedAttributes, forType: UserAttributes.self)
    _userAttributes = mergedAttributes
  }
}
