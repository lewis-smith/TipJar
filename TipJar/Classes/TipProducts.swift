//
//  TipProducts.swift
//  TipJar
//
//  Created by Lewis Smith on 04/10/2017.
//  Copyright © 2017 Lewis Makes Apps. All rights reserved.
//

import Foundation

public struct TipProducts {

    fileprivate static let productIdentifiers: Set<ProductIdentifier> = ["TIP_1",
                                                                         "TIP_2",
                                                                         "TIP_3",
                                                                         "TIP_4"]

    public static let store = IAPHelper(productIds: TipProducts.productIdentifiers)
}

func resourceNameForProductIdentifier(_ productIdentifier: String) -> String? {
    return productIdentifier.components(separatedBy: ".").last
}
