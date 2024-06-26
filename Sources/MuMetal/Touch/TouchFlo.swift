
import QuartzCore
import UIKit
import MuFlo
import MuMetal

public class TouchFlo {

    private var root     : Flo?
    private var tilt˚    : Flo? ; var tilt    = false
    private var press˚   : Flo? ; var press   = true
    private var size˚    : Flo? ; var size    = CGFloat(1)
    private var index˚   : Flo? ; var index   = UInt32(127)
    private var prev˚    : Flo? ; var prev    = CGPoint.zero
    private var next˚    : Flo? ; var next    = CGPoint.zero
    private var force˚   : Flo? ; var force   = CGFloat(0)
    private var radius˚  : Flo? ; var radius  = CGFloat(0)
    private var azimuth˚ : Flo? ; var azimuth = CGPoint.zero
    private var fill˚    : Flo? ; var fill    = Float(-1)
    private var dotOn˚   : Flo? // addDot(f, .began)
    private var dotOff˚  : Flo? // addDot(f, .ended)

    private var bufSize = CGSize.zero
    public var viewSize = CGSize(width: 1920, height: 1080) //????? 
    private var drawBuf: UnsafeMutablePointer<UInt32>?
    private var archive: FloArchive?

    public init() {
    }

    public func parseRoot(_ root: Flo,
                          _ archive: FloArchive) {

        self.root = root
        self.archive = archive

        let sky    = root.bind("sky"   )
        let input  = sky .bind("input" )

        let draw   = sky .bind("draw"  )
        let brush  = draw.bind("brush" )
        let line   = draw.bind("line"  )
        let screen = draw.bind("screen")

        tilt˚    = input .bind("tilt"   ){ f,_ in self.tilt    = f.bool    }
        press˚   = brush .bind("press"  ){ f,_ in self.press   = f.bool    }
        size˚    = brush .bind("size"   ){ f,_ in self.size    = f.cgFloat }
        index˚   = brush .bind("index"  ){ f,_ in self.index   = f.uint32  }
        prev˚    = line  .bind("prev"   ){ f,_ in self.prev    = f.cgPoint }
        next˚    = line  .bind("next"   ){ f,_ in self.next    = f.cgPoint }
        force˚   = input .bind("force"  ){ f,_ in self.force   = f.cgFloat }
        radius˚  = input .bind("radius" ){ f,_ in self.radius  = f.cgFloat }
        azimuth˚ = input .bind("azimuth"){ f,_ in self.azimuth = f.cgPoint }
        fill˚    = screen.bind("fill"   ){ f,_ in self.fill    = f.float   }
        dotOn˚   = draw  .bind("dot.on" ){ f,_ in self.addDot(f, .began)   }
        dotOff˚  = draw  .bind("dot.off"){ f,_ in self.addDot(f, .ended)   }
    }

  func addDot(_ flo: Flo,_ phase: UITouch.Phase) {
        if let exprs = flo.exprs,
           let x = exprs.nameAny["x"] as? FloValScalar,
           let y = exprs.nameAny["y"] as? FloValScalar,
           let z = exprs.nameAny["z"] as? FloValScalar {

            let margin = CGFloat(48)
            let xs = CGFloat(2388/2)
            let ys = CGFloat(1668/2)
            let xx = CGFloat(x.twe) / 12
            let yy = 1 - CGFloat(y.twe / 12)
            let xxx = CGFloat(xx * xs) + margin
            let yyy = CGFloat(yy * ys) - margin
            let point = CGPoint(x: xxx, y: yyy)
            let radius = Float(z.twe/2 + 1)

            let key = "drawDot".hash
            let item = TouchCanvasItem(key, point, radius, .zero, .zero, phase, Visitor(.midi))
            TouchCanvas.shared.remoteItem(item)
        }
    }

}
extension TouchFlo {
    /// get radius of TouchCanvasItem
    public func updateRadius(_ item: TouchCanvasItem) -> CGFloat {

        let visit = item.visit()

        // if using Apple Pencil and brush tilt is turned on
        if item.force > 0, tilt {
            let azi = CGPoint(x: CGFloat(-item.azimY), y: CGFloat(-item.azimX))
            azimuth˚?.setAny(azi, .activate, visit)
            //PrintGesture("azimuth dXY(%.2f,%.2f)", item.azimuth.dx, item.azimuth.dy)
        }

        // if brush press is turned on
        var radiusNow = CGFloat(1)
        if press {
            if force > 0 || item.azimX != 0.0 {
                force˚?.setAny(item.force, .activate, visit) // will update local azimuth via FloGraph
                radiusNow = size
            } else {
                radius˚?.setAny(item.radius, .activate, visit)
                radiusNow = radius
            }
        } else {
            radiusNow = size
        }
        return radiusNow
    }

