// Usage: swift scripts/render-app-store.swift <raw PNG directory> <output directory> <ja-JP|en-US>
// All app content comes from runtime captures. Only framing and Store copy are drawn.
import AppKit

struct StoreSlide: Decodable {
  let name: String
  let headline: String
  let subcopy: String
  let caption: String
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
  _ string: String, left: CGFloat = 88, top: CGFloat, width: CGFloat = 1108,
  height: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, ink: NSColor,
  spacing: CGFloat = 9
) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.lineSpacing = spacing
  let attributed = NSAttributedString(
    string: string,
    attributes: [
      .font: NSFont.systemFont(ofSize: size, weight: weight),
      .foregroundColor: ink, .paragraphStyle: paragraph
    ])
  let bounds = attributed.boundingRect(
    with: NSSize(width: width, height: 10_000), options: [.usesLineFragmentOrigin, .usesFontLeading]
  )
  precondition(bounds.height <= height, "Store text overflows: \(string)")
  attributed.draw(in: rect(left, top, width, height))
}

func panel(_ image: NSImage, left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat? = nil) {
  let scaledHeight = image.size.height * width / image.size.width
  let frame = rect(left, top, width, height ?? scaledHeight)
  let path = NSBezierPath(roundedRect: frame, xRadius: 44, yRadius: 44)
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.11)
  shadow.shadowBlurRadius = 44
  shadow.shadowOffset = NSSize(width: 0, height: -18)
  shadow.set()
  color(0xFFFCF7).setFill()
  path.fill()
  NSGraphicsContext.restoreGraphicsState()
  NSGraphicsContext.saveGraphicsState()
  path.addClip()
  image.draw(in: NSRect(x: left, y: frame.maxY - scaledHeight, width: width, height: scaledHeight))
  NSGraphicsContext.restoreGraphicsState()
  color(0xDED1BF).withAlphaComponent(0.6).setStroke()
  path.lineWidth = 1
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

let icon = imageAt(
  scripts.deletingLastPathComponent().appendingPathComponent(
    "UsedWell/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
var finished: [NSImage] = []
for (index, slide) in slides.enumerated() {
  let forest = index == 2
  let primary = color(forest ? 0x243F35 : 0x302F2B)
  let secondary = color(forest ? 0x566A5A : 0x746F66)
  let accent = color(forest ? 0x285342 : 0x9C502F)
  let bitmap = render(width: canvasWidth, height: canvasHeight) {
    color(forest ? 0xE8EEE2 : 0xF4EADB).setFill()
    NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight).fill()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect(88, 83, 68, 68), xRadius: 16, yRadius: 16).addClip()
    icon.draw(in: rect(88, 83, 68, 68))
    NSGraphicsContext.restoreGraphicsState()
    text("UsedWell", left: 177, top: 88, height: 64, size: 42, weight: .semibold, ink: primary)
    text(
      String(format: "%02d / 05", index + 1), left: 1044, top: 102, width: 150,
      height: 44, size: 27, weight: .medium, ink: secondary)
    text(
      slide.headline, top: 233, height: 260, size: index == 4 ? 86 : 92,
      weight: .bold, ink: primary, spacing: 12)
    text(slide.subcopy, top: 525, height: 158, size: 38, ink: secondary, spacing: 14)
    switch index {
    case 0:
      panel(runtime("01-home"), left: 170, top: 689, width: 944)
    case 1:
      text(slide.caption, top: 790, height: 60, size: 30, weight: .medium, ink: accent)
      panel(
        runtime("01-home", crop: CGRect(x: 60, y: 651, width: 1086, height: 1458)),
        left: 72, top: 929, width: 1140)
    case 2:
      panel(runtime("03-goal"), left: 170, top: 689, width: 944)
    case 3:
      text(slide.caption, top: 790, height: 60, size: 30, weight: .medium, ink: accent)
      panel(
        runtime(
          "02-detail",
          crop: CGRect(x: 0, y: 429, width: 1206, height: locale == "en-US" ? 1764 : 1620)),
        left: 72, top: 929, width: 1140)
    default:
      text(slide.caption, top: 790, height: 60, size: 30, weight: .medium, ink: accent)
      panel(
        runtime("05-cost", crop: CGRect(x: 0, y: 440, width: 1206, height: 1840)),
        left: 72, top: 929, width: 1140)
    }
  }
  try bitmap.representation(using: .png, properties: [:])!.write(
    to: output.appendingPathComponent(slide.name + ".png"))
  finished.append(
    NSImage(cgImage: bitmap.cgImage!, size: NSSize(width: canvasWidth, height: canvasHeight)))
}
let sheet = render(width: 2000, height: 866) {
  for (index, image) in finished.enumerated() {
    image.draw(in: NSRect(x: index * 400, y: 0, width: 400, height: 866))
  }
}
try sheet.representation(using: .png, properties: [:])!.write(
  to: output.appendingPathComponent("contact-sheet.png"))
print("Rendered \(locale): five 1284 x 2778 sRGB PNGs and contact sheet")
