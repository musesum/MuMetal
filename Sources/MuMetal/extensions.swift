//
//  File.swift
//  
//
//  Created by warren on 3/11/23.
//

import Foundation

extension CGRect {

    /// normalize to 0...1
    public func normalize() -> ClipRect {
        let x = origin.x
        let y = origin.y
        let w = size.width
        let h = size.height

        let pp = ClipRect(x: x / w,
                          y: y / h,
                          width: (w - 2*x) / w,
                          height:(h - 2*y) / h)
        return pp
    }

    func floats() -> [Float] {
        return [Float(minX),Float(minY),Float(width),Float(height)]
    }
}

extension CGPoint {
    func floats() -> [Float] {
        return [Float(x),Float(y)]
    }
}

extension CGSize {
    
    public static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {

        let ww = lhs.width * rhs
        let hh = lhs.height * rhs
        let s = CGSize(width: ww, height: hh)
        return s
    }

    func floats() -> [Float] {
        return [Float(width),Float(height)]
    }
}

extension String {
    func pad(_ len: Int) -> String {
        return self.padding(toLength: len, withPad: " ", startingAt: 0)
    }
    static func pointer(_ object: AnyObject?) -> String {
        guard let object = object else { return "nil" }
        let opaque: UnsafeMutableRawPointer = Unmanaged.passUnretained(object).toOpaque()
        return String(describing: opaque)
    }
}
