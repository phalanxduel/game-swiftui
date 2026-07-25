import SwiftUI
import StoreKit

public struct StoreView: View {
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PHALANX STORE")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(Color.goldAccent)
                    Text("Cosmetics, Themes & Supporter Passes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.1))

            Divider()

            // Products Grid / List
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(storeManager.availableProducts) { product in
                        ProductCardView(product: product)
                    }
                }
                .padding()
            }
            .background(Color(white: 0.05).ignoresSafeArea())
        }
        .frame(minWidth: 480, minHeight: 520)
    }
}

struct ProductCardView: View {
    let product: StoreProductItem
    @StateObject private var storeManager = StoreManager.shared
    @State private var isPurchasing = false
    @State private var showSuccess = false

    var isOwned: Bool {
        storeManager.purchasedProductIDs.contains(product.sku) || storeManager.purchasedProductIDs.contains(product.id)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Category Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(product.category == "supporter_pass" ? Color.goldAccent.opacity(0.2) : Color.amberHighlight.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(product.category == "supporter_pass" ? Color.goldAccent : Color.amberHighlight, lineWidth: 1)
                    )

                Image(systemName: product.category == "supporter_pass" ? "crown.fill" : "paintpalette.fill")
                    .font(.title2)
                    .foregroundColor(product.category == "supporter_pass" ? Color.goldAccent : Color.amberHighlight)
            }

            // Description & Title
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(product.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    if product.category == "supporter_pass" {
                        Text("FOUNDER")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.goldAccent)
                            .foregroundColor(.black)
                            .cornerRadius(4)
                    }
                }

                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Purchase / Owned Action Button
            if isOwned {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color.emeraldGreen)
                    Text("OWNED")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.emeraldGreen)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.emeraldGreen.opacity(0.15))
                .cornerRadius(8)
            } else {
                Button(action: {
                    Task {
                        isPurchasing = true
                        let success = await storeManager.simulatePurchase(item: product)
                        isPurchasing = false
                        if success {
                            showSuccess = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        if isPurchasing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text(product.priceFormatted)
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .frame(minWidth: 80)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.goldAccent)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isOwned ? Color.emeraldGreen.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
