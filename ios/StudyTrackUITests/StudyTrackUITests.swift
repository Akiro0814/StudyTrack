import XCTest

final class StudyTrackUITests: XCTestCase {
    @MainActor func testCompleteGuideExplainsAllFeaturesAndOpensProfile() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting"]; app.launch()
        XCTAssertTrue(app.buttons["guide.next"].waitForExistence(timeout: 15))
        for title in ["从你的学习档案开始","给每次努力一个归属","一科，或整场考试","让记录随时可找","看见每一步变化","让旧记录也加入旅程","让记录安心留存","把学迹变成你的样子"] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
            app.buttons["guide.next"].tap()
        }
        XCTAssertTrue(app.textFields["onboarding.name"].waitForExistence(timeout: 5))
        snapshot(app,"14-complete-guide-profile")
    }
    @MainActor func testWidgetHelpExplainsConfigurationAndRefreshesWithoutAccount() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting-showcase"]; app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 15))
        app.tabBars.buttons["设置"].tap()
        let help = app.buttons["settings.widgets"]
        reveal(help,in: app); help.tap()
        XCTAssertTrue(app.staticTexts["添加到桌面"].waitForExistence(timeout: 5))
        let refresh = app.buttons["立即刷新小组件"]; reveal(refresh,in: app); refresh.tap()
        XCTAssertTrue(app.navigationBars["小组件"].exists)
        snapshot(app,"15-widget-help")
    }
    @MainActor func testNativeDocumentPickerSelectsAndImportsXLSX() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting-showcase"]; app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 15))
        app.tabBars.buttons["设置"].tap()
        reveal(app.buttons["settings.data"],in: app); app.buttons["settings.data"].tap()
        app.buttons["导入 .xlsx"].tap()
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@","StudyTrack Import Test")).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 10))
        snapshot(app,"12-native-xlsx-selectable")
        XCTAssertTrue(file.isEnabled); file.tap()
        XCTAssertTrue(app.buttons["导入 .xlsx"].waitForExistence(timeout: 10))
        reveal(app.buttons["取消预览"],in: app)
        XCTAssertTrue(app.buttons["取消预览"].waitForExistence(timeout: 15))
        snapshot(app,"13-native-xlsx-import-preview")
    }
    @MainActor func testFirstLaunchShowsSkippableGuide() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting"]; app.launch()
        XCTAssertTrue(app.buttons["guide.skip"].waitForExistence(timeout: 15))
        snapshot(app,"09-first-launch-guide")
        app.buttons["guide.skip"].tap()
        XCTAssertTrue(app.textFields["onboarding.name"].waitForExistence(timeout: 5))
    }
    @MainActor func testSettingsSeparatesStageFromSemester() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting-showcase"]; app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 15))
        app.tabBars.buttons["设置"].tap()
        reveal(app.buttons["settings.semesters"],in: app)
        app.buttons["settings.semesters"].tap()
        XCTAssertTrue(app.buttons["semester.next"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["大学阶段"].exists)
        app.buttons["semester.next"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@","settings.semesters","高一下学期")).firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["首页"].tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.tabBars.buttons["设置"].tap()
        reveal(app.buttons["settings.stages"],in: app)
        app.buttons["settings.stages"].tap()
        XCTAssertTrue(app.buttons["stage.university"].waitForExistence(timeout: 5))
        snapshot(app,"11-learning-stages")
        app.buttons["stage.university"].tap()
        XCTAssertTrue(app.buttons["开启大学阶段"].waitForExistence(timeout: 5))
        app.buttons["开启大学阶段"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@","settings.stages","大学阶段")).firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["首页"].tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
    }
    @MainActor func testRecentScoreSwipesLeftWithoutOpeningEditor() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting-showcase"]; app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 15))
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@","阶段练习 4")).firstMatch
        for _ in 0..<5 {
            if row.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        XCTAssertFalse(app.textFields["exam.score"].exists)
        let delete = app.buttons["删除成绩"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        snapshot(app,"10-recent-left-swipe")
        delete.tap()
        XCTAssertTrue(app.buttons["撤销"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["exam.score"].exists)
        app.buttons["撤销"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.textFields["exam.score"].waitForExistence(timeout: 5))
    }
    @MainActor func testExperienceWithWallpaperAndSameDayExams() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting-showcase"]; app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["home.avatar"].exists)
        snapshot(app,"01-home-wallpaper")
        app.tabBars.buttons["成绩分析"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["analysis.chart"].firstMatch.waitForExistence(timeout: 10))
        snapshot(app,"02-analysis-same-day")
        snapshot(app,"03-ranking-with-missing-value")
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.staticTexts["StudyTrack"].waitForExistence(timeout: 5))
        snapshot(app,"04-settings-brand")
        app.buttons["settings.appearance"].tap()
        XCTAssertTrue(app.staticTexts["内容质感"].waitForExistence(timeout: 5))
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
    @MainActor private func reveal(_ element: XCUIElement,in app: XCUIApplication) {
        for _ in 0..<6 { if element.isHittable { return }; app.swipeUp() }
    }
    @MainActor func testFirstRecordGuidesThroughSubjectAndContinuesToExam() throws {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting"]; app.launch()
        if app.buttons["guide.skip"].waitForExistence(timeout: 2) { app.buttons["guide.skip"].tap() }
        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15)); name.tap(); name.typeText("Student\n")
        for _ in 0..<4 { if app.buttons["onboarding.start"].isHittable { break }; app.swipeUp() }
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
        if app.buttons["guide.skip"].waitForExistence(timeout: 2) { app.buttons["guide.skip"].tap() }
        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15)); name.tap(); name.typeText("Student\n")
        for _ in 0..<4 { if app.buttons["onboarding.start"].isHittable { break }; app.swipeUp() }
        app.buttons["onboarding.start"].tap()
        XCTAssertTrue(app.tabBars.buttons["科目"].waitForExistence(timeout: 10))
        app.tabBars.buttons["科目"].tap(); app.buttons["subjects.add"].tap()
        let subject = app.textFields["subject.name"]; XCTAssertTrue(subject.waitForExistence(timeout: 5)); subject.tap(); subject.typeText("Math")
        app.buttons["subject.save"].tap()
        XCTAssertTrue(app.staticTexts["Math"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.lifetime = .keepAlways; add(attachment)
    }
}
