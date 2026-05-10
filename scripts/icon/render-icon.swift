#!/usr/bin/env swift
// render-icon.swift — produces a 1024x1024 PNG app icon for WhatsApp MCP.
// Uses SF Symbol `phone.fill` for the handset (proper banana shape),
// surrounded by 3 small "MCP node" dots on a green squircle.

import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xff) / 255.0
        let g = CGFloat((hex >>  8) & 0xff) / 255.0
        let b = CGFloat( hex        & 0xff) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

func squirclePath(rect: CGRect, cornerRadius: CGFloat) -> CGPath {
    return CGPath(roundedRect: rect,
                  cornerWidth: cornerRadius,
                  cornerHeight: cornerRadius,
                  transform: nil)
}

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil,
                          width: Int(size), height: Int(size),
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fputs("Failed to create CGContext\n", stderr); exit(1)
}

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// ---------- 1. Squircle green gradient background ----------
let cornerRadius: CGFloat = size * 0.225
let bgRect = rect.insetBy(dx: 12, dy: 12)
let bg = squirclePath(rect: bgRect, cornerRadius: cornerRadius)

ctx.saveGState()
ctx.addPath(bg)
ctx.clip()

let topColor    = NSColor(hex: 0x2BD16A).cgColor
let bottomColor = NSColor(hex: 0x0E7C5C).cgColor
let gradient = CGGradient(colorsSpace: cs,
                          colors: [topColor, bottomColor] as CFArray,
                          locations: [0.0, 1.0])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: size),
                       end:   CGPoint(x: size, y: 0),
                       options: [])

// Top sheen
let sheenColors = [
    NSColor.white.withAlphaComponent(0.18).cgColor,
    NSColor.white.withAlphaComponent(0.0).cgColor
]
let sheen = CGGradient(colorsSpace: cs, colors: sheenColors as CFArray, locations: [0.0, 1.0])!
ctx.drawLinearGradient(sheen,
                       start: CGPoint(x: size/2, y: size),
                       end:   CGPoint(x: size/2, y: size * 0.55),
                       options: [])
ctx.restoreGState()

// ---------- 2. MCP "node dots" — 3 small white dots in triangular pattern ----------
ctx.saveGState()
ctx.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
let nodeRadius: CGFloat = size * 0.030
let nodes: [CGPoint] = [
    CGPoint(x: size * 0.18, y: size * 0.82),  // top-left
    CGPoint(x: size * 0.82, y: size * 0.82),  // top-right
    CGPoint(x: size * 0.50, y: size * 0.13)   // bottom-center
]
for n in nodes {
    ctx.fillEllipse(in: CGRect(x: n.x - nodeRadius, y: n.y - nodeRadius,
                               width: nodeRadius * 2, height: nodeRadius * 2))
}
ctx.restoreGState()

// ---------- 3. White chat bubbles SF Symbol, large, centered ----------
let symbolName = "bubble.left.and.bubble.right.fill"
let symbolConfig = NSImage.SymbolConfiguration(pointSize: 520, weight: .semibold)
guard let baseSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
    fputs("SF Symbol \(symbolName) unavailable\n", stderr); exit(1)
}
guard let phone = baseSymbol.withSymbolConfiguration(symbolConfig) else {
    fputs("Failed to apply symbol configuration\n", stderr); exit(1)
}
let phoneSize = phone.size

ctx.saveGState()

// Drop shadow
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
shadow.shadowBlurRadius = size * 0.045

// Use NSGraphicsContext to leverage NSImage drawing + tinting
NSGraphicsContext.saveGraphicsState()
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = nsCtx
shadow.set()

// Center + tilt
let centerX = size / 2
let centerY = size / 2
ctx.translateBy(x: centerX, y: centerY)
ctx.translateBy(x: -phoneSize.width / 2, y: -phoneSize.height / 2)

// Tint to white by drawing the symbol mask
let phoneRect = CGRect(origin: .zero, size: phoneSize)
NSColor.white.setFill()

if let cgPhone = phone.cgImage(forProposedRect: nil, context: nsCtx, hints: nil) {
    // Use the symbol's image as a mask, fill with white
    ctx.saveGState()
    ctx.translateBy(x: 0, y: phoneSize.height)
    ctx.scaleBy(x: 1, y: -1)
    ctx.clip(to: phoneRect, mask: cgPhone)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(phoneRect)
    ctx.restoreGState()
}

NSGraphicsContext.restoreGraphicsState()
ctx.restoreGState()

// ---------- Save ----------

guard let cgImage = ctx.makeImage() else {
    fputs("Failed to create CGImage\n", stderr); exit(1)
}
let nsImg = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
guard let tiff = nsImg.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr); exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("✓ Wrote \(outPath) (\(png.count) bytes)")
} catch {
    fputs("Failed to write: \(error)\n", stderr); exit(1)
}
