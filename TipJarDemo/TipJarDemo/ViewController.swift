//
//  ViewController.swift
//  TipJarDemo
//
//  Created by Lewis Smith on 26/09/2017.
//  Copyright © 2017 Lewis Makes Apps. All rights reserved.
//

import UIKit
import TipJar

class ViewController: UIViewController {

    @IBOutlet weak var tipAmount: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.updatePaidAmount()

        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.handlePurchaseNotification(_:)),
                                               name: IAPHelper.IAPHelperPurchaseNotification,
                                               object: nil)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func tipJarTapped(_ sender: Any) {
        self.present(TipJar.shared.tipJarViewController(), animated: true, completion: nil)
    }

    @objc func handlePurchaseNotification(_ notification: Notification) {
        self.updatePaidAmount()
    }

    func updatePaidAmount() {
        self.tipAmount.text = TipJar.shared.formattedTipAmount()
    }
}
