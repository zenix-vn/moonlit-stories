import Foundation
import Observation
import StoreKit

struct MoonPassOffer {
    let backendProduct: Product
    let storeProduct: StoreKit.Product?

    var displayName: String {
        storeProduct?.displayName ?? backendProduct.name
    }

    var displayPrice: String {
        if let storeProduct {
            return storeProduct.displayPrice
        }
        return "\(backendProduct.currency) \(String(format: "%.2f", backendProduct.price))"
    }

    var isPurchasable: Bool {
        storeProduct != nil
    }
}

@MainActor
@Observable
final class SubscriptionPurchaseManager {
    var offer: MoonPassOffer?
    var isLoading = false
    var isPurchasing = false
    var errorMessage: String?

    func loadMoonPassOffer() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let products = try await NetworkService.shared.fetchProducts()
            guard let moonPass = products.first(where: { $0.type == "subscription" && $0.active }) else {
                errorMessage = "MoonPass is not configured yet."
                offer = nil
                return
            }

            guard let productID = moonPass.platformProductID, !productID.isEmpty else {
                errorMessage = "MoonPass product ID is missing."
                offer = MoonPassOffer(backendProduct: moonPass, storeProduct: nil)
                return
            }

            let storeProducts = try await StoreKit.Product.products(for: [productID])
            offer = MoonPassOffer(
                backendProduct: moonPass,
                storeProduct: storeProducts.first(where: { $0.id == productID })
            )

            if offer?.storeProduct == nil {
                errorMessage = "MoonPass is not available from the App Store on this device."
            }
        } catch {
            errorMessage = error.localizedDescription
            offer = nil
        }
    }

    func purchaseMoonPass() async -> Bool {
        guard let offer, let storeProduct = offer.storeProduct else {
            errorMessage = "MoonPass is not ready for purchase."
            return false
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await storeProduct.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                _ = try await NetworkService.shared.verifyIAPPurchase(
                    productCode: offer.backendProduct.code,
                    transactionId: String(transaction.id),
                    signedTransaction: verification.jwsRepresentation
                )
                await transaction.finish()
                NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceChanged"), object: nil)
                return true
            case .pending:
                errorMessage = "Purchase is pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                errorMessage = "Purchase could not be completed."
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restoreMoonPass() async -> Bool {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()

            let products = try await NetworkService.shared.fetchProducts()
            let subscriptions = products.filter { $0.type == "subscription" && $0.active }

            for await result in Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                guard let product = subscriptions.first(where: { $0.platformProductID == transaction.productID }) else {
                    continue
                }

                _ = try await NetworkService.shared.verifyIAPPurchase(
                    productCode: product.code,
                    transactionId: String(transaction.id),
                    signedTransaction: result.jwsRepresentation
                )
                return true
            }

            errorMessage = "No active MoonPass purchase found."
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw NSError(
                domain: "StoreKit",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Purchase could not be verified."]
            )
        }
    }
}
