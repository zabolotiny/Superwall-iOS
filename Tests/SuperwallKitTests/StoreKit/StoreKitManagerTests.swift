//
//  StoreKitManagerTests.swift
//  
//
//  Created by Yusuf Tör on 01/09/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit
import StoreKit

class StoreKitManagerTests: XCTestCase {
  private func makeStoreKitManager(with productsFetcher: ProductsFetcherSK1) -> StoreKitManager {
    let dependencyContainer = DependencyContainer(apiKey: "")
    let coordinator = StoreKitCoordinator(
      delegateAdapter: dependencyContainer.delegateAdapter,
      storeKitManager: dependencyContainer.storeKitManager,
      factory: dependencyContainer,
      productsFetcher: productsFetcher
    )
    let storeKitCoordinatorFactoryMock = StoreKitCoordinatorFactoryMock(
      coordinator: coordinator
    )
    let storeKitManager = StoreKitManager(factory: storeKitCoordinatorFactoryMock)
    storeKitManager.postInit()

    return storeKitManager
  }

  func test_getProducts_primaryProduct() async {
    let dependencyContainer = DependencyContainer(apiKey: "abc")
    let manager = dependencyContainer.storeKitManager!

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = PaywallProducts(
      primary: StoreProduct(sk1Product: primary)
    )

    do {
      let (productsById, products) = try await manager.getProducts(withIds: [], substituting: substituteProducts)
      XCTAssertEqual(productsById[primary.productIdentifier]?.underlyingSK1Product, primary)
      XCTAssertEqual(products.first!.id, primary.productIdentifier)
      XCTAssertEqual(products.first!.type, .primary)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_primaryAndTertiaryProduct() async {
    let dependencyContainer = DependencyContainer(apiKey: "abc")
    let manager = dependencyContainer.storeKitManager!

    let primary = MockSkProduct(productIdentifier: "abc")
    let tertiary = MockSkProduct(productIdentifier: "def")
    let substituteProducts = PaywallProducts(
      primary: StoreProduct(sk1Product: primary),
      tertiary: StoreProduct(sk1Product: tertiary)
    )

    do {
      let (productsById, products) = try await manager.getProducts(withIds: [], substituting: substituteProducts)
      XCTAssertEqual(productsById[primary.productIdentifier]?.underlyingSK1Product, primary)
      XCTAssertEqual(products[0].id, primary.productIdentifier)
      XCTAssertEqual(products[0].type, .primary)

      XCTAssertEqual(productsById[tertiary.productIdentifier]?.underlyingSK1Product, tertiary)
      XCTAssertEqual(products[1].id, tertiary.productIdentifier)
      XCTAssertEqual(products[1].type, .tertiary)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_primarySecondaryTertiaryProduct() async {
    let dependencyContainer = DependencyContainer(apiKey: "abc")
    let manager = dependencyContainer.storeKitManager!

    let primary = MockSkProduct(productIdentifier: "abc")
    let secondary = MockSkProduct(productIdentifier: "def")
    let tertiary = MockSkProduct(productIdentifier: "ghi")
    let substituteProducts = PaywallProducts(
      primary: StoreProduct(sk1Product: primary),
      secondary: StoreProduct(sk1Product: secondary),
      tertiary: StoreProduct(sk1Product: tertiary)
    )

    do {
      let (productsById, products) = try await manager.getProducts(withIds: [], substituting: substituteProducts)
      XCTAssertEqual(productsById[primary.productIdentifier]?.underlyingSK1Product, primary)
      XCTAssertEqual(products[0].id, primary.productIdentifier)
      XCTAssertEqual(products[0].type, .primary)

      XCTAssertEqual(productsById[secondary.productIdentifier]?.underlyingSK1Product, secondary)
      XCTAssertEqual(products[1].id, secondary.productIdentifier)
      XCTAssertEqual(products[1].type, .secondary)

      XCTAssertEqual(productsById[tertiary.productIdentifier]?.underlyingSK1Product, tertiary)
      XCTAssertEqual(products[2].id, tertiary.productIdentifier)
      XCTAssertEqual(products[2].type, .tertiary)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_substitutePrimaryProduct_oneResponseProduct() async {
    let productsResult: Result<Set<StoreProduct>, Error> = .success([])
    let productsFetcher = ProductsFetcherSK1Mock(productCompletionResult: productsResult)
    let manager = makeStoreKitManager(with: productsFetcher)

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = PaywallProducts(
      primary: StoreProduct(sk1Product: primary)
    )

    do {
      let (productsById, products) = try await manager.getProducts(withIds: ["1"], substituting: substituteProducts)
      XCTAssertEqual(productsById.count, 1)
      XCTAssertEqual(productsById[primary.productIdentifier]?.underlyingSK1Product, primary)
      XCTAssertEqual(products.first!.id, primary.productIdentifier)
      XCTAssertEqual(products.first!.type, .primary)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_substitutePrimaryProduct_twoResponseProducts() async {
    let responseProduct2 = MockSkProduct(productIdentifier: "2")
    let productsResult: Result<Set<StoreProduct>, Error> = .success([
      StoreProduct(sk1Product: responseProduct2)
    ])
    let productsFetcher = ProductsFetcherSK1Mock(productCompletionResult: productsResult)
    let manager = makeStoreKitManager(with: productsFetcher)

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = PaywallProducts(
      primary: StoreProduct(sk1Product: primary)
    )

    do {
      let (productsById, products) = try await manager.getProducts(withIds: ["1", "2"], substituting: substituteProducts)
      XCTAssertEqual(productsById.count, 2)
      XCTAssertEqual(productsById[primary.productIdentifier]?.underlyingSK1Product, primary)
      XCTAssertEqual(products.count, 1)
      XCTAssertEqual(products.first!.id, primary.productIdentifier)
      XCTAssertEqual(products.first!.type, .primary)
      XCTAssertEqual(productsById["2"]?.underlyingSK1Product, responseProduct2)
    } catch {
      XCTFail("couldn't get products")
    }
  }
}
