// created by musesum on 1/10/24

import Foundation
extension CGRect {
    public var script: String {
        "(\(minX.digits(0...0)),\(minY.digits(0...0)), \(width.digits(0...0)),\(height.digits(0...0)))"
    }
}
extension CGSize {
    public var script: String {
        "(\(width.digits(0...0)),\(height.digits(0...0)))"
    }
}

extension CGPoint {
    var script: String {
        "(\(x.digits(0...0)),\(y.digits(0...0)))"
    }
}
