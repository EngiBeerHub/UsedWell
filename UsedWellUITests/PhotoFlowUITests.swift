import XCTest

final class PhotoFlowUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor func testPhotosPickerSaveRemoveCancelAndRetry() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-lastAcknowledgedRegion", "US"
    ]
    app.launchEnvironment["USEDWELL_FIXTURE"] = "home-review"
    app.launchEnvironment["USEDWELL_FAIL_SAVE"] = "1"
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()
    let featured = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "featured-item")
    ).firstMatch
    XCTAssertTrue(featured.waitForExistence(timeout: 5))
    featured.tap()
    app.buttons["edit-item"].tap()
    choosePhoto(app)
    let remove = app.buttons["remove-item-photo"]
    XCTAssertTrue(remove.waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["save-item"].isEnabled)
    capture("en-US-photo-draft", app)
    app.buttons["save-item"].tap()
    let failure = app.alerts.firstMatch
    XCTAssertTrue(failure.waitForExistence(timeout: 3))
    failure.buttons.firstMatch.tap()
    XCTAssertTrue(remove.exists)
    app.buttons["save-item"].tap()
    XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
    capture("en-US-photo-detail", app)
    app.buttons["edit-item"].tap()
    XCTAssertTrue(remove.waitForExistence(timeout: 3))
    remove.tap()
    XCTAssertFalse(remove.exists)
    app.buttons["Cancel"].tap()
    app.buttons["edit-item"].tap()
    XCTAssertTrue(remove.waitForExistence(timeout: 3))
    remove.tap()
    app.buttons["save-item"].tap()
    app.buttons["edit-item"].tap()
    XCTAssertFalse(remove.exists)
    app.buttons["Cancel"].tap()
  }

  @MainActor func testAddPhotoCancelThenSave() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-lastAcknowledgedRegion", "US"
    ]
    app.launchEnvironment["USEDWELL_FIXTURE"] = "empty"
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()
    app.buttons["add-first-item"].tap()
    choosePhoto(app)
    XCTAssertTrue(app.buttons["remove-item-photo"].waitForExistence(timeout: 10))
    app.buttons["Cancel"].tap()
    app.buttons["add-first-item"].tap()
    XCTAssertFalse(app.buttons["remove-item-photo"].exists)
    choosePhoto(app)
    XCTAssertTrue(app.buttons["remove-item-photo"].waitForExistence(timeout: 10))
    app.textFields["item-name"].tap()
    app.textFields["item-name"].typeText("Photo Camera")
    app.textFields["purchase-price"].tap()
    app.textFields["purchase-price"].typeText("3100")
    app.buttons["save-item"].tap()
    let later = app.alerts.buttons["Not Now"]
    if later.waitForExistence(timeout: 2) { later.tap() }
    let item = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo Camera"))
      .firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 3))
    item.tap()
    app.buttons["edit-item"].tap()
    XCTAssertTrue(app.buttons["remove-item-photo"].waitForExistence(timeout: 3))
  }

  @MainActor private func choosePhoto(_ app: XCUIApplication) {
    app.buttons["choose-item-photo"].tap()
    // Uses the real system picker. Seed a disposable Simulator with `simctl addmedia` first.
    let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,"))
      .firstMatch
    XCTAssertTrue(
      photo.waitForExistence(timeout: 10), "The Simulator photo library needs a test image")
    capture("en-US-photo-picker", app)
    photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
  }

  @MainActor func testPhotoVisualStatesAndHistory() throws {
    let photoPath = ProcessInfo.processInfo.environment["USEDWELL_PHOTO_FIXTURE_PATH"]
    for language in ["ja", "en"] {
      for variant in ["under", "90", "100", "over", "long"] {
        checkVisualVariant(language: language, variant: variant, photoPath: photoPath)
      }
    }
  }

  @MainActor private func checkVisualVariant(
    language: String, variant: String, photoPath: String?
  ) {
    let app = XCUIApplication()
    let region = language == "ja" ? "JP" : "US"
    app.launchArguments = [
      "-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)",
      "-lastAcknowledgedRegion", region
    ]
    if variant == "long" {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName",
        "UICTContentSizeCategoryAccessibilityXXXL"
      ]
    }
    app.launchEnvironment["USEDWELL_FIXTURE"] = "home-photo-\(variant)"
    app.launchEnvironment["USEDWELL_PHOTO_FIXTURE_PATH"] = photoPath
    app.launchEnvironment["USEDWELL_RESET_PREFERENCES"] = "1"
    app.launch()
    let featured = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "featured-item")
    ).firstMatch
    XCTAssertTrue(featured.waitForExistence(timeout: 5))
    let percentage = ["under": "67%", "90": "90%", "100": "100%", "over": "133%"]
    if let expected = percentage[variant] {
      XCTAssertTrue(featured.label.contains(expected), featured.label)
    }
    capture("\(language)-\(region)-photo-\(variant)-home", app)
    if variant == "long" {
      app.swipeUp()
      capture("\(language)-\(region)-photo-long-scroll", app)
    }
    if variant != "long" {
      featured.tap()
      XCTAssertTrue(app.buttons["edit-item"].waitForExistence(timeout: 3))
      capture("\(language)-\(region)-photo-\(variant)-detail", app)
      app.navigationBars.buttons.firstMatch.tap()
    }
    let history = app.buttons[language == "ja" ? "これまで使ったもの" : "Past Items"]
    reveal(history, app)
    history.tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history-item-"))
        .firstMatch.waitForExistence(timeout: 3))
    capture("\(language)-\(region)-photo-\(variant)-history", app)
    if variant == "over" { checkHistoryDetail(app, language: language, region: region) }
    app.terminate()
  }

  @MainActor private func checkHistoryDetail(
    _ app: XCUIApplication, language: String, region: String
  ) {
    let cases = [("Past iPhone", "133%"), ("Past Bag", "88%"), ("Past Watch", "100%")]
    for (name, percentage) in cases {
      let past = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
      reveal(past, app)
      past.tap()
      XCTAssertFalse(app.buttons["edit-item"].exists)
      capture("\(language)-\(region)-photo-history-\(percentage)-detail", app)
      let finalProgress = app.staticTexts["final-progress"]
      reveal(finalProgress, app)
      XCTAssertTrue(finalProgress.label.contains(percentage), finalProgress.label)
      capture("\(language)-\(region)-photo-history-\(percentage)-info", app)
      app.navigationBars.buttons.firstMatch.tap()
    }
  }

  @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
    for _ in 0..<18 {
      if element.exists && element.isHittable && element.frame.midY < app.frame.maxY - 35 {
        return
      }
      app.swipeUp()
    }
    XCTAssertTrue(element.isHittable)
  }

  @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