    public func drawPoint(_ point: CGPoint,
                          _ radius: CGFloat) {

        guard let drawBuf else { return }
        if point == .zero { return }

        #if os(visionOS)
        let scale = CGFloat(3) //?? UITraitCollection().displayScale == 0
        #else
        let scale = UIScreen.main.scale
        #endif

        let viewPoint = point * scale
        let texPoint = viewPointToTexture(viewPoint, viewSize, bufSize) //??????

        let r = radius * 2.0 - 1
        let r2 = Int(r * r / 4.0)
        let texW = Int(bufSize.width)
        let texH = Int(bufSize.height)
        let texMax = Int(bufSize.width * bufSize.height)
        let texX = Int(texPoint.x)
        let texY = Int(texPoint.y)

        var x0 = Int(texPoint.x - radius - 0.5)
        var y0 = Int(texPoint.y - radius - 0.5)
        var x1 = Int(texPoint.x + radius + 0.5)
        var y1 = Int(texPoint.y + radius + 0.5)

        while x0 < 0 { x0 += texW }
        while y0 < 0 { y0 += texH }
        while x1 < x0 { x1 += texW }
        while y1 < y0 { y1 += texH }

        if radius == 1 {
            drawBuf[y0 * texW + x0] = index
            return
        }

        for y in y0 ..< y1 {

            for x in x0 ..< x1  {

                let xd = (x - texX) * (x - texX)
                let yd = (y - texY) * (y - texY)

                if xd + yd < r2 {

                    let yy = (y + texH) % texH  // wrapped pixel y index
                    let xx = (x + texW) % texW  // wrapped pixel x index
                    let ii = (yy * texW + xx) % texMax // final pixel x, y index into buffer

                    drawBuf[ii] = index     // set the buffer to value
                }
            }
        }
    }


    // duplicate in MuMetal::MetAspect
    public func viewPointToTexture(_ point: CGPoint,
                                   _ viewSize: CGSize,
                                   _ texSize: CGSize) -> CGPoint {

        let fill = fillClip(from: texSize, to: viewSize)
        let norm = fill.normalize()
        let x0 = point.x / viewSize.width
        let y0 = point.y / viewSize.height
        let x1 = (x0 + norm.minX) * norm.width * texSize.width
        let y1 = (y0 + norm.minY) * norm.height * texSize.height
        return CGPoint(x: x1, y: y1)
    }

    func drawFill(_ fill: UInt32) {
        guard let drawBuf else { return }

        let w = Int(bufSize.width)
        let h = Int(bufSize.height)
        let count = w * h // count

        for i in 0 ..< count {
            drawBuf[i] = fill
        }
    }
    func drawData() {

        let w = Int(bufSize.width)
        let h = Int(bufSize.height)
        let count = w * h // count

        archive?.textureData["draw"]??.withUnsafeBytes { dataPtr in
            guard let drawBuf else { return }
            let tex32Ptr = dataPtr.bindMemory(to: UInt32.self)
            for i in 0 ..< count {
                drawBuf[i] = tex32Ptr[i]
            }
        }
        archive?.textureData["draw"] = nil
    }
}
extension TouchFlo: TouchDrawDelegate {

    public func setDrawBuffer(_ drawBuf: UnsafeMutablePointer<UInt32>,
                              _ bufSize: CGSize) {

        self.drawBuf = drawBuf
        self.bufSize = bufSize

        if archive?.textureData["draw"] != nil {
            fill = -1 // preempt fill after data
            drawData()
        } else if fill > 255 {
            let fill = UInt32(fill)
            drawFill(fill)
            self.fill = -1
        } else if fill >= 0 {
            let v8 = UInt32(fill * 255)
            let fill = (v8 << 24) + (v8 << 16) + (v8 << 8) + v8
            drawFill(fill)
            self.fill = -1
        }
    }
    // duplicate in MuMetal::MetAspect
    public func fillClip(from: CGSize, to: CGSize) -> CGRect {

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

}
