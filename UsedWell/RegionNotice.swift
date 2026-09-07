import Foundation

/// Only the last acknowledged region is retained; amounts have no stored currency identity.
enum RegionNotice {
  static let defaultsKey = "lastAcknowledgedRegion"

  static func needsAcknowledgement(
    previousRegion: String?, currentRegion: String, hasItems: Bool
  ) -> Bool {
    guard hasItems else { return false }
    guard let previousRegion else { return currentRegion != "JP" }
    return previousRegion != currentRegion
  }
}
