import StoreKit

@Observable
final class StoreKitService {
    private(set) var isAdFree = false
    private(set) var adFreeProduct: Product?
    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    private static let adFreeProductID = "com.iwakisyogo.QuickMemo.adfree"

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.adFreeProductID {
                isAdFree = true
                return
            }
        }
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.adFreeProductID])
            adFreeProduct = products.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product = adFreeProduct else { return }
        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "購入の検証に失敗しました"
                    break
                }
                isAdFree = true
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }

    func restore() async {
        errorMessage = nil
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                if transaction.productID == Self.adFreeProductID {
                    await MainActor.run {
                        self?.isAdFree = true
                    }
                    await transaction.finish()
                }
            }
        }
    }
}
