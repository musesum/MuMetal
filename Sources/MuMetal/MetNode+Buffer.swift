//
//  File.swift
//  
//
//  Created by warren on 12/29/19.
//

import Foundation
import QuartzCore

extension MetNode {

    public func addBuffer(_ key: String,_ val: Any) {

        if nameBuffer.keys.contains(key) { return }
        // compute buffer index is in order of declaration in flo script
        let index = nameBuffer.count
        let metBuffer = MetBuffer(key, index, val, pipeline.device)
        nameBuffer[key] = metBuffer
    }

    public func updateBuffer(_ named: String, _ val: Any) {

        if let buffer = nameBuffer[named] {
            buffer.updateBuf(val)
        } else {
            addBuffer(named, val)
        }
    }
}
