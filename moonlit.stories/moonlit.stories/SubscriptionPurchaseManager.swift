import Foundation
import Observation
import StoreKit

// MARK: - Fixed Product ID source of truth
// Khai báo CỨNG theo App Store Connect / StoreKit Configuration file.
// Đây là nguồn duy nhất quyết định ID nào được truyền vào StoreKit.Product.products(for:).
// Backend (`Product.platformProductID`) chỉ dùng để map metadata hiển thị (tên, giá fallback,
// trạng thái active) — KHÔNG dùng để quyết định ID gọi StoreKit, để tránh việc backend
// nhập sai/null/lệch ký tự làm mất nguyên một offer.
enum MoonPassTier: String, CaseIterable {
    case weekly    = "com.moonlit.weekly_2_99usd"
    case monthly   = "com.moonlit.monthly_5_99usd"
    case quarterly = "com.moonlit.quarterly_14_99usd"
    case yearly    = "com.moonlit.yearly_29_99usd"
    // Lưu ý: hiện KHÔNG có product ID cho "daily" trong StoreKit Config.
    // Nếu backend vẫn trả code "moonpass_daily", nó sẽ không bao giờ match enum này
    // và bị loại tự nhiên — không cần filter riêng theo string "moonpass_daily" nữa.

    /// Khớp với backend product code để map displayName/giá fallback khi StoreKit chưa load xong.
    var backendCode: String {
        switch self {
        case .weekly:    return "moonpass_weekly"
        case .monthly:   return "moonpass_monthly"
        case .quarterly: return "moonpass_quarterly"
        case .yearly:    return "moonpass_yearly"
        }
    }

    /// Thứ bậc gói (cao = tốt hơn) — dùng để chỉ hiện gói cao hơn tier hiện tại của user.
    var rank: Int {
        switch self {
        case .weekly:    return 2
        case .monthly:   return 3
        case .quarterly: return 4
        case .yearly:    return 5
        }
    }

    /// Tên hiển thị cho UI (Profile badge, lịch sử giao dịch, v.v).
    var displayName: String {
        switch self {
        case .weekly:    return "MoonPass Weekly"
        case .monthly:   return "MoonPass Monthly"
        case .quarterly: return "MoonPass Quarterly"
        case .yearly:    return "MoonPass Yearly"
        }
    }

    /// Tên ngắn cho badge nhỏ (vd. cạnh nickname trên ProfileView).
    var shortBadgeName: String {
        switch self {
        case .weekly:    return "WEEKLY"
        case .monthly:   return "MONTHLY"
        case .quarterly: return "QUARTERLY"
        case .yearly:    return "YEARLY"
        }
    }

    static func from(backendCode: String) -> MoonPassTier? {
        allCases.first { $0.backendCode == backendCode }
    }

    static var allProductIDs: [String] {
        allCases.map { $0.rawValue }
    }
}

struct MoonPassOffer: Identifiable {
    var id: String { tier.backendCode }
    let tier: MoonPassTier
    let backendProduct: Product?       // metadata backend (có thể nil nếu backend chưa khai báo code này)
    let storeProduct: StoreKit.Product? // nguồn sự thật cho purchase

    var displayName: String {
        storeProduct?.displayName ?? backendProduct?.name ?? tier.backendCode
    }

    var displayPrice: String {
        if let storeProduct {
            return storeProduct.displayPrice
        }
        if let backendProduct {
            return "\(backendProduct.currency) \(String(format: "%.2f", backendProduct.price))"
        }
        return "--"
    }

    var isPurchasable: Bool {
        storeProduct != nil
    }

    /// Human-readable billing period, e.g. "month", "year", "week".
    var periodText: String? {
        guard let period = storeProduct?.subscription?.subscriptionPeriod else {
            switch tier {
            case .weekly:    return "week"
            case .monthly:   return "month"
            case .quarterly: return "3 months"
            case .yearly:    return "year"
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
            // Backend chỉ dùng để: (1) biết tier hiện tại của user, (2) lấy metadata
            // hiển thị (tên/giá fallback) và trạng thái active, KHÔNG dùng để quyết định
            // product ID nào sẽ gọi vào StoreKit.
            let products = try await NetworkService.shared.fetchProducts()
            let backendByCode = Dictionary(
                products
                    .filter { $0.type == "subscription" }
                    .map { ($0.code, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            let activeSub = try? await NetworkService.shared.fetchSubscription()
            let activeCode = activeSub?.isSubscribed == true ? activeSub?.subscription?.productCode : nil
            let activeRank = activeCode.flatMap { MoonPassTier.from(backendCode: $0)?.rank } ?? 0

            // Chỉ xét các tier có rank cao hơn tier hiện tại của user (logic upgrade).
            let candidateTiers = MoonPassTier.allCases.filter { $0.rank > activeRank }

            guard !candidateTiers.isEmpty else {
                offers = []
                selectedOffer = nil
                errorMessage = nil // user đang ở tier cao nhất — không phải lỗi
                return
            }

            // Gọi StoreKit với ID CỐ ĐỊNH, không phụ thuộc backend trả platformProductID đúng hay không.
            let storeProducts = (try? await StoreKit.Product.products(for: candidateTiers.map(\.rawValue))) ?? []
            let storeProductByID = Dictionary(storeProducts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            var loadedOffers: [MoonPassOffer] = candidateTiers.map { tier in
                MoonPassOffer(
                    tier: tier,
                    backendProduct: backendByCode[tier.backendCode],
                    storeProduct: storeProductByID[tier.rawValue]
                )
            }

            // Nếu thiếu StoreKit product (vd. chưa duyệt trên App Store Connect, hoặc
            // scheme không trỏ đúng StoreKit Configuration), log rõ ID nào bị thiếu
            // để dễ debug — KHÔNG cần phụ thuộc backend nữa để biết nguyên nhân.
            #if DEBUG
            let missing = candidateTiers.map(\.rawValue).filter { storeProductByID[$0] == nil }
            if !missing.isEmpty {
                print("[MoonPass] StoreKit không resolve được các ID: \(missing)")
            }
            #endif

            loadedOffers = loadedOffers.filter { $0.isPurchasable }

            // Order weekly, monthly, quarterly, yearly (theo rank đã khai báo trong enum).
            loadedOffers.sort { $0.tier.rank < $1.tier.rank }

            self.offers = loadedOffers
            // Luôn default về monthly nếu có, để CTA "Purchase" sống ngay khi mở màn hình.
            self.selectedOffer = loadedOffers.first(where: { $0.tier == .monthly })
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
                    productCode: selectedOffer.tier.backendCode,
                    transactionId: String(transaction.id),
                    signedTransaction: verification.jwsRepresentation
                )
                await transaction.finish()
                AnalyticsService.shared.track(.purchaseSuccess, [
                    "product_code": selectedOffer.tier.backendCode,
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

            for await result in Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                guard let tier = MoonPassTier.allCases.first(where: { $0.rawValue == transaction.productID }) else {
                    continue
                }

                _ = try await NetworkService.shared.verifyIAPPurchase(
                    productCode: tier.backendCode,
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
