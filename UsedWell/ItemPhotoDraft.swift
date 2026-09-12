import Foundation

/// The model is never touched while picking, removing, cancelling, or retrying a photo.
struct ItemPhotoDraft {
  enum Change: Equatable {
    case unchanged
    case replacement(Data)
    case removed
  }
  private let original: Data?
  private(set) var change = Change.unchanged
  private(set) var selectionID = UUID()
  private(set) var isLoading = false
  private(set) var loadFailed = false

  init(original: Data?) { self.original = original }

  var data: Data? {
    switch change {
    case .unchanged: original
    case .replacement(let data): data
    case .removed: nil
    }
  }

  mutating func beginSelection() {
    selectionID = UUID()
    isLoading = true
    loadFailed = false
  }

  mutating func finish(_ data: Data?, selectionID: UUID) {
    guard self.selectionID == selectionID, isLoading else { return }
    isLoading = false
    loadFailed = data == nil
    if let data { change = .replacement(data) }
  }

  mutating func cancelLoading() {
    selectionID = UUID()
    isLoading = false
    loadFailed = false
  }

  mutating func remove() {
    cancelLoading()
    change = .removed
  }
}
