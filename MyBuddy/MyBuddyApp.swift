import SwiftUI
import FirebaseCore

@main
struct MyBuddyApp: App {

    init() {
        // Configura Firebase antes de instanciar la primera vista
        FirebaseApp.configure()
    }

    var body: some Scene {
        // Define la escena principal que monta RootView
        WindowGroup {
            RootView()
        }
    }
}
