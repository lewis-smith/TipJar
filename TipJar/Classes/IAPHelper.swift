
import StoreKit

public typealias ProductIdentifier = String
public typealias ProductsRequestCompletionHandler = (_ success: Bool, _ products: [SKProduct]?) -> ()

open class IAPHelper : NSObject  {

    public static let IAPHelperPurchaseNotification = Notification.Name("IAPHelperPurchaseNotification")
    static let IAPHelperFailNotification = Notification.Name("IAPHelperFailNotification")
    static let IAPHelperReadyNotification = Notification.Name("IAPHelperReadyNotification")
    static let IAPHelperTotalSpendKey = "IAPHelperTotalSpendKey"

    fileprivate let productIdentifiers: Set<ProductIdentifier>
    fileprivate var purchasedProductIdentifiers = Set<ProductIdentifier>()
    fileprivate var productsRequest: SKProductsRequest?
    fileprivate var productsRequestCompletionHandler: ProductsRequestCompletionHandler?
    public var products: [SKProduct]?

    public init(productIds: Set<ProductIdentifier>) {
        productIdentifiers = productIds
        for productIdentifier in productIds {
            let purchasedCount = UserDefaults.standard.integer(forKey: productIdentifier)
            if purchasedCount > 0 {
                purchasedProductIdentifiers.insert(productIdentifier)
                print("Previously purchased: \(productIdentifier) \(purchasedCount) times")
            } else {
                print("Not purchased: \(productIdentifier)")
            }
        }
        super.init()
        SKPaymentQueue.default().add(self)
    }
}

// MARK: - StoreKit API

extension IAPHelper {

    public func requestProducts(completionHandler: @escaping ProductsRequestCompletionHandler) {
        productsRequest?.cancel()
        productsRequestCompletionHandler = completionHandler

        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest!.delegate = self
        productsRequest!.start()


        let store = NSUbiquitousKeyValueStore.default
        NotificationCenter.default.addObserver(self, selector: #selector(updateIcloud(_:)),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: store)

    }

    public func buyProduct(_ product: SKProduct) {
        print("Buying \(product.productIdentifier)...")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    public func isProductPurchased(_ productIdentifier: ProductIdentifier) -> Bool {
        return purchasedProductIdentifiers.contains(productIdentifier)
    }

    public class func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }

    public func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    public static func totalSpend() -> Double {
        return UserDefaults.standard.double(forKey: IAPHelper.IAPHelperTotalSpendKey)
    }

    public static func totalSpend() -> String {
        return IAPHelper.priceFormatter.string(from: NSNumber(value: self.totalSpend()))!
    }

    public static let priceFormatter: NumberFormatter = {

        let formatter = NumberFormatter()
        formatter.formatterBehavior = .behavior10_4
        formatter.numberStyle = .currency

        return formatter
    }()
}

// MARK: - SKProductsRequestDelegate

extension IAPHelper: SKProductsRequestDelegate {

    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let products = response.products
        print("Loaded list of products...")

        productsRequestCompletionHandler?(true, products)
        clearRequestAndHandler()

        for p in products {
            print("Found product: \(p.productIdentifier) \(p.localizedTitle) \(p.price.floatValue)")
            IAPHelper.priceFormatter.locale = p.priceLocale
        }
        self.products = products
        NotificationCenter.default.post(name: IAPHelper.IAPHelperReadyNotification, object: nil)
    }

    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Failed to load list of products.")
        print("Error: \(error.localizedDescription)")
        productsRequestCompletionHandler?(false, nil)
        clearRequestAndHandler()
    }

    private func clearRequestAndHandler() {
        productsRequest = nil
        productsRequestCompletionHandler = nil
    }
    
}

// MARK: - SKPaymentTransactionObserver

