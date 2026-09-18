#!/usr/bin/env swift
import AppKit
import CoreGraphics

let size: CGFloat = 1024

func makeContext() -> CGContext {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return ctx
}

func drawBackground(_ ctx: CGContext, top: NSColor, bottom: NSColor) {
    let colors = [top.cgColor, bottom.cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
}

func drawRadialGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: NSColor, alpha: CGFloat) {
    let colors = [color.withAlphaComponent(alpha).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

// Bulb glyph: rounded bulb head + a small base, drawn with bezier paths.
func drawBulb(_ ctx: CGContext, center: CGPoint, scale: CGFloat, fillTop: NSColor, fillBottom: NSColor) {
    let bulbRadius = 190 * scale
    let bulbCenter = CGPoint(x: center.x, y: center.y + 70 * scale)

    let path = CGMutablePath()
    // Bulb head: circle
    path.addEllipse(in: CGRect(x: bulbCenter.x - bulbRadius, y: bulbCenter.y - bulbRadius, width: bulbRadius * 2, height: bulbRadius * 2))

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors = [fillTop.cgColor, fillBottom.cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: center.x, y: bulbCenter.y + bulbRadius), end: CGPoint(x: center.x, y: bulbCenter.y - bulbRadius), options: [])
    ctx.restoreGState()

    // Base: rounded rect below the bulb
    let baseWidth = bulbRadius * 1.05
    let baseHeight = 130 * scale
    let baseRect = CGRect(x: center.x - baseWidth / 2, y: bulbCenter.y - bulbRadius - baseHeight + 46 * scale, width: baseWidth, height: baseHeight)
    let basePath = CGPath(roundedRect: baseRect, cornerWidth: 34 * scale, cornerHeight: 34 * scale, transform: nil)
    ctx.addPath(basePath)
    ctx.setFillColor(fillBottom.cgColor)
    ctx.fillPath()

    // Filament lines (two short rounded bars) inside the base for detail.
    ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.18).cgColor)
    ctx.setLineWidth(10 * scale)
    ctx.setLineCap(.round)
    let lineY1 = baseRect.minY + baseHeight * 0.35
    let lineY2 = baseRect.minY + baseHeight * 0.65
    ctx.move(to: CGPoint(x: baseRect.minX + 18 * scale, y: lineY1))
    ctx.addLine(to: CGPoint(x: baseRect.maxX - 18 * scale, y: lineY1))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: baseRect.minX + 18 * scale, y: lineY2))
    ctx.addLine(to: CGPoint(x: baseRect.maxX - 18 * scale, y: lineY2))
    ctx.strokePath()
}

func renderIcon(name: String, bgTop: NSColor, bgBottom: NSColor, glowColor: NSColor, bulbTop: NSColor, bulbBottom: NSColor) {
    let ctx = makeContext()
    let center = CGPoint(x: size / 2, y: size / 2)

    drawBackground(ctx, top: bgTop, bottom: bgBottom)
    drawRadialGlow(ctx, center: CGPoint(x: size / 2, y: size * 0.58), radius: size * 0.52, color: glowColor, alpha: 0.55)
    drawBulb(ctx, center: center, scale: 1.05, fillTop: bulbTop, fillBottom: bulbBottom)

    guard let cgImage = ctx.makeImage() else { fatalError("no image") }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("no png data") }

    let outDir = "icon-variants"
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    let outPath = "\(outDir)/\(name).png"
    try? data.write(to: URL(fileURLWithPath: outPath))
    print("Wrote \(outPath)")
}

// Light/default: dark teal-black background (matches the app's near-black gray + teal accent
// design language), bright teal-to-mint bulb as the single focal point.
renderIcon(
    name: "icon_light",
    bgTop: NSColor(calibratedRed: 0x12/255, green: 0x12/255, blue: 0x14/255, alpha: 1),
    bgBottom: NSColor(calibratedRed: 0x04/255, green: 0x20/255, blue: 0x1d/255, alpha: 1),
    glowColor: NSColor(calibratedRed: 0x14/255, green: 0xb8/255, blue: 0xa6/255, alpha: 1),
    bulbTop: NSColor(calibratedRed: 0xcc/255, green: 0xfb/255, blue: 0xf1/255, alpha: 1),
    bulbBottom: NSColor(calibratedRed: 0x14/255, green: 0xb8/255, blue: 0xa6/255, alpha: 1)
)

// Dark appearance: slightly deeper background, same bulb (already reads well on black).
renderIcon(
    name: "icon_dark",
    bgTop: NSColor(calibratedRed: 0x08/255, green: 0x08/255, blue: 0x09/255, alpha: 1),
    bgBottom: NSColor(calibratedRed: 0x02/255, green: 0x14/255, blue: 0x12/255, alpha: 1),
    glowColor: NSColor(calibratedRed: 0x0d/255, green: 0x94/255, blue: 0x88/255, alpha: 1),
    bulbTop: NSColor(calibratedRed: 0xcc/255, green: 0xfb/255, blue: 0xf1/255, alpha: 1),
    bulbBottom: NSColor(calibratedRed: 0x0d/255, green: 0x94/255, blue: 0x88/255, alpha: 1)
)

// Tinted (grayscale mark on dark ground) — macOS doesn't use this the way iOS 18+ does,
// generated anyway for completeness/future-proofing.
renderIcon(
    name: "icon_tinted",
    bgTop: NSColor(calibratedWhite: 0.07, alpha: 1),
    bgBottom: NSColor(calibratedWhite: 0.03, alpha: 1),
    glowColor: NSColor(calibratedWhite: 0.6, alpha: 1),
    bulbTop: NSColor(calibratedWhite: 0.92, alpha: 1),
    bulbBottom: NSColor(calibratedWhite: 0.55, alpha: 1)
)
