//
//  ProductModel.swift
//  Monolog
//
//  Created by Paulo Orquillo on 2/03/23.
//

import Foundation
import StoreKit
import Glassfy

//alias
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo //The Product.SubscriptionInfo.RenewalInfo provides information about the next subscription renewal period.
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState // the renewal states of auto-renewable subscriptions.

class StoreModel: ObservableObject {
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionGroupStatus: RenewalState?
    @Published var selectedProduct: Product?
    
    private let productIds: [String] = ["unlimited_monthly", "unlimited_annual"]
    
    var updateListenerTask : Task<Void, Error>? = nil

    init() {
        //start a transaction listern as close to app launch as possible so you don't miss a transaction
        updateListenerTask = listenForTransactions()
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    // deliver products to the user
                    await self.updateCustomerProductStatus()
                    
                    await transaction.finish()
                } catch {
                    print("transaction failed verification")
                }
            }
        }
    }
    
    // Request the products
    @MainActor
    func requestProducts() async {
        do {
            // request from the app store using the product ids (hardcoded)
            subscriptions = try await Product.products(for: productIds)
            selectedProduct = subscriptions.first
            //print("SUBSCRIPTIONS")
            //print(subscriptions)
        } catch {
            print("Failed product request from app store server: \(error)")
        }
    }
    
    // purchase the product
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            //Check whether the transaction is verified. If it isn't,
            //this function rethrows the verification error.
            let transaction = try checkVerified(verification)
            
            //The transaction is verified. Deliver content to the user.
            await updateCustomerProductStatus()
            
            //Always finish a transaction.
            await transaction.finish()

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }
    
    @MainActor
    func updateCustomerProductStatus() async {
        for await result in Transaction.currentEntitlements {
            do {
                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try checkVerified(result)
                
                switch transaction.productType {
                    case .autoRenewable:
                        if let subscription = subscriptions.first(where: {$0.id == transaction.productID}) {
                            purchasedSubscriptions.append(subscription)
                        }
                        //print("all purchased: \(purchasedSubscriptions)")
                    default:
                        break
                }
                //Always finish a transaction.
                await transaction.finish()
            } catch {
                print("failed updating products")
            }
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            //The result is verified. Return the unwrapped value.
            return safe
        }
    }
    
    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            do {
                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try checkVerified(result)
                
                switch transaction.productType {
                    case .autoRenewable:
                        if let subscription = subscriptions.first(where: {$0.id == transaction.productID}) {
                            purchasedSubscriptions.append(subscription)
                        }
                        //print("all purchased: \(purchasedSubscriptions)")
                    default:
                        break
                }
                //Always finish a transaction.
                await transaction.finish()
            } catch {
                print("failed updating products")
            }
        }
    }
    
    func monthlyProduct() -> Product? {
        if let monthly = subscriptions.first(where: {$0.id == "unlimited_monthly"}) {
            return monthly
        }
        return nil
    }
    
    func annualProduct() -> Product? {
        if let annual = subscriptions.first(where: {$0.id == "unlimited_annual"}) {
            return annual
        }
        return nil
    }

}

public enum StoreError: Error {
    case failedVerification
}
