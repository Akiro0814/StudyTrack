import XCTest

final class StudyTrackUITests: XCTestCase {
    @MainActor func testExperienceWithWallpaperAndSameDayExams() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting-showcase"]; app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["home.avatar"].exists)
        snapshot(app,"01-home-wallpaper")
        app.tabBars.buttons["分析"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["analysis.chart"].firstMatch.waitForExistence(timeout: 10))
        snapshot(app,"02-analysis-same-day")
        app.segmentedControls.buttons["班排"].firstMatch.tap()
        snapshot(app,"03-ranking-with-missing-value")
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.staticTexts["StudyTrack"].waitForExistence(timeout: 5))
        snapshot(app,"04-settings-brand")
        app.buttons["settings.appearance"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["appearance.preview"].firstMatch.waitForExistence(timeout: 5))
        snapshot(app,"05-personalization")
    }
    @MainActor func testDarkLargeTypeWithWallpaper() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting-showcase","-uitesting-dark","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["home.add"].isEnabled)
        snapshot(app,"06-home-dark-accessibility-size")
        app.swipeUp()
        snapshot(app,"08-home-dark-accessibility-score")
        app.tabBars.buttons["设置"].tap()
        snapshot(app,"07-settings-dark-accessibility-size")
    }
    @MainActor private func snapshot(_ app: XCUIApplication,_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testFirstRecordGuidesThroughSubjectAndContinuesToExam() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting"]; app.launch()
        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15)); name.tap(); name.typeText("Student\n")
        let semester = app.textFields["onboarding.semester"]; semester.typeText("Fall\n")
        app.buttons["onboarding.start"].tap()
        let add = app.buttons["home.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10)); XCTAssertTrue(add.isEnabled); add.tap()
        XCTAssertTrue(app.alerts["先添加一个科目"].waitForExistence(timeout: 5))
        app.alerts.buttons["添加科目"].tap()
        let subject = app.textFields["subject.name"]
        XCTAssertTrue(subject.waitForExistence(timeout: 5)); subject.tap(); subject.typeText("Math")
        app.buttons["subject.save"].tap()
        XCTAssertTrue(app.textFields["exam.score"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["exam.save"].exists)
    }
    @MainActor func testOnboardingAndSubjectCreation() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting"]; app.launch()
        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15)); name.tap(); name.typeText("Student\n")
        let semester = app.textFields["onboarding.semester"]; semester.typeText("Fall\n")
        app.buttons["onboarding.start"].tap()
        XCTAssertTrue(app.tabBars.buttons["科目"].waitForExistence(timeout: 10))
        app.tabBars.buttons["科目"].tap(); app.buttons["subjects.add"].tap()
        let subject = app.textFields["subject.name"]; XCTAssertTrue(subject.waitForExistence(timeout: 5)); subject.tap(); subject.typeText("Math")
        app.buttons["subject.save"].tap()
        XCTAssertTrue(app.staticTexts["Math"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.lifetime = .keepAlways; add(attachment)
    }
}
