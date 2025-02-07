import StoreKit

class StoreKit2Handler {
    // Initialize the StoreKit2Handler and listen for transaction updates
    static func initialize() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                // Finish the transaction
                await transaction.finish()
            }
        }
    }

    // Fetch products from the App Store based on product identifiers
    static func fetchProducts(
        productIdentifiers: [String], completion: @escaping (Result<[Product], Error>) -> Void
    ) {
        Task {
            do {
                // Fetch all products for the given identifiers
                let allProducts = try await Product.products(for: productIdentifiers)

                // Sort the products based on the provided identifiers
                let sortedProducts = productIdentifiers.compactMap { identifier in
                    allProducts.first(where: { $0.id == identifier })
                }

                // Return the sorted products
                completion(.success(sortedProducts))
            } catch {
                // Handle any errors that occur during product fetching
                completion(.failure(error))
            }
        }
    }

    // Check if there is an active subscription
    static func hasActiveSubscription() async -> Bool {
        for await verificationResult in Transaction.currentEntitlements {
            switch verificationResult {
            case .verified(_):
                // Return true if there is a verified transaction
                return true
            case .unverified(_, _):
                break
            }
        }
        // Return false if no active subscription is found
        return false
    }

    // Purchase a product with the given product ID
    static func buyProduct(
        productId productID: String, completion: @escaping (Bool, Error?, Transaction?) -> Void
    ) {
        Task {
            do {
                // Fetch the products for the given product ID
                let products = try await Product.products(for: [productID])
                guard let product = products.first else {
                    // Handle the case where the product is not found
                    completion(
                        false,
                        NSError(
                            domain: "StoreKitError", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Product not found"]), nil)
                    return
                }

                // Attempt to purchase the product
                let result = try await product.purchase()

                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        // Finish the transaction and indicate success
                        await transaction.finish()
                        completion(true, nil, transaction)
                    case .unverified:
                        // Handle unverified transaction
                        completion(
                            false,
                            NSError(
                                domain: "StoreKitError", code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "Transaction unverified"]), nil)
                    }
                case .pending:
                    // Handle pending state if needed
                    break
                case .userCancelled:
                    // User cancelled the purchase
                    completion(
                        false,
                        NSError(
                            domain: "StoreKitError", code: -3,
                            userInfo: [NSLocalizedDescriptionKey: "User cancelled"]), nil)
                @unknown default:
                    // Handle unexpected cases
                    completion(
                        false,
                        NSError(
                            domain: "StoreKitError", code: -3,
                            userInfo: [NSLocalizedDescriptionKey: "Unknown purchase result"]), nil)
                }
            } catch {
                // Handle any errors that occur during the purchase
                completion(false, error, nil)
            }
        }
    }

    // Fetch the purchase history
    static func fetchPurchaseHistory() async -> [String] {
        var all: [String] = []

        for await verificationResult in Transaction.all {
            switch verificationResult {
            case .verified(let transaction):
                // Append the transaction JSON representation to the result list
                all.append(String(data: transaction.jsonRepresentation, encoding: .utf8) ?? "")
            case .unverified(_, _):
                break
            }
        }
        // Return the list of purchase history
        return all
    }

    // Check if the user can make payments
    static func canMakePayments() -> Bool {
        return AppStore.canMakePayments
    }

    // Present an external purchase sheet and return the result
    static func presentExternalPurchaseSheet() async -> (token: String?, message: String) {
        var purchaseToken: String? = nil
        var resultMessage: String = ""

        // Check if external purchases can be presented
        let canPresent = await ExternalPurchase.canPresent

        if (!canPresent) {
            resultMessage = "External purchases are not supported."
            return (nil, resultMessage)
        }

        do {
            // Present the external purchase notice sheet
            let result = try await ExternalPurchase.presentNoticeSheet()

            switch result {
            case .continuedWithExternalPurchaseToken(let token):
                resultMessage = "Move to external purchase page."
                if let decodedData = Data(base64Encoded: token) {
                    purchaseToken = String(data: decodedData, encoding: .utf8)!
                }
            case .cancelled:
                resultMessage = "User cancelled the external purchase."
            @unknown default:
                resultMessage = "Unknown error occurred"
            }
        } catch {
            // Handle any errors that occur during the external purchase
            resultMessage = "Error: \(error.localizedDescription)"
        }
        // Return the purchase token and result message
        return (purchaseToken, resultMessage)
    }
}
