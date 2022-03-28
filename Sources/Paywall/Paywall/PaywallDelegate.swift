//
//  File.swift
//  
//
//  Created by Jake Mor on 10/5/21.
//

import Foundation
import StoreKit

/// The protocol that handles Paywall lifecycle events.
///
/// The delegate methods receive callbacks from the SDK in response to certain events that happen on the paywall. It contains some required and some optional methods. To learn how to conform to the delegate in your app and best practices, see <doc:GettingStarted>.
@objc public protocol PaywallDelegate: AnyObject {
	/// Called when the user initiates checkout for a product.
  ///
  /// Add your purchase logic here. You can use Apple's StoreKit APIs, or if you use RevenueCat, you can call [`Purchases.shared.purchaseProduct()`]( https://sdk.revenuecat.com/ios/Classes/RCPurchases.html#/c:objc(cs)RCPurchases(im)purchaseProduct:withCompletionBlock:).
	/// - Parameter product: The `SKProduct` the user would like to purchase.
	@objc func purchase(product: SKProduct)

	/// Called when the user initiates a restore.
  ///
  /// Add your restore logic here.
  ///
  /// - Parameters:
  ///   - completion: Call the completion with `true` if the user's transactions were restored or `false` if they weren't.
	@objc func restorePurchases(completion: @escaping (Bool) -> Void)

	/// Decides whether a paywall should be presented based on the user's subscription status.
  ///
  /// A paywall will never be shown if this function returns `true`.
  ///
  /// - Returns: A boolean that indicates whether or not the user has an active subscription.
	@objc func isUserSubscribed() -> Bool

	/// Called when the user taps a button with a custom `data-pw-custom` tag in your HTML paywall. See paywall.js for further documentation
	///  - Parameter withName: The value of the `data-pw-custom` tag in your HTML element that the user selected.
	@objc optional func handleCustomPaywallAction(withName name: String)

	/// Called right before the paywall is dismissed.
	@objc optional func willDismissPaywall()

	/// Called right before the paywall is presented.
	@objc optional func willPresentPaywall()

	/// Called right after the paywall is dismissed.
	@objc optional func didDismissPaywall()

	/// Called right after the paywall is presented.
	@objc optional func didPresentPaywall()

	/// Called when the user opens a URL by selecting an element with the `data-pw-open-url` tag in your HTML paywall.
	@objc optional func willOpenURL(url: URL)

	/// Called when the user taps a deep link in your HTML paywall.
	@objc optional func willOpenDeepLink(url: URL)

	/// Called when you should track a standard internal analytics event to your own system. If you want the event's name as an enum, do this: `let event = Paywall.EventName(rawValue: name)`
	///
	/// Possible Values:
	///  ```swift
	/// // App Lifecycle Events
	/// Paywall.delegate.trackAnalyticsEvent(name: "app_install", params: nil)
	/// Paywall.delegate.trackAnalyticsEvent(name: "app_open", params: nil)
	/// Paywall.delegate.trackAnalyticsEvent(name: "app_close", params: nil)
	///
	/// // Paywall Events
	/// Paywall.delegate.trackAnalyticsEvent(name: "paywall_open", params: ['paywall_id': 'someid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "paywall_close", params: ['paywall_id': 'someid'])
	///
	/// // Transaction Events
	/// Paywall.delegate.trackAnalyticsEvent(name: "transaction_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "transaction_fail", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "transaction_abandon", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "transaction_complete", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "transaction_restore", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	///
	/// // Purchase Events
	/// Paywall.delegate.trackAnalyticsEvent(name: "subscription_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "freeTrial_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "nonRecurringProduct_purchase", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	///
	/// // Superwall API Request Events
	/// Paywall.delegate.trackAnalyticsEvent(name: "paywallResponseLoad_start", params: ['paywall_id': 'someid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "paywallResponseLoad_fail", params: ['paywall_id': 'someid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "paywallResponseLoad_complete", params: ['paywall_id': 'someid'])
	///
	/// // Webview Reqeuest Events
	/// Paywall.delegate.trackAnalyticsEvent(name: "paywallWebviewLoad_start", params: ['paywall_id': 'someid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "paywallWebviewLoad_fail", params: ['paywall_id': 'someid'])
	/// Paywall.delegate.trackAnalyticsEvent(name: "paywallWebviewLoad_complete", params: ['paywall_id': 'someid'])
	/// ```
	@objc optional func trackAnalyticsEvent(
    withName name: String,
    params: [String: Any]
  )

  /// Receive all the log messages generated by the SDK.
  ///
  /// - Parameters:
  ///   - level: Specifies the detail of the logs returned from the SDK to the console. Can be either "DEBUG", "INFO", "WARN", or "ERROR", as defined by ``LogLevel``.
  ///   - scope: The possible scope of logs to print to the console, as defined by ``LogScope``.
  ///   - message: The message associated with the log.
  ///   - info: A dictionary of information associated with the log.
  ///   - error: The error associated with the log.
	@objc optional func handleLog(
    level: String,
    scope: String,
    message: String?,
    info: [String: Any]?,
    error: Swift.Error?
  )
}
