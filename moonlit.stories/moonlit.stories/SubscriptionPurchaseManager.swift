import Foundation
import Observation
import StoreKit

struct MoonPassOffer: Identifiable {
    var id: String { backendProduct.code }
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

    /// Human-readable billing period, e.g. "month", "year", "week".
    var periodText: String? {
        guard let period = storeProduct?.subscription?.subscriptionPeriod else {
            // Fallback from product code
            switch backendProduct.code {
            case "moonpass_daily": return "day"
            case "moonpass_weekly": return "week"
            case "moonpass_monthly": return "month"
            case "moonpass_quarterly": return "3 months"
            case "moonpass_yearly": return "year"
            default: return "month"
            }
        }
        let unit: String
        switch period.unit {
        case .day:   unit = "day"
        case .week:  unit = "week"
        case .month: unit = "month"
        case .year:  unit = "year"
        @unknown default: unit = "period"
        }
        return period.value == 1 ? unit : "\(period.value) \(unit)s"
    }
    
    var displayPeriodDescription: String {
        if let periodText {
            return "Billed every \(periodText)"
        }
        return "Billed periodically"
    }
}

@MainActor
@Observable
final class SubscriptionPurchaseManager {
    var offers: [MoonPassOffer] = []
    var selectedOffer: MoonPassOffer?
    var isLoading = false
    var isPurchasing = false
    var errorMessage: String?

    func loadMoonPassOffer() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let products = try await NetworkService.shared.fetchProducts()
            let subscriptionProducts = products.filter { $0.type == "subscription" && $0.active && $0.code != "moonpass_daily" }
            
            if subscriptionProducts.isEmpty {
                errorMessage = "MoonPass is not configured yet."
                offers = []
                selectedOffer = nil
                return
            }

            let activeSub = try? await NetworkService.shared.fetchSubscription()
            let activeCode = activeSub?.isSubscribed == true ? activeSub?.subscription?.productCode : nil

            let tiers = [
                "moonpass_daily": 1,
                "moonpass_weekly": 2,
                "moonpass_monthly": 3,
                "moonpass_quarterly": 4,
                "moonpass_yearly": 5
            ]
            let activeRank = activeCode != nil ? (tiers[activeCode!] ?? 0) : 0

            // Only consider products the user can actually upgrade to.
            let candidates = subscriptionProducts.filter { sub in
                guard let productID = sub.platformProductID, !productID.isEmpty else { return false }
                let subRank = tiers[sub.code] ?? 0
                return subRank > activeRank
            }

            // Batch-fetch all StoreKit products in a single request (more reliable than
            // per-product calls, which can silently fail and leave the offer unpurchasable).
            let productIDs = Array(Set(candidates.compactMap { $0.platformProductID }))
            let storeProducts = (try? await StoreKit.Product.products(for: productIDs)) ?? []
            let storeProductByID = Dictionary(storeProducts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            var loadedOffers: [MoonPassOffer] = candidates.map { sub in
                let storeProduct = sub.platformProductID.flatMap { storeProductByID[$0] }
                return MoonPassOffer(backendProduct: sub, storeProduct: storeProduct)
            }

            // Drop offers StoreKit could not resolve so the user never lands on a dead choice.
            loadedOffers = loadedOffers.filter { $0.isPurchasable }

            // Order daily, weekly, monthly, quarterly, yearly
            let order = ["moonpass_daily": 1, "moonpass_weekly": 2, "moonpass_monthly": 3, "moonpass_quarterly": 4, "moonpass_yearly": 5]
            loadedOffers.sort { (order[$0.backendProduct.code] ?? 99) < (order[$1.backendProduct.code] ?? 99) }

            self.offers = loadedOffers
            // Always default to a purchasable offer (prefer monthly) so the Purchase button is live.
            self.selectedOffer = loadedOffers.first(where: { $0.backendProduct.code == "moonpass_monthly" })
                ?? loadedOffers.first

            if loadedOffers.isEmpty {
                errorMessage = "MoonPass is currently unavailable. Please try again later."
            }

        } catch {
            errorMessage = error.localizedDescription
            offers = []
            selectedOffer = nil
        }
    }

    func purchaseMoonPass() async -> Bool {
        guard let selectedOffer else {
            errorMessage = "Please select a subscription offer."
            return false
        }
        guard let storeProduct = selectedOffer.storeProduct else {
            errorMessage = "Selected subscription is not available in the App Store."
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
                    productCode: selectedOffer.backendProduct.code,
                    transactionId: String(transaction.id),
                    signedTransaction: verification.jwsRepresentation
                )
                await transaction.finish()
                AnalyticsService.shared.track(.purchaseSuccess, [
                    "product_code": selectedOffer.backendProduct.code,
                    "product_type": "subscription",
                    "transaction_id": String(transaction.id)
                ])
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
