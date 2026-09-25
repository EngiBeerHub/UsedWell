import XCTest

/// Captures current runtime UI with an isolated, deterministic Store fixture.
final class AppStoreScreenshotTests: UIFlowTestCase {
  @MainActor func testJapaneseStoreScreenshots() {
    captureStory(language: "ja", region: "JP")
  }

  @MainActor func testEnglishStoreScreenshots() {
    captureStory(language: "en", region: "US")
  }

  @MainActor private func launch(
    language: String, region: String, fixture: String, theme: String = "warm"
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)",
      "-lastAcknowledgedRegion", region, "-selectedAppTheme", theme,
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
    ]
    let photo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent(
        "design/images/photo-portrait-fixture-20260923.png")
    XCTAssertTrue(FileManager.default.fileExists(atPath: photo.path))
    app.launchEnvironment = [
      "USEDWELL_FIXTURE": fixture, "USEDWELL_RESET_PREFERENCES": "1",
      "USEDWELL_PHOTO_FIXTURE_PATH": photo.path
    ]
    app.launch()
    XCTAssertTrue(app.buttons["featured-item"].waitForExistence(timeout: 5))
    return app
  }

  @MainActor private func captureStory(language: String, region: String) {
    let prefix = "\(language)-\(region)"
    let app = launch(language: language, region: region, fixture: "store-home")
    XCTAssertTrue(app.buttons["featured-item"].label.contains("95%"))
    let warmFeatured = app.buttons["featured-item"].label
    capture("\(prefix)-01-home", app: app)
    app.buttons["featured-item"].tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 5))
    capture("\(prefix)-02-detail", app: app)
    dragUp(app, distance: 0.21)
    XCTAssertEqual(app.buttons.matching(identifier: "usage-note-row").count, 3)
    capture("\(prefix)-04-notes", app: app)
    app.terminate()

    let forest = launch(language: language, region: region, fixture: "store-home", theme: "forest")
    XCTAssertEqual(forest.buttons["featured-item"].label, warmFeatured)
    capture("\(prefix)-04-home-forest", app: forest)
    forest.terminate()

    let cost = launch(language: language, region: region, fixture: "store-cost")
    cost.buttons["featured-item"].tap()
    XCTAssertTrue(cost.buttons["edit-item"].waitForExistence(timeout: 5))
    capture("\(prefix)-05-cost", app: cost)
    cost.terminate()
  }

  @MainActor private func dragUp(_ app: XCUIApplication, distance: CGFloat) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.76)).press(
      forDuration: 0.1,
      thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.76 - distance)),
      withVelocity: .slow, thenHoldForDuration: 0.4)
  }

  @MainActor private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
