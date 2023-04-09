//  Created by warren on 2/21/23.
//  Copyright © 2023 com.deepmuse. All rights reserved.


import Foundation

/// A structure that provides an RGB color intensity value for the roll, pitch, and yaw angles of face pose.
struct MetFaceAngleColors {

    let red: CGFloat
    let blue: CGFloat
    let green: CGFloat

    init(roll: NSNumber?, pitch: NSNumber?, yaw: NSNumber?) {
        red   = 0.4 * MetFaceAngleColors.convert(value: roll, with: -.pi, and: .pi)
        blue  = 0.3 * MetFaceAngleColors.convert(value: pitch, with: -.pi / 2, and: .pi / 2)
        green = 0.3 * MetFaceAngleColors.convert(value: yaw, with: -.pi / 2, and: .pi / 2)
    }

    static func convert(value: NSNumber?, with minValue: CGFloat, and maxValue: CGFloat) -> CGFloat {
        guard let value = value else { return 0 }
        let maxValue = maxValue * 0.8
        let minValue = minValue + (maxValue * 0.2)
        let facePoseRange = maxValue - minValue

        guard facePoseRange != 0 else { return 0 } // protect from zero division

        let colorRange: CGFloat = 1
        return (((CGFloat(truncating: value) - minValue) * colorRange) / facePoseRange)
    }
}
