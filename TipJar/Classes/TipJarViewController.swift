//
//  TipJarViewController.swift
//  TipJar
//
//  Created by Lewis Smith on 26/09/2017.
//  Copyright © 2017 Lewis Makes Apps. All rights reserved.
//

import UIKit
import StoreKit

public class TipJarViewController: UIViewController {

    @IBOutlet var tipButtons: [UIButton]!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tipAmountLabel: UILabel!

    var tipProducts: [SKProduct]?

    public override func viewDidLoad() {
        super.viewDidLoad()

        for button in tipButtons {
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 5
            button.layer.borderColor = self.view.tintColor.cgColor
            button.setTitle("loading...", for: .normal)
            button.isEnabled = false
        }

        self.titleLabel.text = "If you're enjoying \(Bundle.main.infoDictionary!["CFBundleDisplayName"] as? String ?? "this app") and fancy dropping a few spare coins into the tip jar, it would be most appreicated."

        self.updateTipButtonValues(Notification.init(name: IAPHelper.IAPHelperReadyNotification))
        self.updatePaidAmount()

        NotificationCenter.default.addObserver(self, selector: #selector(TipJarViewController.handlePurchaseNotification(_:)),
                                               name: IAPHelper.IAPHelperPurchaseNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(TipJarViewController.handleFailNotification(_:)),
                                               name: IAPHelper.IAPHelperFailNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(TipJarViewController.updateTipButtonValues(_:)),
                                               name: IAPHelper.IAPHelperReadyNotification,
                                               object: nil)
    }

    @IBAction func doneTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }


    @IBAction func tipButtonTapped(_ sender: UIButton) {
        guard self.tipProducts != nil else {
            // not sure how we got here, but we hella don't wanna go any further!
            return
        }

        if self.tipProducts?.count == 0 || sender.tag + 1 > (self.tipProducts?.count)! {
            // ABORT
            return
        }

        JustHUD.shared.showInView(view: self.view, withHeader: "Hold on a sec", andFooter: "Contacting ")


        let productToBuy = self.tipProducts![sender.tag]
        TipProducts.store.buyProduct(productToBuy)

    }

    @objc func handlePurchaseNotification(_ notification: Notification) {
        JustHUD.shared.hide()
        self.updatePaidAmount()
    }

    @objc func handleFailNotification(_ notification: Notification) {
        JustHUD.shared.hide()

        guard notification.object != nil else {
            return
        }

        if let transactionError = notification.object as! NSError? {
            if transactionError.code != SKError.paymentCancelled.rawValue {
                let alertController = UIAlertController(title: "Error with Purchase", message: transactionError.localizedDescription, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "Ok", style: .default, handler: { (action) in
                    alertController.dismiss(animated: true, completion: nil)
                })
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }

    @objc func updateTipButtonValues(_ notification: Notification) {
        self.tipProducts = TipProducts.store.products

        guard self.tipProducts != nil else {
            return
        }

        var i = 0
        for product in self.tipProducts! {
            let button = self.tipButtons[i]
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 5
            button.layer.borderColor = self.view.tintColor.cgColor
            button.isEnabled = true

            button.setTitle(IAPHelper.priceFormatter.string(from:  product.price), for: .normal)

            i += 1
        }
    }

    func updatePaidAmount() {
        var emojii = "😞"
        if IAPHelper.totalSpend() > 0 {
            emojii = "😀"
        }

        if IAPHelper.totalSpend() > 2 {
            emojii = "😊"
        }

        if IAPHelper.totalSpend() > 5 {
            emojii = "😇"
        }

        self.tipAmountLabel.text = "You have tipped a total of \(IAPHelper.totalSpend() as String) \(emojii)"
    }
}
