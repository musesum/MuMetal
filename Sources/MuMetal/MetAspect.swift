//  Created by warren on 8/3/21.
//

import UIKit

/// x,y clips inside width,height
public typealias ClipRect = CGRect

public class MetAspect {

    /** create a clipping rect where x,y is inside boundary, not offset
    - Parameters:
      - from: sourc size to rescale and clip
      - to: destination size in which to fill
     */
    static public func fillClip(from: CGSize, to: CGSize) -> ClipRect {

        let ht = to.height      // height to
        let wt = to.width       // width to
        let rt = wt/ht          // ratio to

        let hf = from.height    // height from
        let wf = from.width     // width from
        let rf = wf/hf          // ratio from

        if rt < rf {

            let h = ht
            let w = wf * (ht/hf)
            let x = (w-wt) / 2
            let y = CGFloat(0)

            return CGRect(x: x, y: y, width: w, height: h)

        } else if rt > rf {

            let w = wt
            let h = hf * (wt/wf)
            let y = (h-ht) / 2
            let x = CGFloat(0)

            return CGRect(x: x, y: y, width: w, height: h)

        } else {

            return CGRect(x: 0, y: 0, width: wt, height: ht)
        }
    }

    /** create a clipping rect where x,y is inside boundary, not offset
    - Parameters:
     - p: point in captured in view
     - viewSize: view which captured point in its coordinates
     - texSize: original texture which filled view, which may be clipped
     */
    static public func viewPointToTexture(_ p: CGPoint, viewSize: CGSize, texSize: CGSize) -> CGPoint {

        let fill = fillClip(from: texSize, to: viewSize)
        let norm = fill.normalize()
        let x0 = p.x / viewSize.width
        let y0 = p.y / viewSize.height
        let x1 = (x0 + norm.minX) * norm.width * texSize.width
        let y1 = (y0 + norm.minY) * norm.height * texSize.height
        return CGPoint(x: x1, y: y1)
    }

}
