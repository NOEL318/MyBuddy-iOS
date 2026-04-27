import SwiftUI
import FirebaseAuth

struct LoginView: View {

    @State private var email          = ""
    @State private var password       = ""
    @State private var errorMessage   = ""
    @State private var isLoading      = false
    @State private var showRegister   = false
    @State private var appeared       = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.primaryGreen,
                        Color.actionGreen.opacity(0.88),
                        Color.accentOrange.opacity(0.8),
                        Color.accentOrange.opacity(0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        logoSection
                        formCard
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    // Logo y nombre de la app
    private var logoSection: some View {
        VStack(spacing: 18) {
            MyBuddyLogoView(size: 90)
            Text("MyBuddy")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.top, 80)
        .padding(.bottom, 48)
    }

    // Tarjeta blanca con campos de formulario
    private var formCard: some View {
        VStack(spacing: 16) {
            // Campo de email
            inputField(
                icon: "envelope",
                placeholder: "Correo electrónico",
                text: $email,
                delay: 0.0
            )

            // Campo de contraseña
            inputField(
                icon: "lock",
                placeholder: "Contraseña",
                text: $password,
                isSecure: true,
                delay: 0.1
            )

            // Mensaje de error
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }

            // Botón de inicio de sesión
            Button(action: login) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Iniciar sesión")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(Color.actionGreen)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(isLoading)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
            .animation(.easeOut(duration: 0.45).delay(0.2), value: appeared)

            // Enlace a registro
            Button {
                showRegister = true
            } label: {
                Text("¿No tienes cuenta? ")
                    .foregroundStyle(.secondary) +
                Text("Regístrate")
                    .foregroundStyle(Color.actionGreen)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.45).delay(0.3), value: appeared)
        }
        .padding(28)
        .background(Color.white)
        .colorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 24)
    }

    // Campo de texto genérico con ícono y animación escalonada
    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        delay: Double
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.actionGreen)
                .frame(width: 20)
            if isSecure {
                SecureField(placeholder, text: text)
                    .foregroundStyle(Color.primary)
                    .tint(Color.actionGreen)
            } else {
                TextField(placeholder, text: text)
                    .foregroundStyle(Color.primary)
                    .tint(Color.actionGreen)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(.easeOut(duration: 0.45).delay(delay), value: appeared)
    }

    // Intenta iniciar sesión con Firebase Auth
    private func login() {
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !emailTrimmed.isEmpty, !password.isEmpty else {
            errorMessage = "Completa todos los campos."
            return
        }
        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await Auth.auth().signIn(withEmail: emailTrimmed, password: password)
            } catch {
                errorMessage = firebaseError(error)
            }
            isLoading = false
        }
    }

    // Mapea errores de Firebase Auth a mensajes en español
    private func firebaseError(_ error: Error) -> String {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .invalidEmail:     return "El correo no tiene un formato válido."
        case .wrongPassword:    return "Contraseña incorrecta."
        case .userNotFound:     return "No existe una cuenta con ese correo."
        case .userDisabled:     return "Esta cuenta ha sido deshabilitada."
        case .networkError:     return "Sin conexión. Revisa tu internet."
        case .tooManyRequests:  return "Demasiados intentos. Intenta más tarde."
        default:                return "Error al iniciar sesión. Intenta de nuevo."
        }
    }
}

#Preview {
    LoginView()
}
