//
//  MetItem.swift
//  DeepMuse
//
//  Created by warren on 3/11/23.
//  Copyright © 2023 DeepMuse. All rights reserved.
//

import Metal

public struct MetItem {
    
    public let name: String
    public let type: MetType
    
    public init(_ name: String,
                _ type: MetType) {
        
        self.name = name
        self.type = type
    }
}