extension IAPHelper: SKPaymentTransactionObserver {

    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch (transaction.transactionState) {
            case .purchased:
                complete(transaction: transaction)
                break
            case .failed:
                fail(transaction: transaction)
                break
            case .restored:
                restore(transaction: transaction)
                break
            case .deferred:
                break
            case .purchasing:
                break
            }
        }
    }

    private func complete(transaction: SKPaymentTransaction) {
        print("complete...")
        deliverPurchaseNotificationFor(identifier: transaction.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func restore(transaction: SKPaymentTransaction) {
        guard let productIdentifier = transaction.original?.payment.productIdentifier else { return }

        print("restore... \(productIdentifier)")
        deliverPurchaseNotificationFor(identifier: productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func fail(transaction: SKPaymentTransaction) {
        print("fail...")
        if let transactionError = transaction.error as NSError? {
            if transactionError.code != SKError.paymentCancelled.rawValue {
                print("Transaction Error: \(transaction.error?.localizedDescription ?? "no description")")
            }
            NotificationCenter.default.post(name: IAPHelper.IAPHelperFailNotification, object: transactionError)
        } else {
            NotificationCenter.default.post(name: IAPHelper.IAPHelperFailNotification, object: nil)
        }
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func deliverPurchaseNotificationFor(identifier: String?) {
        guard let identifier = identifier else { return }

        purchasedProductIdentifiers.insert(identifier)
        var purchasedCount = UserDefaults.standard.integer(forKey: identifier)

        purchasedCount += 1
        UserDefaults.standard.set(purchasedCount, forKey: identifier)

        var totalSpend = UserDefaults.standard.double(forKey: IAPHelper.IAPHelperTotalSpendKey)

        guard products != nil else {
            // we got here because we didn't finish processing the transaction before
            return
        }

        for p in products! {
            if p.productIdentifier == identifier {
                totalSpend += p.price.doubleValue
                break
            }
        }

        NSUbiquitousKeyValueStore.default.set(totalSpend, forKey: IAPHelper.IAPHelperTotalSpendKey)
        UserDefaults.standard.set(totalSpend, forKey:IAPHelper.IAPHelperTotalSpendKey)
        UserDefaults.standard.synchronize()

        NotificationCenter.default.post(name: IAPHelper.IAPHelperPurchaseNotification, object: nil)
    }

    //MARK: - iCloud
    @objc func updateIcloud(_ notification: Notification) {
        // We get more information from the notification, by using:
        // NSUbiquitousKeyValueStoreChangeReasonKey or NSUbiquitousKeyValueStoreChangedKeysKey constants
        // against the notification's useInfo.
        //
        let userInfo:[AnyHashable: Any?] = notification.userInfo!
        let reasonForChange:NSNumber? = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber

        if (reasonForChange != nil)    // reason must be determined in order to perform an update
        {
            // get the reason for the notification (initial download, external change or quota violation change)
            let reasonForChangeValue = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as! Int

            // reason can be:
            //
            // NSUbiquitousKeyValueStoreServerChange:
            //      Value(s) were changed externally from other users/devices.
            //      Get the changes and update the corresponding keys locally.
            //
            // NSUbiquitousKeyValueStoreInitialSyncChange:
            //      Initial downloads happen the first time a device is connected to an iCloud account,
            //      and when a user switches their primary iCloud account.
            //      Get the changes and update the corresponding keys locally.
            //
            // note: if you receive "NSUbiquitousKeyValueStoreInitialSyncChange" as the reason,
            // you can decide to "merge" your local values with the server values
            //
            if reasonForChangeValue == NSUbiquitousKeyValueStoreInitialSyncChange
            {
                // do the merge
                // ... but for this sample we have only one value, so a merge is not necessary
                let totalCloudSpend = NSUbiquitousKeyValueStore.default.double(forKey: IAPHelper.IAPHelperTotalSpendKey)
                let totalLocalSpend = UserDefaults.standard.double(forKey: IAPHelper.IAPHelperTotalSpendKey)

                let totalSpend = totalCloudSpend + totalLocalSpend

                UserDefaults.standard.set(totalSpend, forKey:IAPHelper.IAPHelperTotalSpendKey)
                UserDefaults.standard.synchronize()

                NotificationCenter.default.post(name: IAPHelper.IAPHelperPurchaseNotification, object: nil)

                return
            }

            let changedKeysObject = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey]
            let changedKeys = changedKeysObject as! [String]

            // check if any of the keys we care about were updated, and if so use the new value stored under that key.
            for changedKey:String in changedKeys {
                if changedKey == IAPHelper.IAPHelperTotalSpendKey {
                    // Replace our "selectedColor" with the value from the cloud, but *only* if it's a value we know how to interpret.
                    // It is important to validate any value that comes in through iCloud, because it could have been generated by a different version of your app.
                    let totalSpend = NSUbiquitousKeyValueStore.default.double(forKey: IAPHelper.IAPHelperTotalSpendKey)
                    if totalSpend >= 0 {
                        UserDefaults.standard.set(totalSpend, forKey:IAPHelper.IAPHelperTotalSpendKey)
                        UserDefaults.standard.synchronize()

                        NotificationCenter.default.post(name: IAPHelper.IAPHelperPurchaseNotification, object: nil)
                    }
                    else {
                        // ???!!!???
                    }
                }
            }
        }
    }
}
