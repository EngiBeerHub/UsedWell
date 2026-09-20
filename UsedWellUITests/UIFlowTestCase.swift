import XCTest

/// Flow tests use portrait; launch-configuration tests may leave the device in landscape.
class UIFlowTestCase: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
  }

  @MainActor override func tearDownWithError() throws {
    if let testRun, testRun.failureCount > 0 {
      let tree = XCTAttachment(string: XCUIApplication().debugDescription)
      tree.name = "Failure accessibility tree"
      tree.lifetime = .keepAlways
      add(tree)
    }
  }

  @MainActor func revealElement(
    _ element: XCUIElement, in app: XCUIApplication, upward: Bool = true,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    for _ in 0..<24 {
      let top = max(app.navigationBars.firstMatch.frame.maxY, app.frame.minY) + 12
      let keyboard = app.keyboards.firstMatch
      let bottom = keyboard.exists ? keyboard.frame.minY - 12 : app.frame.maxY - 20
      let isVisible =
        element.exists && element.isHittable
        && element.frame.midY > top && element.frame.midY < bottom
      if isVisible {
        return
      }
      let scrollUp = element.exists && element.frame.midY < top ? false : upward
      // Keep gestures above the keyboard and inside the scrollable content.
      let height = bottom - top
      let startY = (top + height * (scrollUp ? 0.8 : 0.25)) / app.frame.height
      let endY = (top + height * (scrollUp ? 0.25 : 0.8)) / app.frame.height
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY)).press(
        forDuration: 0.05,
        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY)))
    }
    XCTFail("Element did not become visible: \(element)", file: file, line: line)
  }

  @MainActor func waitForElement(
    _ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
  }
}
