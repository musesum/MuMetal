//  MetItem.swift
//  created by musesum on 3/11/23.

import Metal

public struct MetItem {
    
    public let name: String
    public let type: MetNodeType
    
    public init(_ name: String,
                _ type: MetNodeType) {
        
        self.name = name
        self.type = type
    }
}
