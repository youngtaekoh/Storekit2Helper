import Flutter
import StoreKit
import UIKit

public class Storekit2Plugin: NSObject, FlutterPlugin {

  // Mapping of subscription period units to their titles
  let periodTitles = [
    "Day": "Weekly",
    "Week": "Weekly",
    "Month": "Monthly",
    "Year": "Yearly",
  ]

  // Register the plugin with the Flutter plugin registrar
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "storekit2helper", binaryMessenger: registrar.messenger())
    let instance = Storekit2Plugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // Handle method calls from Flutter
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {

    case "initialize":
      // Initialize StoreKit2 (Actually this is not needed in the plugin for External Purchase)
      Task {
        await result(StoreKit2Handler.initialize())
      }

    case "fetchPurchaseHistory":
      // Fetch purchase history
      Task {
        await result(StoreKit2Handler.fetchPurchaseHistory())
      }

    case "hasActiveSubscription":
      // Check if there is an active subscription
      Task {
        let hasSubscription = await StoreKit2Handler.hasActiveSubscription()
        result(hasSubscription)
      }

    case "fetchProducts":
      // Fetch product details
      if let args = call.arguments as? [String: Any],
        let productIDs = args["productIDs"] as? [String]
      {
        StoreKit2Handler.fetchProducts(productIdentifiers: productIDs) { fetchResult in
          switch fetchResult {
          case .success(let products):
            // Convert products to a format that can be sent back to Flutter
            let productDetails = products.map { product -> [String: Any] in

              var data = [
                "productId": product.id,
                "title": product.displayName,
                "description": product.description,
                "price": product.price,
                "periodUnit": String(
                  describing: product.subscription?.subscriptionPeriod.unit
                    ?? Product.SubscriptionPeriod.Unit.day),
                "periodValue": product.subscription?.subscriptionPeriod.value ?? 0,
                "periodTitle": "",
                "json": String(data: product.jsonRepresentation, encoding: .utf8) ?? "",
                "localizedPrice": product.displayPrice,
                "type": String(describing: product.type.rawValue),
                "introductoryOffer": String(
                  describing: product.subscription?.introductoryOffer?.paymentMode.rawValue ?? ""),

                "introductoryOfferPeriod": String(
                  describing: product.subscription?.introductoryOffer?.period.debugDescription ?? ""
                ),
                "isTrial": false,
              ]

              // Set the period title based on the period unit
              if let periodTitle = self.periodTitles[data["periodUnit"] as! String] {
                data["periodTitle"] = periodTitle
              }
              // Check if there is an introductory offer
              if data["introductoryOffer"] as! String != "" {
                data["isTrial"] = true
              }

              return data
            }

            result(productDetails)
          case .failure(let error):
            result(
              FlutterError(
                code: "PRODUCT_FETCH_ERROR", message: error.localizedDescription, details: nil))
          }
        }
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing productIDs", details: nil))
      }

    case "buyProduct":
      // Handle product purchase
      if let args = call.arguments as? [String: Any], let productId = args["productId"] as? String {

        StoreKit2Handler.buyProduct(productId: productId) { success, error, transaction in

          if success {
            // Assuming transaction is not nil if success is true
            let transactionDetails: [String: Any] = [
              "transactionId": transaction!.id,
              "productId": transaction!.productID,
              "appBundleID": transaction!.appBundleID,
              "purchaseDate": Int(transaction!.purchaseDate.timeIntervalSince1970),
              "json": String(data: transaction!.jsonRepresentation, encoding: .utf8) ?? "",

            ]

            result(transactionDetails)
          } else {

            let errorCode = "PURCHASE_ERROR"
            let errorMessage = error?.localizedDescription ?? "error"

            result(FlutterError(code: errorCode, message: errorMessage, details: nil))
          }
        }
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing productId", details: nil))
      }

    case "canMakePayments":
      // Check if payments can be made
      result(StoreKit2Handler.canMakePayments())

    case "presentExternalPurchaseSheet":
      // Present external purchase sheet
    Task {
      do {
        let (token, message) = try await StoreKit2Handler.presentExternalPurchaseSheet()
        result(["token": token, "message": message])
      } catch {
        result(FlutterError(code: "EXTERNAL_PURCHASE_ERROR", message: error.localizedDescription, details: nil))
      }
    }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

}
