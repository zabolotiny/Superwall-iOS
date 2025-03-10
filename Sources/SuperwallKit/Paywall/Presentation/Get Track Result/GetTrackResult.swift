//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/11/2022.
//

import Foundation
import Combine

enum GetTrackResultError: Error, Equatable {
  case willNotPresent(TriggerResult)
  case userIsSubscribed
  case paywallNotAvailable

  static func == (lhs: GetTrackResultError, rhs: GetTrackResultError) -> Bool {
    switch (lhs, rhs) {
    case (.willNotPresent, .willNotPresent),
      (.userIsSubscribed, .userIsSubscribed),
      (.paywallNotAvailable, .paywallNotAvailable):
      return true
    default:
      return false
    }
  }
}

extension Superwall {
  func getTrackResult(for request: PresentationRequest) async -> TrackResult {
    let presentationSubject = PresentationSubject(request)

    return await presentationSubject
      .eraseToAnyPublisher()
      .waitToPresent()
      .logPresentation("Called Superwall.shared.getTrackResult")
      .evaluateRules(isPreemptive: true)
      .checkForPaywallResult()
      .getPaywallViewControllerNoChecks()
      .checkPaywallIsPresentable()
      .async()
  }
}

// MARK: - Async Publisher for GetTrackResult
extension Publisher where Output == TrackResult {
  /// Waits and returns the first value of the publisher.
  ///
  /// This handles the error cases thrown by `getTrackResult(for:)`.
  @discardableResult
  func async() async -> Output {
    await withCheckedContinuation { continuation in
      var cancellable: AnyCancellable?
      cancellable = first()
        .sink { completion in
          switch completion {
          case .failure(let error):
            switch error {
            case let error as GetTrackResultError:
              switch error {
              case .willNotPresent(let result):
                continuation.resume(with: .success(result))
              case .userIsSubscribed:
                let userInfo: [String: Any] = [
                  "Already Subscribed": "The user has an active subscription so the paywall won't show."
                ]
                let error = NSError(
                  domain: "com.superwall",
                  code: 404,
                  userInfo: userInfo
                )
                continuation.resume(with: .success(.error(error)))
              case .paywallNotAvailable:
                let userInfo: [String: Any] = [
                  "Paywall View Controller Error": "There was an issue retrieving the Paywall View Controller."
                ]
                let error = NSError(
                  domain: "com.superwall",
                  code: 404,
                  userInfo: userInfo
                )
                continuation.resume(with: .success(.error(error)))
              }
            default:
              break
            }
            cancellable?.cancel()
          case .finished:
            cancellable?.cancel()
          }
        } receiveValue: { value in
          continuation.resume(with: .success(value))
        }
    }
  }
}
