import SwiftUI

@main struct StudyTrackApp: App {
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView().environment(model).tint(model.accent).task { await model.start() }
                #if DEBUG
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-uitesting-dark") ? .dark : nil)
                #endif
        }
    }
}
