//
//  PaywallView.swift
//  EasyPhoto
//
//  付费解锁窗口
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject private var pm = PurchaseManager.shared
    @ObservedObject private var loc = LocalizationManager.shared
    var onDismiss: () -> Void
    var onPurchased: (() -> Void)?

    var body: some View {
        ZStack {
            // 模糊背景
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 图标区
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "camera.aperture")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.white)
                }
                .padding(.top, 40)

                // 标题
                Text(loc.s(.paywallTitle))
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                // 副标题
                Text(loc.s(.paywallSubtitle))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                // 功能列表
                VStack(alignment: .leading, spacing: 10) {
                    FeatureRow(icon: "photo.stack", text: loc.s(.paywallFeature1))
                    FeatureRow(icon: "info.circle", text: loc.s(.paywallFeature2))
                    FeatureRow(icon: "play.rectangle", text: loc.s(.paywallFeature3))
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                Spacer(minLength: 24)

                // 错误提示
                if let error = pm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                }

                // 购买按钮
                Button {
                    Task { await pm.purchase() }
                } label: {
                    ZStack {
                        if pm.isPurchasing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Text(priceLabel)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(pm.isPurchasing || pm.product == nil)
                .padding(.horizontal, 32)

                // 恢复购买
                Button {
                    Task { await pm.restorePurchases() }
                } label: {
                    Text(loc.s(.paywallRestore))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                // 稍后再说
                Button {
                    onDismiss()
                } label: {
                    Text(loc.s(.paywallLater))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .frame(width: 340)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                    .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 8)
            )
        }
        .onChange(of: pm.isUnlocked) { _, unlocked in
            if unlocked {
                if let onPurchased {
                    onPurchased()
                } else {
                    onDismiss()
                }
            }
        }
    }

    private var priceLabel: String {
        if let product = pm.product {
            return "\(loc.s(.paywallUnlock))  \(product.displayPrice)"
        }
        return loc.s(.paywallUnlock)
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    PaywallView(onDismiss: {})
        .frame(width: 600, height: 500)
}
