// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

// Renders the ActivitySnitch app icon to AppIcon-1024.png (pass an output path
// as the first argument). Run: swift Scripts/make-icon.swift <out.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * size, y: y * size) }

// Background: dark slate rounded rect with macOS-style margin and corner radius.
let margin = 0.098 * size
let radius = 0.185 * size
let bg = CGPath(
    roundedRect: CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin),
    cornerWidth: radius, cornerHeight: radius, transform: nil)

ctx.saveGState()
ctx.addPath(bg)
ctx.clip()
let bgGrad = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(red: 0.20, green: 0.22, blue: 0.32, alpha: 1).cgColor,
        NSColor(red: 0.06, green: 0.07, blue: 0.12, alpha: 1).cgColor,
    ] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(bgGrad, start: pt(0.5, 1), end: pt(0.5, 0), options: [])

// Faint gauge arc behind the bolt, hinting at monitoring.
ctx.setStrokeColor(NSColor(white: 1, alpha: 0.08).cgColor)
ctx.setLineWidth(0.035 * size)
ctx.setLineCap(.round)
ctx.addArc(
    center: pt(0.5, 0.5), radius: 0.30 * size,
    startAngle: .pi * 1.25, endAngle: .pi * -0.25, clockwise: true)
ctx.strokePath()

// Lightning bolt (y axis points up).
let bolt = CGMutablePath()
bolt.move(to: pt(0.615, 0.865))
bolt.addLine(to: pt(0.315, 0.475))
bolt.addLine(to: pt(0.475, 0.475))
bolt.addLine(to: pt(0.395, 0.135))
bolt.addLine(to: pt(0.695, 0.525))
bolt.addLine(to: pt(0.535, 0.525))
bolt.closeSubpath()

// Soft drop shadow, then gradient fill.
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -0.012 * size), blur: 0.045 * size,
    color: NSColor.black.withAlphaComponent(0.55).cgColor)
ctx.addPath(bolt)
ctx.setFillColor(NSColor(red: 1.0, green: 0.78, blue: 0.15, alpha: 1).cgColor)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(bolt)
ctx.clip()
let boltGrad = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(red: 1.00, green: 0.86, blue: 0.25, alpha: 1).cgColor,
        NSColor(red: 1.00, green: 0.60, blue: 0.05, alpha: 1).cgColor,
    ] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(boltGrad, start: pt(0.5, 0.9), end: pt(0.5, 0.1), options: [])
ctx.restoreGState()

// The snitch part: two watchful eyes on the bolt's upper arm.
func eye(center: CGPoint, r: CGFloat, lookX: CGFloat, lookY: CGFloat) {
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(
        in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    let pr = r * 0.48
    let px = center.x + lookX * r * 0.38
    let py = center.y + lookY * r * 0.38
    ctx.setFillColor(NSColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: px - pr, y: py - pr, width: 2 * pr, height: 2 * pr))
    // tiny highlight
    let hr = r * 0.14
    ctx.setFillColor(NSColor(white: 1, alpha: 0.9).cgColor)
    ctx.fillEllipse(
        in: CGRect(x: px - pr * 0.35 - hr, y: py + pr * 0.35 - hr, width: 2 * hr, height: 2 * hr))
}
eye(center: pt(0.475, 0.640), r: 0.052 * size, lookX: -0.6, lookY: -0.4)
eye(center: pt(0.585, 0.655), r: 0.052 * size, lookX: -0.6, lookY: -0.4)

ctx.restoreGState()  // background clip

NSGraphicsContext.current?.flushGraphics()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
