import CoreTransferable
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Images are normalized once on import; no Photos asset identifier or original file is retained.
nonisolated enum ItemPhotoPipeline {
  enum Failure: Error { case invalidImage, encodingFailed }

  static func prepare(fileURL: URL) throws -> Data {
    guard
      let source = CGImageSourceCreateWithURL(
        fileURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
    else {
      throw Failure.invalidImage
    }
    return try prepare(source: source)
  }

  static func prepare(data: Data) throws -> Data {
    guard
      let source = CGImageSourceCreateWithData(
        data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
    else {
      throw Failure.invalidImage
    }
    return try prepare(source: source)
  }

  private static func prepare(source: CGImageSource) throws -> Data {
    let image = try thumbnail(source: source, maxPixelSize: 2048)
    let output = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        output, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw Failure.encodingFailed }
    // Re-encoding the pixels intentionally omits the source's location and other metadata.
    CGImageDestinationAddImage(
      destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw Failure.encodingFailed }
    return output as Data
  }

  static func thumbnail(data: Data, maxPixelSize: Int) throws -> CGImage {
    guard
      let source = CGImageSourceCreateWithData(
        data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
    else {
      throw Failure.invalidImage
    }
    return try thumbnail(source: source, maxPixelSize: maxPixelSize)
  }

  private static func thumbnail(source: CGImageSource, maxPixelSize: Int) throws -> CGImage {
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      kCGImageSourceShouldCacheImmediately: true
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      throw Failure.invalidImage
    }
    return image
  }
}

nonisolated struct ImportedItemPhoto: Transferable {
  let data: Data

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .image) { received in
      // The provider owns this URL until the import closure returns. Nothing is copied to disk.
      let data = try await Task.detached(priority: .userInitiated) {
        try ItemPhotoPipeline.prepare(fileURL: received.file)
      }.value
      return ImportedItemPhoto(data: data)
    }
  }
}
