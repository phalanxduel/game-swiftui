import Foundation
import StoreKit

/// Represents a cosmetic item or supporter pass in the game store
public struct StoreProductItem: Identifiable, Hashable {
    public let id: String
    public let sku: String
    public let name: String
    public let description: String
    public let category: String
    public let priceCents: Int
    public let priceFormatted: String

    public init(id: String, sku: String, name: String, description: String, category: String, priceCents: Int, priceFormatted: String? = nil) {
        self.id = id
        self.sku = sku
        self.name = name
        self.description = description
        self.category = category
        self.priceCents = priceCents
        self.priceFormatted = priceFormatted ?? "$\(Double(priceCents) / 100.0)"
    }
}

/// Manages StoreKit 2 in-app purchases and server entitlement sync
@MainActor
public class StoreManager: ObservableObject {
    public static let shared = StoreManager()

    @Published public private(set) var availableProducts: [StoreProductItem] = []
    @Published public private(set) var storeKitProducts: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var isProcessing: Bool = false
    @Published public var errorMessage: String? = nil

    private var updatesTask: Task<Void, Never>? = nil

    public init() {
        updatesTask = listenForTransactions()
        Task {
            await loadCatalog()
            await updateCustomerProductStatus()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Fetches available product catalog from server and StoreKit
    public func loadCatalog(serverURL: URL = URL(string: "http://127.0.0.1:3001")!) async {
        let endpoint = serverURL.appendingPathComponent("api/store/products")
        do {
            let (data, response) = try await URLSession.shared.data(from: endpoint)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                useFallbackCatalog()
                return
            }

            struct ProductsResponse: Decodable {
                let success: Bool
                let products: [ProductDTO]
            }

            struct ProductDTO: Decodable {
                let id: String
                let sku: String
                let name: String
                let description: String?
                let category: String
                let priceCents: Int
            }

            let decoded = try JSONDecoder().decode(ProductsResponse.self, from: data)
            let items = decoded.products.map { dto in
                StoreProductItem(
                    id: dto.id,
                    sku: dto.sku,
                    name: dto.name,
                    description: dto.description ?? "",
                    category: dto.category,
                    priceCents: dto.priceCents
                )
            }

            self.availableProducts = items.isEmpty ? self.fallbackProducts : items
            let skus = Set(self.availableProducts.map { $0.sku })
            if !skus.isEmpty {
                self.storeKitProducts = (try? await Product.products(for: skus)) ?? []
            }
        } catch {
            useFallbackCatalog()
        }
    }

    private var fallbackProducts: [StoreProductItem] {
        [
            StoreProductItem(
                id: "d8a6e8b2-4f3c-4a1b-9e2a-7c3f8e1b2a3c",
                sku: "com.phalanxduel.supporter_pass_v1",
                name: "Founders Supporter Pass",
                description: "Exclusive gold card frame accent, title badge, and early access supporter perks.",
                category: "supporter_pass",
                priceCents: 499,
                priceFormatted: "$4.99"
            ),
            StoreProductItem(
                id: "e9b7f9c3-5a4d-5b2c-0f3b-8d4a9f2c3b4d",
                sku: "com.phalanxduel.skin_cyber_spades",
                name: "Neon Cyber Spades Deck",
                description: "Cyberpunk animated suit emblems and electric blue column glow effects.",
                category: "card_skin",
                priceCents: 299,
                priceFormatted: "$2.99"
            )
        ]
    }

    private func useFallbackCatalog() {
        self.availableProducts = fallbackProducts
    }

    /// Purchase a StoreKit product
    public func purchase(_ product: Product, userId: String = "local_player") async throws -> Bool {
        isProcessing = true
        defer { isProcessing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await syncEntitlementWithServer(
                userId: userId,
                transactionId: String(transaction.id),
                productId: product.id
            )
            purchasedProductIDs.insert(product.id)
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Direct test purchase for local simulation
    public func simulatePurchase(item: StoreProductItem, userId: String = "local_player", serverURL: URL = URL(string: "http://127.0.0.1:3001")!) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }

        let simulatedTxId = "sim_\(UUID().uuidString)"
        await syncEntitlementWithServer(
            userId: userId,
            transactionId: simulatedTxId,
            productId: item.id,
            serverURL: serverURL
        )
        purchasedProductIDs.insert(item.sku)
        purchasedProductIDs.insert(item.id)
        return true
    }

    /// Synchronizes entitlement record with game server
    public func syncEntitlementWithServer(
        userId: String,
        transactionId: String,
        productId: String,
        serverURL: URL = URL(string: "http://127.0.0.1:3001")!
    ) async {
        let endpoint = serverURL.appendingPathComponent("api/store/verify-purchase")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "userId": userId,
            "productId": productId,
            "transactionId": transactionId,
            "platform": "mac"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await URLSession.shared.data(for: request)
    }

    /// Updates active StoreKit entitlements for current App Store account
    public func updateCustomerProductStatus() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchased.insert(transaction.productID)
            }
        }
        self.purchasedProductIDs = purchased
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.updateCustomerProductStatus()
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
