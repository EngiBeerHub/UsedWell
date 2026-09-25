// Usage: swift scripts/render-app-store.swift <raw PNG directory> <output directory> <ja-JP|en-US>
// D+ polished: full device context with floating runtime crops on slides 2, 3, and 5.
// All app content comes from runtime captures. Only framing and Store copy are drawn.
import AppKit

struct StoreSlide: Decodable {
  let name: String
  let headline: String
  let subcopy: String
}

let arguments = CommandLine.arguments
precondition(arguments.count == 4, "Provide raw directory, output directory, and locale")
let source = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
let locale = arguments[3]
let scripts = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let copy = try JSONDecoder().decode(
  [String: [StoreSlide]].self,
  from: Data(contentsOf: scripts.appendingPathComponent("app-store-copy.json")))
guard let slides = copy[locale], slides.count == 5 else {
  fatalError("Expected five reviewed slides for \(locale)")
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let canvasWidth = 1284
let canvasHeight = 2778
let slideNames = ["01-hero", "02-progress", "03-notes", "04-themes", "05-cost"]
precondition(slides.map(\.name) == slideNames, "Unexpected Store story or output names")
let japanese = locale == "ja-JP"

func color(_ hex: UInt32) -> NSColor {
  NSColor(
    srgbRed: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
    blue: Double(hex & 255) / 255, alpha: 1)
}

func rect(_ left: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
  NSRect(x: left, y: CGFloat(canvasHeight) - top - height, width: width, height: height)
}

func imageAt(_ url: URL) -> NSImage {
  guard let data = try? Data(contentsOf: url),
    let representation = NSBitmapImageRep(data: data),
    let cgImage = representation.cgImage
  else { fatalError("Cannot load \(url.path)") }
  return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
}

func runtime(_ name: String, crop: CGRect? = nil) -> NSImage {
  let original = imageAt(source.appendingPathComponent("\(locale)-\(name).png"))
  // Crops target iPhone 17 Pro / standard text size, captured at native 3x resolution.
  precondition(original.size == NSSize(width: 1206, height: 2622), "Capture on iPhone 17 Pro")
  guard let crop else { return original }
  precondition(
    CGRect(origin: .zero, size: original.size).contains(crop), "Crop outside runtime image")
  let cgImage = original.cgImage(forProposedRect: nil, context: nil, hints: nil)!
  return NSImage(cgImage: cgImage.cropping(to: crop)!, size: crop.size)
}

func text(
  _ string: String, left: CGFloat = 78, top: CGFloat, width: CGFloat = 1128,
  height: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, ink: NSColor,
  spacing: CGFloat = 26
) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.lineSpacing = spacing
  // Use macOS fonts so regeneration does not depend on downloaded fonts.
  let font =
    japanese
    ? NSFont(name: weight == .regular ? "HiraginoSans-W3" : "HiraginoSans-W6", size: size)!
    : NSFont.systemFont(ofSize: size, weight: weight)
  let attributed = NSAttributedString(
    string: string,
    attributes: [
      .font: font,
      .foregroundColor: ink, .paragraphStyle: paragraph
    ])
  for line in string.components(separatedBy: "\n") {
    let lineWidth = (line as NSString).size(withAttributes: [.font: font]).width
    precondition(lineWidth <= width, "Store text wraps unexpectedly: \(line)")
  }
  let bounds = attributed.boundingRect(
    with: NSSize(width: width, height: 10_000), options: [.usesLineFragmentOrigin]
  )
  precondition(bounds.height <= height, "Store text overflows: \(string)")
  attributed.draw(with: rect(left, top, width, height), options: [.usesLineFragmentOrigin])
}

func roundedImage(_ image: NSImage, frame: NSRect, radius: CGFloat) {
  NSGraphicsContext.saveGraphicsState()
  NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).addClip()
  image.draw(in: frame)
  NSGraphicsContext.restoreGraphicsState()
}

func device(_ image: NSImage, left: CGFloat, top: CGFloat, width: CGFloat) {
  // Generic device silhouette, not Apple artwork or an illustration of a specific iPhone.
  // No sensor housing, camera, hardware buttons, logos, or other Apple-specific details.
  // https://developer.apple.com/app-store/marketing/guidelines/#section-product-images
  let scale = width / 860
  let inset = 26 * scale
  let screenWidth = width - inset * 2
  let screenHeight = screenWidth * image.size.height / image.size.width
  let body = NSBezierPath(
    roundedRect: rect(left, top, width, screenHeight + inset * 2),
    xRadius: 115 * scale, yRadius: 115 * scale)
  color(0x20201E).setFill()
  body.fill()
  color(0x76756F).setStroke()
  body.lineWidth = 2 * scale
  body.stroke()
  roundedImage(
    image, frame: rect(left + inset, top + inset, screenWidth, screenHeight), radius: 89 * scale)
}

