//
//  PaywallManager.swift
//  Superwall-UIKit+RevenueCat
//
//  Created by Yusuf Tör on 14/11/2022.
//

import SuperwallKit
import StoreKit
import RevenueCat
import Combine

final class PaywallManager: NSObject {
  static let shared = PaywallManager()
  static var name: String {
    return Superwall.shared.userAttributes["firstName"] as? String ?? ""
  }

  #warning("Replace these with your API keys:")
  private static let revenueCatApiKey = "appl_XmYQBWbTAFiwLeWrBJOeeJJtTql"
  private static let superwallApiKey = "pk_e6bd9bd73182afb33e95ffdf997b9df74a45e1b5b46ed9c9"

  /// Configures both the RevenueCat and Superwall SDKs.
  ///
  /// Call this on `application(_:didFinishLaunchingWithOptions:)`
  static func configure() {
    Purchases.configure(
      with: .init(withAPIKey: revenueCatApiKey)
        .with(usesStoreKit2IfAvailable: false)
    )
    Purchases.shared.delegate = shared

    // We retrieve the subscription status from RevenueCat before
    // configuring Superwall to prevent session_start events from
    // incorrectly firing due to an incorrect subscription status.
    Purchases.shared.getCustomerInfo { customerInfo, _ in
      DispatchQueue.main.async {
        if let customerInfo {
          shared.updateSubscriptionStatus(using: customerInfo)
        }
      }
    }

    Superwall.configure(
      apiKey: superwallApiKey,
      purchaseController: shared
    )
    Superwall.shared.delegate = shared
  }

  /// Logs the user in to both RevenueCat and Superwall with the specified `userId`.
  ///
  /// Call this when your user needs to log in.
  func logIn(userId: String) async {
    do {
      let (customerInfo, _) = try await Purchases.shared.logIn(userId)
      updateSubscriptionStatus(using: customerInfo)
      Superwall.shared.identify(userId: userId)
    } catch {
      print(error.localizedDescription)
    }
  }

  /// Logs the user out of RevenueCat and Superwall.
  ///
  /// Call this when your user logs out.
  func logOut() async {
    do {
      let customerInfo = try await Purchases.shared.logOut()
      updateSubscriptionStatus(using: customerInfo)
      Superwall.shared.reset()
    } catch {
      print("A RevenueCat error occurred", error)
    }
  }

  /// Handles a deep link to open a paywall preview.
  ///
  /// [See here](https://docs.superwall.com/v3.0/docs/in-app-paywall-previews#handling-deep-links)
  /// for information on how to call this function in your app.
  static func handleDeepLink(_ url: URL) {
    Superwall.shared.handleDeepLink(url)
  }

  /// Settting Superwall attributes.
  static func setName(to name: String) {
    Superwall.shared.setUserAttributes(["firstName": name])
  }

  /// Purchases a product with RevenueCat.
  /// - Returns: A boolean indicating whether the user cancelled or not.
  private func purchase(_ product: SKProduct) async throws -> Bool {
    let product = RevenueCat.StoreProduct(sk1Product: product)
    let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(product: product)
    updateSubscriptionStatus(using: customerInfo)
    return userCancelled
  }
}

// MARK: - PurchaseController
extension PaywallManager: PurchaseController {
  /// Restore purchases
  func restorePurchases() async -> Bool {
    return await restore()
  }

  func purchase(product: SKProduct) async -> PurchaseResult {
    do {
      let userCancelled = try await purchase(product)
      return userCancelled ? .cancelled : .purchased
    } catch let error as ErrorCode {
      switch error {
      case .paymentPendingError:
        return .pending
      default:
        return .failed(error)
      }
    } catch {
      return .failed(error)
    }
  }
}

// MARK: - Purchases Delegate
extension PaywallManager: PurchasesDelegate {
  /// Handles updated CustomerInfo received from RevenueCat.
  func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    updateSubscriptionStatus(using: customerInfo)
  }

  /// Updates the subscription status in response to customer info received from RevenueCat.
  private func updateSubscriptionStatus(using customerInfo: CustomerInfo) {
    if customerInfo.entitlements.active.isEmpty {
      Superwall.shared.subscriptionStatus = .inactive
    } else {
      Superwall.shared.subscriptionStatus = .active
    }
  }

  /// Restores purchases and updates subscription status.
  ///
  /// - Returns: A boolean indicating whether the user restored a purchase or not.
  private func restore() async -> Bool {
    do {
      let customerInfo = try await Purchases.shared.restorePurchases()
      updateSubscriptionStatus(using: customerInfo)
      return true
    } catch {
      return false
    }
  }
}

// MARK: - Superwall Delegate
extension PaywallManager: SuperwallDelegate {
  func didTrackSuperwallEventInfo(_ info: SuperwallEventInfo) {
    print("analytics event called", info.event.description)

    // Uncomment if you want to get a dictionary of params associated with the event:
    // print(info.params)

    // Uncomment the following if you want to track
    // Superwall events:
    /*
    switch info.event {
    case .firstSeen:
      <#code#>
    case .appOpen:
      <#code#>
    case .appLaunch:
      <#code#>
    case .appInstall:
      <#code#>
    case .sessionStart:
      <#code#>
    case .appClose:
      <#code#>
    case .deepLink(let url):
      <#code#>
    case .triggerFire(let eventName, let result):
      <#code#>
    case .paywallOpen(let paywallInfo):
      <#code#>
    case .paywallClose(let paywallInfo):
      <#code#>
    case .transactionStart(let product, let paywallInfo):
      <#code#>
    case .transactionFail(let error, let paywallInfo):
      <#code#>
    case .transactionAbandon(let product, let paywallInfo):
      <#code#>
    case .transactionComplete(let transaction, let product, let paywallInfo):
      <#code#>
    case .transactionTimeout(let paywallInfo):
      <#code#>
    case .subscriptionStart(let product, let paywallInfo):
      <#code#>
    case .freeTrialStart(let product, let paywallInfo):
      <#code#>
    case .transactionRestore(let paywallInfo):
      <#code#>
    case .userAttributes(let attributes):
      <#code#>
    case .nonRecurringProductPurchase(let product, let paywallInfo):
      <#code#>
    case .paywallResponseLoadStart(let triggeredEventName):
      <#code#>
    case .paywallResponseLoadNotFound(let triggeredEventName):
      <#code#>
    case .paywallResponseLoadFail(let triggeredEventName):
      <#code#>
    case .paywallResponseLoadComplete(let triggeredEventName, let paywallInfo):
      <#code#>
    case .paywallWebviewLoadStart(let paywallInfo):
      <#code#>
    case .paywallWebviewLoadFail(let paywallInfo):
      <#code#>
    case .paywallWebviewLoadComplete(let paywallInfo):
      <#code#>
    case .paywallWebviewLoadTimeout(let paywallInfo):
      <#code#>
    case .paywallProductsLoadStart(let triggeredEventName, let paywallInfo):
      <#code#>
    case .paywallProductsLoadFail(let triggeredEventName, let paywallInfo):
      <#code#>
    case .paywallProductsLoadComplete(let triggeredEventName):
      <#code#>
    case .paywallPresentationFail(reason: let reason):
      <#code#>
    case .subscriptionStatusDidChange:
      <#code#>
    }
    */
  }
}
