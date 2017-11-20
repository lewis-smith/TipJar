//
//  TipJar.swift
//  TipJar
//
//  Created by Lewis Smith on 26/09/2017.
//  Copyright © 2017 Lewis Makes Apps. All rights reserved.
//

import UIKit

final public class TipJar: NSObject {

    public static let shared = TipJar()

    override private init() {}

    public func tipJarViewController() -> TipJarViewController {
        let bundle = Bundle(for: TipJar.self)

        return TipJarViewController(nibName: "TipJarViewController", bundle: bundle)
    }

    public func userHasTipped() -> Bool {
        return IAPHelper.totalSpend() > 0
    }

    public func formattedTipAmount() -> String {
        return IAPHelper.totalSpend()
    }

    public func tipAmount() -> Double {
        return IAPHelper.totalSpend()
    }

}
