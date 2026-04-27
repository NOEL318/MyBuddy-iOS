import SwiftUI
import Combine
import FirebaseAuth

// Observa el estado de autenticación de Firebase y lo expone a toda la app
@MainActor
final class AuthViewModel: ObservableObject {

    /// Usuario autenticado actual; nil si no hay sesión activa
    @Published var user: FirebaseAuth.User? = nil
    /// true mientras Firebase resuelve el estado inicial de auth (splash)
    @Published var isLoading = true

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Firebase notifica los cambios de sesión; actualizamos en el actor principal
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                self?.user = firebaseUser
                self?.isLoading = false
            }
        }
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // Cierra la sesión del usuario actual
    func signOut() {
        try? Auth.auth().signOut()
    }
}
