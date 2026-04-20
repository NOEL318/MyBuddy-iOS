import SwiftUI
import FirebaseAuth

struct RegisterView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var username        = ""
    @State private var email           = ""
    @State private var phoneNumber     = ""
    @State private var description     = ""
    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var errorMessage    = ""
    @State private var isLoading       = false
    @State private var appeared        = false

    // Validaciones inline en tiempo real
    private var usernameIsValid:   Bool { username.count >= 3 }
    private var emailIsValid:      Bool { email.contains("@") && email.contains(".") }
    private var passwordIsValid:   Bool { password.count >= 6 }
    private var passwordsMatch:    Bool { password == confirmPassword }

    var body: some View {
        ZStack {
            Color.primaryGreen.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Título
                    Text("Crear cuenta")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 32)

                    formCard
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Atrás")
                    }
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    // Tarjeta con todos los campos del formulario
    private var formCard: some View {
        VStack(spacing: 14) {
            // Campos con validación
            validatedField(
                icon: "person",
                placeholder: "Nombre de usuario (mín. 3 caracteres)",
                text: $username,
                error: username.isEmpty ? nil : (usernameIsValid ? nil : "Mínimo 3 caracteres"),
                delay: 0.00
            )
            validatedField(
                icon: "envelope",
                placeholder: "Correo electrónico",
                text: $email,
                isEmail: true,
                error: email.isEmpty ? nil : (emailIsValid ? nil : "Correo no válido"),
                delay: 0.07
            )
            validatedField(
                icon: "phone",
                placeholder: "Teléfono (opcional)",
                text: $phoneNumber,
                isPhone: true,
                delay: 0.14
            )
            validatedField(
                icon: "text.alignleft",
                placeholder: "Descripción (opcional)",
                text: $description,
                delay: 0.21
            )
            validatedField(
                icon: "lock",
                placeholder: "Contraseña (mín. 6 caracteres)",
                text: $password,
                isSecure: true,
                error: password.isEmpty ? nil : (passwordIsValid ? nil : "Mínimo 6 caracteres"),
                delay: 0.28
            )
            validatedField(
                icon: "lock.shield",
                placeholder: "Confirmar contraseña",
                text: $confirmPassword,
                isSecure: true,
                error: confirmPassword.isEmpty ? nil : (passwordsMatch ? nil : "Las contraseñas no coinciden"),
                delay: 0.35
            )

            // Mensaje de error global
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            // Botón de registro
            Button(action: register) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Registrarse")
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
            .animation(.easeOut(duration: 0.4).delay(0.42), value: appeared)
        }
        .padding(24)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 24)
    }

    /// Campo de texto con ícono, borde de error y animación de entrada escalonada
    private func validatedField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        isEmail: Bool = false,
        isPhone: Bool = false,
        error: String? = nil,
        delay: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(error != nil ? .red : .secondary)
                    .frame(width: 20)
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(isEmail ? .emailAddress : (isPhone ? .phonePad : .default))
                        .textInputAutocapitalization(isEmail || isSecure ? .never : .words)
                        .autocorrectionDisabled(isEmail || isSecure)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(error != nil ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )

            if let error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
                    .transition(.opacity)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(.easeOut(duration: 0.4).delay(delay), value: appeared)
    }

    // Crea el usuario en Firebase Auth y su perfil en Firestore
    private func register() {
        let emailTrimmed    = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let usernameTrimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard usernameIsValid, emailIsValid, passwordIsValid, passwordsMatch else {
            errorMessage = "Revisa los campos marcados en rojo."
            return
        }

        isLoading = true
        errorMessage = ""

        Task {
            do {
                let result = try await Auth.auth().createUser(withEmail: emailTrimmed, password: password)
                let profile = UserProfile(
                    id:          result.user.uid,
                    username:    usernameTrimmed,
                    description: description,
                    phoneNumber: phoneNumber,
                    email:       emailTrimmed,
                    createdAt:   Date()
                )
                try await FirestoreService.shared.createProfile(profile)
                // El AuthViewModel detecta el cambio automáticamente
            } catch {
                errorMessage = firebaseError(error)
                // Si Firestore falla después de crear el usuario, borramos el usuario huérfano
                if (error as? AppError) != nil {
                    try? await Auth.auth().currentUser?.delete()
                }
            }
            isLoading = false
        }
    }

    // Mapea errores de Firebase y de la app a mensajes en español
    private func firebaseError(_ error: Error) -> String {
        if let appErr = error as? AppError {
            return appErr.localizedDescription
        }
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .invalidEmail:      return "El correo no tiene un formato válido."
        case .emailAlreadyInUse: return "Ya existe una cuenta con ese correo."
        case .weakPassword:      return "La contraseña es demasiado débil (mínimo 6 caracteres)."
        case .networkError:      return "Sin conexión. Revisa tu internet."
        default:                 return "Error al registrarse. Intenta de nuevo."
        }
    }
}
