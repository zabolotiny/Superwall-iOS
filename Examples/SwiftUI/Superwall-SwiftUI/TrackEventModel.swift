//
//  TrackEventModel.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 06/09/2022.
//

// import Combine
import SuperwallKit

final class TrackEventModel {
  // private var cancellable: AnyCancellable?

  func trackEvent() {
    Superwall.shared.track(event: "campaign_trigger") { paywallState in
      switch paywallState {
      case .presented(let paywallInfo):
        print("paywall info is", paywallInfo)
      case .dismissed(let result):
        switch result.state {
        case .closed:
          print("The paywall was dismissed.")
        case .purchased(productId: let productId):
          print("Purchased a product with id \(productId), then dismissed.")
        case .restored:
          print("Restored purchases, then dismissed.")
        }
      case .skipped(let reason):
        switch reason {
        case .noRuleMatch:
          print("The user did not match any rules")
        case .holdout(let experiment):
          print("The user is in a holdout group, with experiment id: \(experiment.id), group id: \(experiment.groupId), paywall id: \(experiment.variant.paywallId ?? "")")
        case .eventNotFound:
          print("The event wasn't found in a campaign on the dashboard.")
        case .userIsSubscribed:
          print("The user is subscribed.")
        case .error(let error):
          print("Failed to present paywall. Consider a native paywall fallback", error)
        }
      }
    }
  }

  func logOut() {
    SuperwallService.reset()
  }

  // The below function gives an example of how to track an event using Combine publishers:
  /*
  func trackEventUsingCombine() {
    cancellable = Superwall
      .publisher(forEvent: "MyEvent")
      .sink { paywallState in
        switch paywallState {
        case .presented(let paywallInfo):
          print("paywall info is", paywallInfo)
        case .dismissed(let result):
          switch result.state {
          case .closed:
            print("User dismissed the paywall.")
          case .purchased(productId: let productId):
            print("Purchased a product with id \(productId), then dismissed.")
          case .restored:
            print("Restored purchases, then dismissed.")
          }
        case .skipped(let reason):
          switch reason {
          case .noRuleMatch:
            print("The user did not match any rules")
          case .holdout(let experiment):
            print("The user is in a holdout group, with experiment id: \(experiment.id), group id: \(experiment.groupId), paywall id: \(experiment.variant.paywallId ?? "")")
          case .eventNotFound:
            print("The event wasn't found in a campaign on the dashboard.")
          case .error(let error):
            print("Failed to present paywall. Consider a native paywall fallback", error)
          }
        }
      }
    */
}
