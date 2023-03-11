//
//  MetItem.swift
//  DeepMuse
//
//  Created by warren on 3/11/23.
//  Copyright © 2023 DeepMuse. All rights reserved.
//

import Metal

public struct MetItem {

    var name = ""
    var size = CGSize.zero
    var device: MTLDevice
    var type = ""

    init(_ name   : String,
         _ device : MTLDevice,
         _ size   : CGSize,
         _ type   : String) {

        self.name   = name
        self.size   = size
        self.device = device
        self.type   = type
    }
}
