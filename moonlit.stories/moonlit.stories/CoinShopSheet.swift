import SwiftUI
import StoreKit

struct CoinShopView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var currentBalance: Int = 0
    @State private var isPurchasing: String? = nil // Tracks which product code is purchasing
    
    var body: some View {
        ZStack {
            Color.mlBg.ignoresSafeArea()
            
            // Decorative background blurs
            VStack {
                HStack {
                    Circle()
                        .fill(Color.mlPurple.opacity(0.12))
                        .frame(width: 200, height: 200)
                        .blur(radius: 50)
                        .offset(x: -50, y: -20)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.mlPink.opacity(0.10))
                        .frame(width: 250, height: 250)
                        .blur(radius: 60)
                        .offset(x: 50, y: 50)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            if isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(Color.mlPurple)
                        .scaleEffect(1.2)
                    Text("Loading packages...")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mlSubtext)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.mlPink)
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mlSubtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button("Retry") {
                        Task { await loadData() }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.mlPurple))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // MoonPass Banner
                        if let sub = products.first(where: { $0.type == "subscription" }) {
                            subscriptionCard(sub)
                        }
                        
                        // Coin packs title
                        HStack {
                            Text("COIN PACKS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.mlSubtext)
                                .tracking(1.2)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, -8)
                        
                        // Grid of Coin Packs
                        let coinPacks = products.filter { $0.type == "coin_pack" }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                            ForEach(coinPacks) { pack in
                                coinPackCard(pack)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Text("Purchases are processed securely via Apple's App Store.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.mlSubtext.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 12)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Coin Store")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .foregroundStyle(Color.mlGold)
                    Text("\(currentBalance)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let productsTask = NetworkService.shared.fetchProducts()
            async let meTask = NetworkService.shared.fetchMe()
            
            let fetchedProducts = try await productsTask
            let me = try await meTask
            
            await MainActor.run {
                self.products = fetchedProducts.filter { $0.active }
                self.currentBalance = me.wallet.coins
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Components
    
    private func subscriptionCard(_ product: Product) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UNLIMITED ACCESS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.mlPink)
                        .tracking(1.5)
                    
                    Text(product.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                    
                    Text("Read all premium episodes & exclusive stories with no limits")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mlSubtext)
                        .lineLimit(2)
                }
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.mlPink, Color.mlPurple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }
            
            Button(action: {
                purchase(product)
            }) {
                HStack {
                    if isPurchasing == product.code {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Text("Subscribe for \(String(format: "$%.2f", product.price)) / mo")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.mlPurple, Color.mlPurpleDim],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .disabled(isPurchasing != nil)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.mlCard.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.mlPurple.opacity(0.5), Color.mlPink.opacity(0.3)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .padding(.horizontal, 20)
    }
    
    private func coinPackCard(_ product: Product) -> some View {
        let coins = product.coinAmount ?? 0
        let bonus = product.bonusCoinAmount ?? 0
        
        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.mlGold.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.mlGold)
            }
            .padding(.top, 14)
            
            VStack(spacing: 2) {
                Text("\(coins) Coins")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                
                if bonus > 0 {
                    Text("+\(bonus) Bonus")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.55))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(red: 0.25, green: 0.85, blue: 0.55).opacity(0.15)))
                } else {
                    Spacer().frame(height: 14)
                }
            }
            
            Button(action: {
                purchase(product)
            }) {
                HStack {
                    if isPurchasing == product.code {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Text(String(format: "$%.2f", product.price))
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            }
            .disabled(isPurchasing != nil)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mlCard.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private func purchase(_ product: Product) {
        guard isPurchasing == nil else { return }
        isPurchasing = product.code
        
        Task {
            do {
                // TODO: Map product.code to Apple productID configured in App Store Connect
                // Replace "com.moonlit.stories." + product.code with your actual product identifiers
                let appleProductID = "com.moonlit.stories." + product.code
                let storeProducts = try await StoreKit.Product.products(for: [appleProductID])
                
                guard let storeProduct = storeProducts.first else {
                    await MainActor.run {
                        self.errorMessage = "Product not found in App Store. Please try again later."
                        isPurchasing = nil
                    }
                    return
                }
                
                let result = try await storeProduct.purchase()
                
                switch result {
                case .success(let verification):
                    // Verify the transaction is legit (not tampered)
                    let transaction: StoreKit.Transaction
                    switch verification {
                    case .verified(let tx):
                        transaction = tx
                    case .unverified:
                        throw NSError(domain: "IAP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Purchase could not be verified."])
                    }
                    
                    // Send real transaction ID to server for server-side validation
                    let txID = String(transaction.id)
                    let response = try await NetworkService.shared.verifyIAPPurchase(
                        productCode: product.code,
                        transactionId: txID
                    )
                    
                    // Finish the transaction with Apple
                    await transaction.finish()
                    
                    await MainActor.run {
                        if let wallet = response.wallet {
                            self.currentBalance = wallet.coins
                        }
                        NotificationCenter.default.post(name: NSNotification.Name("WalletBalanceChanged"), object: nil)
                        isPurchasing = nil
                        dismiss()
                    }
                    
                case .userCancelled:
                    await MainActor.run { isPurchasing = nil }
                    
                case .pending:
                    await MainActor.run {
                        self.errorMessage = "Purchase is pending approval. You'll be notified when it's complete."
                        isPurchasing = nil
                    }
                    
                @unknown default:
                    await MainActor.run { isPurchasing = nil }
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Purchase failed: \(error.localizedDescription)"
                    isPurchasing = nil
                }
            }
        }
    }
}
