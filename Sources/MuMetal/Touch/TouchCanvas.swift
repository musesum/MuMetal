//  created by musesum on 2/5/19.

import UIKit
import MuPeer
import MuVision

public typealias TouchDrawPoint = ((CGPoint, CGFloat)->())
public typealias TouchDrawRadius = ((TouchCanvasItem)->(CGFloat))

open class TouchCanvas {

    static public let shared = TouchCanvas()
    static var touchBuffers = [Int: TouchCanvasBuffer]()
    public var touchRepeat = true /// repeat touch, even when not moving finger
    public var touchFlo = TouchFlo()

    public init() {

        PeersController.shared.peersDelegates.append(self)
    }
    deinit {
        PeersController.shared.remove(peersDelegate: self)
    }
}


// ARKit visionOS Handpose
extension TouchCanvas: TouchCanvasDelegate {

    public func handBegin(_ jointFlo: JointFlo) {
        //print("👍", terminator: "")

        TouchCanvas.touchBuffers[jointFlo.hash] = TouchCanvasBuffer(jointFlo, self)
    }

    public func handUpdate(_ jointFlo: JointFlo) {
        if let touchBuffer = TouchCanvas.touchBuffers[jointFlo.hash] {

            touchBuffer.addTouchHand(jointFlo)
        } else {
            print("\(#function) failed")
        }
    }
}


// UIKit Touches

extension TouchCanvas {
    public func beginTouch(_ touch: UITouch) -> Bool {
        TouchCanvas.touchBuffers[touch.hash] = TouchCanvasBuffer(touch, self)
        return true
    }
    public func updateTouch(_ touch: UITouch) -> Bool {
        if let touchBuffer = TouchCanvas.touchBuffers[touch.hash] {
            touchBuffer.addTouchItem(touch)
            return true
        }
        return false
    }
    public func remoteItem(_ item: TouchCanvasItem) {

        if let touchBuffer = TouchCanvas.touchBuffers[item.key] {
            touchBuffer.addTouchCanvasItem(item)
        } else {
            TouchCanvas.touchBuffers[item.key] = TouchCanvasBuffer(item, self)
        }
    }
    public static func flushTouchCanvas() {
        var removeKeys = [Int]()
        for (key, buf) in touchBuffers {
            let isDone = buf.flushTouches()
            if isDone { removeKeys.append(key) }
        }
        for key in removeKeys {
            touchBuffers.removeValue(forKey: key)
        }
    }

}


