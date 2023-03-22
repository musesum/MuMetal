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
    public var type = ""
    
    public init(_ name: String,
                _ type: String? = nil) {
        
        self.name   = name
        self.type   = type ?? name
    }
}