func overlay(_ image: NSImage) {
  let width: CGFloat = 1152
  let height = image.size.height * width / image.size.width
  let frame = rect(66, 2596 - height, width, height)
  let path = NSBezierPath(roundedRect: frame, xRadius: 34, yRadius: 34)
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = color(0x433524).withAlphaComponent(0.10)
  shadow.shadowBlurRadius = 28
  shadow.shadowOffset = NSSize(width: 0, height: -10)
  shadow.set()
  color(0xFBF6ED).setFill()
  path.fill()
  NSGraphicsContext.restoreGraphicsState()
  roundedImage(image, frame: frame, radius: 34)
  color(0xBAA486).withAlphaComponent(0.7).setStroke()
  path.lineWidth = 2.5
  path.stroke()
}

func render(width: Int, height: Int, draw: () -> Void) -> NSBitmapImageRep {
  let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
  context.interpolationQuality = .high
  draw()
  NSGraphicsContext.restoreGraphicsState()
  return NSBitmapImageRep(cgImage: context.makeImage()!)
}

var finished: [NSImage] = []
for (index, slide) in slides.enumerated() {
  let bitmap = render(width: canvasWidth, height: canvasHeight) {
    color(0xF0E6D7).setFill()
    NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight).fill()
    text(
      slide.headline, top: index == 3 ? 100 : 130, height: 310,
      size: index == 1 || index == 2 ? 108 : 100, weight: .semibold, ink: color(0x302B25))
    if !slide.subcopy.isEmpty {
      text(
        slide.subcopy, left: 82, top: 493, width: 1120, height: 225, size: 80,
        ink: color(0x675748))
    }
    switch index {
    case 0:
      device(runtime("01-home"), left: 144, top: 566, width: 996)
    case 1:
      device(runtime("01-home"), left: 212, top: 854, width: 860)
      // R4 crop: the entire photo, name, state, duration, goal, and 95% form one block.
      overlay(runtime("01-home", crop: CGRect(x: 108, y: 792, width: 990, height: 936)))
    case 2:
      device(runtime("02-detail"), left: 212, top: 854, width: 860)
      // English notes wrap to more lines; include all three notes at the same magnification.
      overlay(
        runtime(
          "02-detail", crop: CGRect(x: 48, y: 1270, width: 1110, height: japanese ? 775 : 900)))
    case 3:
      for (offset, name, background, ink, capture) in [
        (0, "Warm", UInt32(0xE6D7BE), UInt32(0x965334), "01-home"),
        (624, "Forest", UInt32(0xD0DAC7), UInt32(0x234A3D), "04-home-forest")
      ] {
        color(background).setFill()
        rect(offset == 0 ? 0 : 642, 730, 642, 2048).fill()
        text(
          name, left: CGFloat(64 + offset), top: 994, width: 550, height: 110,
          size: 78, weight: .semibold, ink: color(ink))
        device(runtime(capture), left: CGFloat(48 + offset), top: 1130, width: 564)
      }
    default:
      device(runtime("05-cost"), left: 212, top: 854, width: 860)
      overlay(runtime("05-cost", crop: CGRect(x: 48, y: 1590, width: 1110, height: 600)))
    }
  }
  try bitmap.representation(using: .png, properties: [:])!.write(
    to: output.appendingPathComponent(slide.name + ".png"))
  finished.append(
    NSImage(cgImage: bitmap.cgImage!, size: NSSize(width: canvasWidth, height: canvasHeight)))
}
for (name, width) in [
  ("contact-sheet", 400), ("contact-sheet-240px", 240), ("contact-sheet-180px", 180)
] {
  let height = Int((Double(width) * Double(canvasHeight) / Double(canvasWidth)).rounded())
  let sheet = render(width: width * 5, height: height) {
    for (index, image) in finished.enumerated() {
      image.draw(in: NSRect(x: index * width, y: 0, width: width, height: height))
    }
  }
  try sheet.representation(using: .png, properties: [:])!.write(
    to: output.appendingPathComponent(name + ".png"))
}
print("Rendered \(locale): five 1284 x 2778 sRGB PNGs and 400/240/180px contact sheets")
