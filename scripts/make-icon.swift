// Renders the app icon: a frame of colour film close up, sprocket holes along both edges, the edge print in
// colour-stock orange and CONTACT where the stock prints its maker. The frame holds the demo shoot's dusk landscape.
// Usage: swift scripts/make-icon.swift <output.png> <Resources/Fonts/Archivo[wdth,wght].ttf>
import AppKit
import CoreText

CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL, .process, nil)

let space = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
func hex(_ v: UInt32) -> CGColor { rgb(CGFloat((v >> 16) & 255) / 255, CGFloat((v >> 8) & 255) / 255, CGFloat(v & 255) / 255) }
let film = hex(0x0D0C0B), bench = hex(0x1A1917), edge = hex(0xE69A3B)

/// Archivo at a given weight and width ('wght', 'wdth').
func archivo(_ size: CGFloat, weight: CGFloat, width: CGFloat = 100) -> CTFont {
    let base = CTFontCreateWithName("Archivo" as CFString, size, nil)
    let axes: [NSNumber: NSNumber] = [0x77676874: NSNumber(value: Double(weight)), 0x77647468: NSNumber(value: Double(width))]
    return CTFontCreateCopyWithAttributes(base, size, nil, CTFontDescriptorCreateWithAttributes([kCTFontVariationAttribute: axes] as CFDictionary))
}

func text(_ ctx: CGContext, _ s: String, at p: CGPoint, font: CTFont, tracking: CGFloat = 0) {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: NSColor(cgColor: edge)!, .kern: tracking]))
    ctx.textPosition = p
    CTLineDraw(line, ctx)
}

/// The demo shoot's landscape: graded sky, a sun, three layered hills, back to front.
func landscape(_ ctx: CGContext, in r: CGRect, sun: CGPoint, sunRadius: CGFloat) {
    ctx.saveGState()
    ctx.clip(to: r)
    let sky = CGGradient(colorsSpace: space, colors: [hex(0xEDB596), hex(0xD7AB72)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: r.maxY), end: CGPoint(x: 0, y: r.minY + r.height * 0.3), options: [.drawsAfterEndLocation])
    ctx.setFillColor(hex(0xFBD59C))
    ctx.fillEllipse(in: CGRect(x: r.minX + sun.x * r.width - sunRadius, y: r.minY + sun.y * r.height - sunRadius, width: sunRadius * 2, height: sunRadius * 2))
    let hills: [(color: UInt32, base: CGFloat, a1: CGFloat, f1: CGFloat, p1: CGFloat, a2: CGFloat, f2: CGFloat)] = [
        (0x447A4C, 0.44, 0.035, 1.1, 0.4, 0.015, 2.7), (0x2F5843, 0.33, 0.05, 1.4, 2.2, 0.02, 3.1), (0x1E3833, 0.19, 0.06, 1.0, 4.0, 0.015, 2.3),
    ]
    for h in hills {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: r.minX - 10, y: r.minY - 10))
        for step in 0...80 {
            let t = CGFloat(step) / 80
            path.addLine(to: CGPoint(x: r.minX + t * r.width, y: r.minY + (h.base + h.a1 * sin(t * .pi * h.f1 + h.p1) + h.a2 * sin(t * .pi * h.f2)) * r.height))
        }
        path.addLine(to: CGPoint(x: r.maxX + 10, y: r.minY - 10))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(hex(h.color))
        ctx.fillPath()
    }
    ctx.restoreGState()
}

let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// macOS icon grid: an 824pt rounded square centred on the canvas, with the system's soft drop shadow.
let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(0, 0, 0, 0.35))
ctx.addPath(tile)
ctx.setFillColor(film)
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(tile)
ctx.clip()

// One 3:2 frame centred; the frames either side show as slivers, the same evening a moment apart.
let fw: CGFloat = 612, fh: CGFloat = 408, gap: CGFloat = 40
let frame = CGRect(x: 512 - fw / 2, y: 512 - fh / 2 - 6, width: fw, height: fh)
landscape(ctx, in: frame.offsetBy(dx: -(fw + gap), dy: 0), sun: CGPoint(x: 0.5, y: 0.72), sunRadius: 52)
landscape(ctx, in: frame, sun: CGPoint(x: 0.7, y: 0.7), sunRadius: 58)
landscape(ctx, in: frame.offsetBy(dx: fw + gap, dy: 0), sun: CGPoint(x: 0.25, y: 0.66), sunRadius: 50)

// Sprocket holes near both edges, in the bench colour.
let pitch: CGFloat = 74, hole = CGSize(width: 38, height: 54)
var x = 512 - hole.width / 2 - pitch * 7
while x < 1000 {
    for y in [140.0, 830.0] {
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: hole.width, height: hole.height), cornerWidth: 7, cornerHeight: 7, transform: nil))
        ctx.setFillColor(bench)
        ctx.fillPath()
    }
    x += pitch
}

// Edge print above the frame, as the app sets lab film: number, arrow, half-frame number.
let baseline = frame.maxY + 36
text(ctx, "12", at: CGPoint(x: frame.minX + 14, y: baseline), font: archivo(46, weight: 800))
let arrow = CGMutablePath()
let ax = frame.minX + 90, ay = baseline + 16
arrow.move(to: CGPoint(x: ax, y: ay + 15))
arrow.addLine(to: CGPoint(x: ax + 26, y: ay))
arrow.addLine(to: CGPoint(x: ax, y: ay - 15))
arrow.closeSubpath()
ctx.addPath(arrow)
ctx.setFillColor(edge)
ctx.fillPath()
text(ctx, "12A", at: CGPoint(x: frame.midX + 70, y: baseline), font: archivo(40, weight: 700), tracking: 2)

// Below it, the stock's ■■ flanks and the maker's name, set in the wordmark cut (Archivo ExtraCondensed Black).
for i in 0..<2 { ctx.fill(CGRect(x: frame.minX + 16 + CGFloat(i) * 30, y: frame.minY - 62, width: 22, height: 22)) }
text(ctx, "CONTACT", at: CGPoint(x: frame.minX + 92, y: frame.minY - 66), font: archivo(36, weight: 900, width: 62), tracking: 3)
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
