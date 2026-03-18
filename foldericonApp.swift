import SwiftUI

@main
struct foldericonApp: App {
    var body: some Scene {
        Window("", id: "main") {
            MainView()
                .frame(width: 779)
                .frame(height: 550)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
