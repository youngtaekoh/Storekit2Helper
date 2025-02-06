import StoreKit



class StoreKit2Handler {
    
    
    
       static func initialize()async{
             
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    
                    await transaction.finish()
                }
            }
            
       }
       
    
    static func fetchProducts(productIdentifiers: [String], completion: @escaping (Result<[Product], Error>) -> Void) {
        Task {
            do {
                
                let allProducts = try await Product.products(for: productIdentifiers)
                
                let sortedProducts = productIdentifiers.compactMap { identifier in
                    allProducts.first(where: { $0.id == identifier })
                }
                
                completion(.success(sortedProducts))
                
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    static  func hasActiveSubscription() async -> Bool {
        
        for await verificationResult in Transaction.currentEntitlements {
            switch verificationResult {
                
            case .verified(_):
                return true
                
            case .unverified(_, _): break
                
            }
        }
        return false
    }
    
    static func buyProduct(productId productID: String, completion: @escaping (Bool, Error?, Transaction?) -> Void) {
        Task {
            do {
                // Fetch the products
                let products = try await Product.products(for: [productID])
                guard let product = products.first else {
                    // Handle the case where the product is not found
                    completion(false, NSError(domain: "StoreKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Product not found"]),nil)
                    return
                }
                
              
                // Attempt to purchase the product
                let result = try await product.purchase()
                 
                
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction ):
                        
                        await transaction.finish()
                        
                        // Call completion handler indicating success
                        completion(true, nil,  transaction )
                    case .unverified:
                        // Handle unverified transaction
                        completion(false, NSError(domain: "StoreKitError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Transaction unverified"]),nil)
                    }
                case .pending:
                    // Handle pending state if needed
                    break
                case .userCancelled:
                    // User cancelled the purchase
                    
                    completion(false, NSError(domain: "StoreKitError", code: -3, userInfo: [NSLocalizedDescriptionKey: "User cancelled"]),nil)
                @unknown default:
                    // Handle unexpected cases
                    completion(false, NSError(domain: "StoreKitError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unknown purchase result"]),nil)
                }
                
            } catch {
                
                completion(false, error,nil)
            }
        }
    }
    
    
    

    
    
   static func fetchPurchaseHistory() async ->   [String]  {
   
       var all : [String] = []
     
       for await verificationResult in Transaction.all {
           switch verificationResult {
               
           case .verified(let transaction):
             
               all.append(String(data:  transaction.jsonRepresentation, encoding: .utf8) ?? "")
                
           case .unverified(_, _): break
              
               
           }
       }
       return all
    }

    static func canMakePayments() -> Bool {
        return AppStore.canMakePayments
    }

    static func presentExternalPurchaseSheet() async -> (token: String?, message: String) {
        var purchaseToken: String? = nil
        var resultMessage: String = ""
        var canPresent: Bool = false
        if #available(iOS 17.4, *) {
            canPresent = await ExternalPurchase.canPresent
            print("ExternalPurchase.canPresent: \(canPresent)")
        }

        if !canPresent {
            resultMessage = "External purchases are not supported."
            return (nil, resultMessage)
        }

        do {
            let result = try await ExternalPurchase.presentNoticeSheet()

            switch result {
                case .continuedWithExternalPurchaseToken(let token):
                    resultMessage = "Moved to external purchase page."
                    purchaseToken = token

                case .cancelled:
                    resultMessage = "User cancelled the external purchase."

                @unknown default:
                    resultMessage = "Unknown error occurred"
            }
        } catch {
            resultMessage = "Error: \(error.localizedDescription)"
        }
        return (purchaseToken, resultMessage)
    }
}

