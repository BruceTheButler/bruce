#!/usr/bin/env swift
import AppKit
import Foundation

enum IconMode {
  case standard
  case full
}

enum IconPlatform {
  case iOS
  case macOS
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func color(_ red: Int, _ green: Int, _ blue: Int) -> NSColor {
  NSColor(
    calibratedRed: CGFloat(red) / 255,
    green: CGFloat(green) / 255,
    blue: CGFloat(blue) / 255,
    alpha: 1
  )
}

func renderIcon(size: Int, mode: IconMode, platform: IconPlatform) -> Data {
  let alphaInfo: CGImageAlphaInfo = platform == .macOS ? .premultipliedLast : .noneSkipLast
  guard
    let drawingContext = CGContext(
      data: nil,
      width: size,
      height: size,
      bitsPerComponent: 8,
      bytesPerRow: size * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: alphaInfo.rawValue
    )
  else {
    preconditionFailure("Could not create an app icon drawing context.")
  }
  let context = NSGraphicsContext(cgContext: drawingContext, flipped: false)

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  let canvasBounds = NSRect(x: 0, y: 0, width: size, height: size)
  let iconBounds =
    platform == .macOS
    ? canvasBounds.insetBy(dx: CGFloat(size) * 0.1, dy: CGFloat(size) * 0.1)
    : canvasBounds
  let isFullBruce = mode == .full
  (isFullBruce ? color(0, 86, 63) : color(237, 227, 209)).setFill()
  if platform == .macOS {
    drawingContext.clear(canvasBounds)
    NSBezierPath(
      roundedRect: iconBounds,
      xRadius: iconBounds.width * 0.22,
      yRadius: iconBounds.height * 0.22
    ).fill()
  } else {
    iconBounds.fill()
  }

  let sourceName = isFullBruce ? "bruce-full-beer.png" : "bruce-portrait.png"
  let portraitURL = repositoryRoot.appendingPathComponent("docs/branding/\(sourceName)")
  guard let portrait = NSImage(contentsOf: portraitURL) else {
    preconditionFailure("Could not load the canonical Bruce portrait.")
  }
  let clip = platform == .macOS
    ? NSBezierPath(
      roundedRect: iconBounds,
      xRadius: iconBounds.width * 0.22,
      yRadius: iconBounds.height * 0.22
    )
    : NSBezierPath(rect: iconBounds)
  clip.addClip()
  portrait.draw(in: iconBounds, from: .zero, operation: .sourceOver, fraction: 1)

  NSGraphicsContext.restoreGraphicsState()

  guard
    let image = drawingContext.makeImage(),
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  else {
    preconditionFailure("Could not render app icon.")
  }
  return data
}

func writeIcon(path: String, size: Int, mode: IconMode, platform: IconPlatform) throws {
  let destination = repositoryRoot.appendingPathComponent(path)
  try FileManager.default.createDirectory(
    at: destination.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try renderIcon(size: size, mode: mode, platform: platform).write(to: destination)
}

if !CommandLine.arguments.contains("--carplay-only") {
  try writeIcon(
    path: "App/Assets-iOS.xcassets/AppIcon.appiconset/Bruce-1024.png",
    size: 1024,
    mode: .standard,
    platform: .iOS
  )
  try writeIcon(
    path: "App/Assets-iOS.xcassets/AppIconFullBruce.appiconset/FullBruce-1024.png",
    size: 1024,
    mode: .full,
    platform: .iOS
  )

  for size in [16, 32, 64, 128, 256, 512, 1024] {
    try writeIcon(
      path: "App/Assets-macOS.xcassets/AppIcon.appiconset/Bruce-\(size).png",
      size: size,
      mode: .standard,
      platform: .macOS
    )
  }

  try writeIcon(
    path: "App/Assets-macOS.xcassets/FullBruceDockIcon.imageset/FullBruce-512.png",
    size: 512,
    mode: .full,
    platform: .macOS
  )
  try writeIcon(
    path: "App/Assets-macOS.xcassets/FullBruceDockIcon.imageset/FullBruce-1024.png",
    size: 1024,
    mode: .full,
    platform: .macOS
  )
}

for size in [120, 180] {
  try writeIcon(
    path: "App/Assets-iOS.xcassets/AppIcon.appiconset/Bruce-CarPlay-\(size).png",
    size: size, mode: .standard, platform: .iOS)
  try writeIcon(
    path: "App/Assets-iOS.xcassets/AppIconFullBruce.appiconset/FullBruce-CarPlay-\(size).png",
    size: size, mode: .full, platform: .iOS)
}
