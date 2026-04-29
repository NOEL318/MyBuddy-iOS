import SwiftUI
import Combine
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var user: FirebaseAuth.User? = nil
    @Published var isLoading = true

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Suscribe el listener de Firebase Auth y refresca el estado en el actor principal
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                self?.user = firebaseUser
                self?.isLoading = false
            }
        }
    }

    deinit {
        // Cancela el listener para evitar callbacks tras la destrucción
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signOut() {
        // Cierra la sesión actual de Firebase Auth
        try? Auth.auth().signOut()
    }
}
