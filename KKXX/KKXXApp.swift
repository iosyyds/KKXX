import SwiftUI

@main
struct KKXXApp: App {
    @StateObject private var store = LocalStore()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(
                    settings.theme == "light" ? .light :
                    settings.theme == "dark" ? .dark : nil
                )
        }
    }
}
