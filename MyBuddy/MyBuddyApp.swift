//
//  MyBuddyApp.swift
//  MyBuddy
//
//  Created by Noel Rincón on 10/04/26.
//

import SwiftUI
import FirebaseCore

@main
struct MyBuddyApp: App {

    // Inicializa Firebase al arrancar la app antes de que se cree la primera vista
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            // RootView decide entre splash, login y la app según el estado de auth
            RootView()
        }
    }
}
