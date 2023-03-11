//
//  MetItem.swift
//  DeepMuse
//
//  Created by warren on 3/11/23.
//  Copyright © 2023 DeepMuse. All rights reserved.
//

import Metal

public struct MetItem {
    
    public var name = ""
    public var size = CGSize.zero
    public var device: MTLDevice
    public var type = ""
    
    public init(_ name   : String,
                _ device : MTLDevice,
                _ size   : CGSize,
                _ type   : String) {
        
        self.name   = name
        self.size   = size
        self.device = device
        self.type   = type
    }
}
