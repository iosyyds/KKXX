import SwiftUI

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var unlocked = false

    var body: some View {
        if settings.fingerprintLock && !unlocked {
            LockView(unlocked: $unlocked)
        } else {
            HomeView()
        }
    }
}
