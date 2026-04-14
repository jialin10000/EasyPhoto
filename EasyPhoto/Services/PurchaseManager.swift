//
//  PurchaseManager.swift
//  EasyPhoto
//
//  StoreKit 2 内购管理器
//  产品 ID: linjiateam.EasyPhoto.unlockAll（需在 App Store Connect 中创建）
//
//  免费规则：每个文件夹显示前 50 张，多于 50 张的目录需解锁才能看全部。
//  文件夹 ≤ 50 张时，完全没有限制。
//

import StoreKit
import Combine

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    static let productID = "linjiateam.EasyPhoto.unlockAll"
    static let freeLimit = 50

    @Published var isUnlocked: Bool
    @Published var product: Product?
    @Published var isPurchasing: Bool = false
    @Published var errorMessage: String?

    private let unlockKey = "easyPhotoUnlocked"

    private init() {
        isUnlocked = UserDefaults.standard.bool(forKey: "easyPhotoUnlocked")
        Task {
            await loadProduct()
            await checkExistingEntitlements()
        }
        Task { await listenForTransactions() }
    }

    // MARK: - 商品加载

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            self.product = products.first
        } catch {
            print("StoreKit: 无法加载商品: \(error)")
        }
    }

    // MARK: - 购买

    func purchase() async {
        guard let product = product else {
            errorMessage = "无法连接商店，请稍后重试"
            return
        }

        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    unlock()
                    await transaction.finish()
                case .unverified:
                    errorMessage = "购买验证失败，请联系支持"
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "等待批准（家长控制或延迟付款）"
            @unknown default:
                break
            }
        } catch {
            errorMessage = "购买出错：\(error.localizedDescription)"
        }

        isPurchasing = false
    }

    // MARK: - 恢复购买

    func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil
        var found = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID {
                unlock()
                found = true
            }
        }

        if !found {
            errorMessage = "未找到之前的购买记录"
        }
        isPurchasing = false
    }

    // MARK: - 私有

    private func checkExistingEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID {
                unlock()
            }
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID {
                unlock()
                await transaction.finish()
            }
        }
    }

    private func unlock() {
        isUnlocked = true
        UserDefaults.standard.set(true, forKey: unlockKey)
    }
}
