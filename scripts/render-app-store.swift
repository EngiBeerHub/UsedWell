// Usage: swift scripts/render-app-store.swift <raw PNG directory> <output directory>
// Composes actual English Simulator captures; never redraws or replaces app UI.
import AppKit

let arguments = CommandLine.arguments
precondition(arguments.count == 3, "Provide raw and output directories")
let source = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let width = 1284
let height = 2778

func capture(_ name: String) -> NSImage {
  guard let image = NSImage(contentsOf: source.appendingPathComponent(name)) else {
    fatalError("Missing capture: \(name)")
  }
  return image
}

func write(_ image: NSImage, to url: URL) throws {
  let context = CGContext(
    data: nil, width: Int(image.size.width), height: Int(image.size.height),
    bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
  image.draw(in: NSRect(origin: .zero, size: image.size))
  NSGraphicsContext.restoreGraphicsState()
  let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
  try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

func text(_ string: String, top: CGFloat, size: CGFloat, color: NSColor) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.lineSpacing = 14
  (string as NSString).draw(
    in: NSRect(x: 84, y: CGFloat(2778) - top - 300, width: 1120, height: 300),
    withAttributes: [
      .font: NSFont.systemFont(ofSize: size, weight: size == 80 ? .bold : .medium),
      .foregroundColor: color, .paragraphStyle: paragraph
    ])
}

func panel(
  _ image: NSImage, left: CGFloat, top: CGFloat, width: CGFloat,
  height: CGFloat, sourceTop: CGFloat = 0
) {
  let rect = NSRect(x: left, y: 2778 - top - height, width: width, height: height)
  NSGraphicsContext.saveGraphicsState()
  NSBezierPath(roundedRect: rect, xRadius: 44, yRadius: 44).addClip()
  let scaledHeight = image.size.height * width / image.size.width
  image.draw(
    in: NSRect(x: left, y: rect.maxY - scaledHeight + sourceTop, width: width, height: scaledHeight)
  )
  NSGraphicsContext.restoreGraphicsState()
}

let home = capture("en-US-01-home.png")
let detail = capture("en-US-02-detail.png")
let notes = capture("en-US-03-cost-notes.png")
let costs = capture("en-US-14-cost.png")
let headings = [
  "Is it time to replace\nthis iPhone?",
  "See how long\nyou've owned it",
  "Don't replace it\non a whim",
  "Keep notes on\nwhat you notice",
  "What does it\ncost per day?"
]
let subtitles = [
  "Reflect on time owned, your own goals, and how it feels to use.",
  "Your time with it and your own usage goal, together at a glance.",
  "Use your own goal and your experience to help you decide.",
  "Look back at dated notes on what's changed—and what's still good.",
  "One more perspective when deciding whether to keep using it."
]
let names = ["01-hero", "02-progress", "03-decision", "04-notes", "05-cost"]
var images: [NSImage] = []
for index in 0..<5 {
  let image = NSImage(size: NSSize(width: width, height: height))
  image.lockFocus()
  NSGradient(
    starting: NSColor(red: 0.973, green: 0.98, blue: 0.995, alpha: 1),
    ending: NSColor(red: 0.94, green: 0.955, blue: 0.985, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)
  text(
    headings[index], top: 154, size: 80,
    color: NSColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1))
  text(
    subtitles[index], top: 431, size: 29,
    color: NSColor(red: 0.38, green: 0.41, blue: 0.46, alpha: 1))
  switch index {
  case 0: panel(home, left: 82, top: 1000, width: 1120, height: 1778)
  case 1: panel(detail, left: 82, top: 1010, width: 1120, height: 1768)
  case 2:
    panel(detail, left: 82, top: 790, width: 800, height: 1290, sourceTop: 145)
    panel(notes, left: 402, top: 1830, width: 800, height: 900, sourceTop: 180)
  case 3: panel(notes, left: 82, top: 1010, width: 1120, height: 1768)
  default: panel(costs, left: 72, top: 1010, width: 1120, height: 1768, sourceTop: 0)
  }
  image.unlockFocus()
  try write(image, to: output.appendingPathComponent(names[index] + ".png"))
  images.append(image)
}
let sheet = NSImage(size: NSSize(width: 1500, height: 649))
sheet.lockFocus()
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 1500, height: 649).fill()
for (index, image) in images.enumerated() {
  image.draw(in: NSRect(x: index * 300, y: 0, width: 300, height: 649))
}
sheet.unlockFocus()
try write(sheet, to: output.appendingPathComponent("contact-sheet.png"))

// Side-by-side original UI captures for copy and layout review in the task handoff.
let reviewDirectory = output.deletingLastPathComponent().appendingPathComponent("ui-review")
try FileManager.default.createDirectory(at: reviewDirectory, withIntermediateDirectories: true)
for name in ["01-home", "02-detail", "03-cost-notes", "06-edit-item", "region-notice"] {
  let pair = NSImage(size: NSSize(width: 1206, height: 1311))
  pair.lockFocus()
  capture("ja-JP-\(name).png").draw(in: NSRect(x: 0, y: 0, width: 603, height: 1311))
  capture("en-US-\(name).png").draw(in: NSRect(x: 603, y: 0, width: 603, height: 1311))
  pair.unlockFocus()
  try write(pair, to: reviewDirectory.appendingPathComponent("\(name)-ja-en.png"))
}
