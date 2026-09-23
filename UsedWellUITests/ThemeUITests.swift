import XCTest

final class ThemeUITests: UIFlowTestCase {
  @MainActor func testForestThemeAcrossDetailHistoryAndEditors() {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    app.launchEnvironment["USEDWELL_FIXTURE"] = "home-photo-95"
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()

    app.buttons["open-settings"].tap()
    app.segmentedControls["theme-picker"].buttons["Forest"].tap()
    app.buttons["完了"].tap()
    capture("Forest Home", app: app)

    app.buttons["featured-item"].tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 5))
    capture("Forest Detail", app: app)
    let note = app.buttons["usage-note-row"].firstMatch
    revealElement(note, in: app)
    note.tap()
    capture("Forest Usage Note", app: app)
    app.buttons["キャンセル"].tap()

    app.buttons["edit-item"].tap()
    XCTAssertTrue(app.textFields["item-name"].waitForExistence(timeout: 5))
    capture("Forest Edit", app: app)
    app.buttons["キャンセル"].tap()
    app.navigationBars.buttons.firstMatch.tap()

    let history = app.buttons["これまで使ったもの"]
    revealElement(history, in: app)
    history.tap()
    XCTAssertTrue(app.navigationBars["これまで使ったもの"].waitForExistence(timeout: 5))
    capture("Forest History", app: app)
  }

  @MainActor func testProgressStagesAreReadableWithoutColor() {
    for (fixture, status, percentage) in [
      ("home-photo-83", "まだ使いたい", "83%"),
      ("home-photo-95", "買い替えを考え始める", "95%"),
      ("home-photo-100", "目標達成", "100%"),
      ("home-photo-over", "目標達成", "133%")
    ] {
      let app = XCUIApplication()
      app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
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
    app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
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
