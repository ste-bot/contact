// Renders the app icon: the CONTACT mark, a box drawn in white wax pencil, on a matte black tile.
// Usage: swift scripts/make-icon.swift <output.png> <Resources/Brand/wax-box.json>
import AppKit

struct Mark: Decodable { let strokes: String; let secondPass: String }
let mark = try! JSONDecoder().decode(Mark.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))

/// The outline data only uses absolute M, L and Z. Points are on a 1024 grid, y down.
func path(_ d: String) -> CGPath {
    let path = CGMutablePath()
    var numbers: [CGFloat] = [], command: Character = "M", token = ""
    func number() { if let n = Double(token) { numbers.append(n) }; token = "" }
    func point() {
        guard numbers.count == 2 else { return }
        let p = CGPoint(x: numbers[0], y: 1024 - numbers[1])
        if command == "M" { path.move(to: p); command = "L" } else { path.addLine(to: p) }
        numbers.removeAll()
    }
    for c in d {
        switch c {
        case "M", "L": number(); point(); command = c
        case "Z": number(); point(); path.closeSubpath()
        case " ", ",": number(); point()
        default: token.append(c)
        }
    }
    number(); point()
    return path
}

let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let rgb = { (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) in CGColor(srgbRed: r, green: g, blue: b, alpha: a) }

// macOS icon grid: an 824pt rounded square centred on the canvas, with the system's soft drop shadow.
let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(0, 0, 0, 0.35))
context.addPath(tile)
context.setFillColor(rgb(0.07, 0.07, 0.066, 1))
context.fillPath()
context.restoreGState()

// Matte black jacket: a whisper of light from above.
context.saveGState()
context.addPath(tile)
context.clip()
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(0.114, 0.110, 0.102, 1), rgb(0.051, 0.051, 0.047, 1)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
context.restoreGState()
context.addPath(CGPath(roundedRect: CGRect(x: 101, y: 101, width: 822, height: 822), cornerWidth: 184, cornerHeight: 184, transform: nil))
context.setStrokeColor(rgb(1, 1, 1, 0.07))
context.setLineWidth(2)
context.strokePath()

// The box, in its own layer so the wax grain knocks out of the stroke and not the tile.
let wax = (r: 0.953, g: 0.941, b: 0.902)
context.beginTransparencyLayer(auxiliaryInfo: nil)
context.addPath(path(mark.strokes))
context.setFillColor(rgb(wax.r, wax.g, wax.b, 0.94))
context.fillPath()
context.addPath(path(mark.secondPass))
context.setFillColor(rgb(wax.r, wax.g, wax.b, 0.7))
context.fillPath()

var state: UInt64 = 0x434f4e54_41435421 // "CONTACT!"
func unit() -> CGFloat {
    state &+= 0x9e3779b97f4a7c15
    var z = state
    z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
    z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
    return CGFloat(Double((z ^ (z >> 31)) >> 11) / Double(1 << 53))
}
context.setBlendMode(.destinationOut)
// Wax pits are tiny and drag along the stroke: stretched sideways on the top and bottom bars, upright on the sides.
for _ in 0..<5200 {
    let gx = 244 + unit() * 536, gy = 190 + unit() * 628, r = 0.7 + unit() * 1.6
    let along = (abs(gy - 250) < 70 || abs(gy - 766) < 70) ? CGSize(width: r * 3.2, height: r * 1.1) : CGSize(width: r * 1.1, height: r * 3.2)
    context.setFillColor(rgb(0, 0, 0, 0.45 + unit() * 0.45))
    context.fillEllipse(in: CGRect(x: gx - along.width / 2, y: 1024 - gy - along.height / 2, width: along.width, height: along.height))
}
context.endTransparencyLayer()

let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
