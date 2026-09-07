import XCTest

final class LocalizationUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor func testReviewedEnglishScreenshots() {
    let app = launch(language: "en", region: "US", fixture: "screenshots")
    XCTAssertTrue(app.buttons["add-item"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Want to keep using it"].firstMatch.exists)
    XCTAssertTrue(app.staticTexts["Thinking about replacing it"].firstMatch.exists)
    capture("en-US-01-home", app: app)
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "iPhone 15 Pro")).firstMatch
      .tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
    capture("en-US-02-detail", app: app)
    app.swipeUp()
    capture("en-US-03-cost-notes", app: app)
    app.terminate()
    captureCostScreenshot()
  }

  @MainActor private func captureCostScreenshot() {
    let app = launch(language: "en", region: "US", fixture: "cost-screenshot")
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "MacBook Pro")).firstMatch.tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.80)).press(
      forDuration: 0.05,
      thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22)),
      withVelocity: .slow, thenHoldForDuration: 0.3)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).press(
      forDuration: 0.05,
      thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)),
      withVelocity: .slow, thenHoldForDuration: 0.3)
    capture("en-US-14-cost", app: app)
    app.terminate()
  }

  @MainActor func testEnglishScreenshotsAndFlows() {
    exerciseFlows(language: "en", region: "US")
    captureCostScreenshot()
  }

  @MainActor func testJapaneseScreenshotsAndFlows() {
    exerciseFlows(language: "ja", region: "JP")
  }

  @MainActor private func launch(
    language: String, region: String, fixture: String,
    resetPreferences: Bool = true, acknowledgeRegion: Bool = true
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(\(language))"]
    app.launchArguments += ["-AppleLocale", "\(language)_\(region)"]
    if acknowledgeRegion { app.launchArguments += ["-lastAcknowledgedRegion", region] }
    app.launchEnvironment["USEDWELL_FIXTURE"] = fixture
    if resetPreferences { app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1" }
    app.launch()
    return app
  }

  @MainActor private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
    for _ in 0..<6 {
      if element.isHittable { return }
      app.swipeUp()
    }
    XCTAssertTrue(element.isHittable)
  }

  @MainActor private func exerciseFlows(language: String, region: String) {
    let japanese = language == "ja"
    let prefix = "\(language)-\(region)"
    let app = launch(language: language, region: region, fixture: "screenshots")
    XCTAssertTrue(app.buttons["add-item"].waitForExistence(timeout: 5))
    capture("\(prefix)-01-home", app: app)
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "iPhone 15 Pro")).firstMatch
      .tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts[japanese ? "目標まであと16日" : "16 days to your goal"].exists)
    capture("\(prefix)-02-detail", app: app)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.80)).press(
      forDuration: 0.05,
      thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22)),
      withVelocity: .slow, thenHoldForDuration: 0.3)
    capture("\(prefix)-14-cost", app: app)
    app.swipeUp()
    capture("\(prefix)-03-cost-notes", app: app)
    exerciseNotes(app: app, japanese: japanese, prefix: prefix)
    app.buttons["edit-item"].tap()
    XCTAssertTrue(app.textFields["item-name"].waitForExistence(timeout: 3))
    capture("\(prefix)-06-edit-item", app: app)
    app.datePickers["purchase-date-picker"].tap()
    capture("\(prefix)-07-date-picker", app: app)
    app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    app.buttons["save-item"].tap()
    reveal(app.buttons["complete-item"], app: app)
    app.buttons["complete-item"].tap()
    capture("\(prefix)-08-complete-confirmation", app: app)
    app.alerts.buttons[japanese ? "今日で使用を終了" : "Finish Using Today"].tap()
    capture("\(prefix)-09-completed", app: app)
    app.alerts.buttons[japanese ? "完了" : "Done"].tap()
    let history = app.buttons[japanese ? "これまで使ったもの" : "Past Items"]
    reveal(history, app: app)
    history.tap()
    capture("\(prefix)-10-history", app: app)
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "iPhone 15 Pro")).firstMatch
      .tap()
    capture("\(prefix)-11-history-detail", app: app)
    reveal(app.buttons["delete-item"], app: app)
    app.buttons["delete-item"].tap()
    app.alerts.buttons[japanese ? "完全に削除" : "Delete Permanently"].tap()
    XCTAssertTrue(
      app.staticTexts[japanese ? "履歴はまだありません" : "No past items yet"].waitForExistence(timeout: 3))
    app.terminate()

    exerciseAdd(language: language, region: region)
  }

  @MainActor private func exerciseNotes(app: XCUIApplication, japanese: Bool, prefix: String) {
    reveal(app.buttons["usage-note-row"].firstMatch, app: app)
    app.buttons["usage-note-row"].firstMatch.tap()
    XCTAssertTrue(app.textViews["usage-note-text"].waitForExistence(timeout: 3))
    capture("\(prefix)-04-edit-note", app: app)
    app.textViews["usage-note-text"].tap()
    app.textViews["usage-note-text"].typeText(" Still useful.")
    app.buttons["save-usage-note"].tap()
    reveal(app.buttons["add-usage-note"], app: app)
    app.buttons["add-usage-note"].tap()
    app.textViews["usage-note-text"].tap()
    app.textViews["usage-note-text"].typeText("Keeping it for now")
    app.buttons["save-usage-note"].tap()
    let note = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Keeping it for now"))
      .firstMatch
    reveal(note, app: app)
    note.tap()
    app.buttons["delete-usage-note"].tap()
    capture("\(prefix)-05-delete-note", app: app)
    app.alerts.buttons[japanese ? "削除" : "Delete"].tap()
    XCTAssertFalse(app.staticTexts["Keeping it for now"].exists)
  }

  @MainActor private func exerciseAdd(language: String, region: String) {
    let japanese = language == "ja"
    let prefix = "\(language)-\(region)"
    let empty = launch(language: language, region: region, fixture: "empty")
    capture("\(prefix)-12-empty", app: empty)
    empty.buttons["add-first-item"].tap()
    empty.textFields["item-name"].tap()
    empty.textFields["item-name"].typeText("New Camera")
    empty.textFields["purchase-price"].tap()
    empty.textFields["purchase-price"].typeText("1299")
    XCTAssertTrue(empty.buttons["save-item"].isEnabled)
    capture("\(prefix)-13-add-item", app: empty)
    empty.buttons["save-item"].tap()
    let later = empty.alerts.buttons[japanese ? "後で" : "Not Now"]
    if later.waitForExistence(timeout: 2) { later.tap() }
    XCTAssertTrue(
      empty.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New Camera")).firstMatch
        .exists)
    empty.terminate()
  }

  @MainActor func testRegionNoticeAcknowledgementSurvivesRelaunch() {
    let first = launch(
      language: "en", region: "US", fixture: "screenshots", acknowledgeRegion: false)
    XCTAssertTrue(first.alerts["Region settings changed"].waitForExistence(timeout: 5))
    capture("en-US-region-notice", app: first)
    first.alerts.buttons["OK"].tap()
    first.terminate()
    let second = launch(
      language: "en", region: "US", fixture: "screenshots",
      resetPreferences: false, acknowledgeRegion: false)
    XCTAssertTrue(second.buttons["add-item"].waitForExistence(timeout: 5))
    XCTAssertFalse(second.alerts["Region settings changed"].exists)
    second.terminate()
    let changed = launch(
      language: "ja", region: "JP", fixture: "screenshots",
      resetPreferences: false, acknowledgeRegion: false)
    XCTAssertTrue(changed.alerts["地域設定が変更されました"].waitForExistence(timeout: 5))
    capture("ja-JP-region-notice", app: changed)
    changed.alerts.buttons["確認"].tap()
    changed.terminate()
  }
}
