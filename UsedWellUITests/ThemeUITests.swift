import XCTest

final class ThemeUITests: UIFlowTestCase {
  @MainActor func testThemesAcrossDetailHistoryAndEditors() {
    for theme in ["Warm", "Forest"] {
      let app = XCUIApplication()
      app.launchArguments = [
        "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP", "-lastAcknowledgedRegion", "JP"
      ]
      app.launchEnvironment["USEDWELL_FIXTURE"] = "home-photo-95"
      app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
      if let path = ProcessInfo.processInfo.environment["USEDWELL_PHOTO_FIXTURE_PATH"] {
        app.launchEnvironment["USEDWELL_PHOTO_FIXTURE_PATH"] = path
      }
      app.launch()

      app.buttons["open-settings"].tap()
      if theme == "Forest" {
        app.segmentedControls["theme-picker"].buttons["Forest"].tap()
      }
      capture("\(theme) Settings", app: app)
      app.buttons["完了"].tap()
      capture("\(theme) Home", app: app)

      app.buttons["featured-item"].tap()
      XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 5))
      capture("\(theme) Detail", app: app)
      let note = app.buttons["usage-note-row"].firstMatch
      revealElement(note, in: app)
      note.tap()
      capture("\(theme) Usage Note", app: app)
      app.buttons["キャンセル"].tap()

      app.buttons["edit-item"].tap()
      XCTAssertTrue(app.textFields["item-name"].waitForExistence(timeout: 5))
      capture("\(theme) Edit", app: app)
      app.buttons["キャンセル"].tap()
      app.navigationBars.buttons.firstMatch.tap()

      let history = app.buttons["これまで使ったもの"]
      revealElement(history, in: app)
      history.tap()
      XCTAssertTrue(app.navigationBars["これまで使ったもの"].waitForExistence(timeout: 5))
      capture("\(theme) History", app: app)
      app.terminate()
    }
  }

  @MainActor func testHomeTitleCollapsesAndToolbarRemains() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP", "-lastAcknowledgedRegion", "JP"
    ]
    app.launchEnvironment["USEDWELL_FIXTURE"] = "home-review"
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()
    XCTAssertTrue(app.navigationBars["愛用品"].waitForExistence(timeout: 5))
    capture("Home initial large title", app: app)
    app.swipeUp()
    XCTAssertTrue(app.navigationBars["愛用品"].exists)
    XCTAssertTrue(app.buttons["open-settings"].isHittable)
    XCTAssertTrue(app.buttons["add-item"].isHittable)
    capture("Home scrolled compact title", app: app)
  }

  @MainActor func testLargeEnglishRegularRowKeepsAllInformation() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
      "-lastAcknowledgedRegion", "US", "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryAccessibilityXXXL"
    ]
    app.launchEnvironment["USEDWELL_FIXTURE"] = "home-photo-long"
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()
    let row = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "regular-item-")
    ).firstMatch
    for _ in 0..<12 {
      if row.exists && row.isHittable { break }
      app.scrollViews.firstMatch.swipeUp()
    }
    XCTAssertTrue(row.exists)
    for value in [
      "The MacBook Air I have used for work and travel over many years",
      "2 years 6 months", "Want to keep using it", "83%", "Goal 3 years",
      "About 6 months to your goal", "$201 per day"
    ] {
      XCTAssertTrue(row.label.contains(value), row.label)
    }
    capture("English long regular row at maximum text size", app: app)
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 5))
  }

  @MainActor func testProgressStagesAreReadableWithoutColor() {
    for (fixture, status, percentage) in [
      ("home-photo-83", "まだ使いたい", "83%"),
      ("home-photo-95", "買い替えを考え始める", "95%"),
      ("home-photo-100", "目標達成", "100%"),
      ("home-photo-over", "目標達成", "133%")
    ] {
      let app = XCUIApplication()
      app.launchArguments = [
        "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP", "-lastAcknowledgedRegion", "JP"
      ]
      app.launchEnvironment["USEDWELL_FIXTURE"] = fixture
      app.launch()
      let featured = app.buttons["featured-item"]
      XCTAssertTrue(featured.waitForExistence(timeout: 5))
      XCTAssertTrue(featured.label.contains(status), featured.label)
      XCTAssertTrue(featured.label.contains(percentage), featured.label)
      app.terminate()
    }
  }

  @MainActor func testThemeChangesImmediatelyAndPersistsAcrossRelaunch() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP", "-lastAcknowledgedRegion", "JP"
    ]
    app.launchEnvironment["USEDWELL_FIXTURE"] = "home-review"
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()

    app.buttons["open-settings"].tap()
    let picker = app.segmentedControls["theme-picker"]
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    XCTAssertTrue(picker.buttons["Warm"].isSelected)
    picker.buttons["Forest"].tap()
    XCTAssertTrue(picker.buttons["Forest"].isSelected)
    capture("Forest Settings", app: app)
    app.buttons["完了"].tap()
    capture("Forest Home", app: app)

    app.terminate()
    app.launchEnvironment.removeValue(forKey: "USEDWELL_RESET_PREFERENCES")
    app.launch()
    app.buttons["open-settings"].tap()
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    XCTAssertTrue(picker.buttons["Forest"].isSelected)
    picker.buttons["Warm"].tap()
    XCTAssertTrue(picker.buttons["Warm"].isSelected)
  }

  @MainActor private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
