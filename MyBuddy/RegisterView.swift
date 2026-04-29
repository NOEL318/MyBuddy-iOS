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

    private var usernameIsValid: Bool {
        // Comprueba que el username tenga al menos 3 caracteres
        username.count >= 3
    }
    private var emailIsValid: Bool {
        // Comprueba que el correo contenga arroba y punto
        email.contains("@") && email.contains(".")
    }
    private var passwordIsValid: Bool {
        // Comprueba que la contraseña tenga al menos 6 caracteres
        password.count >= 6
    }
    private var passwordsMatch: Bool {
        // Comprueba que la confirmación coincida con la contraseña
        password == confirmPassword
    }

    var body: some View {
        // Compone la pantalla de registro con degradado, logo y formulario
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
                    VStack(spacing: 14) {
                        MyBuddyLogoView(size: 72)
                        Text("Crear cuenta")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
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

    private var formCard: some View {
        // Tarjeta blanca con todos los campos del formulario y el botón de registro
        VStack(spacing: 14) {
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

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

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
        .background(Color.white)
        .colorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 24)
    }

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
        // Campo de texto con ícono, borde rojo si hay error y animación escalonada
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(error != nil ? .red : .secondary)
                    .frame(width: 20)
                if isSecure {
                    SecureField(placeholder, text: text)
                        .foregroundStyle(Color.primary)
                        .tint(Color.actionGreen)
                } else {
                    TextField(placeholder, text: text)
                        .foregroundStyle(Color.primary)
                        .tint(Color.actionGreen)
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

    private func register() {
        // Crea el usuario en Firebase Auth y persiste su perfil en Firestore
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
            } catch {
                errorMessage = firebaseError(error)
                if (error as? AppError) != nil {
                    try? await Auth.auth().currentUser?.delete()
                }
            }
            isLoading = false
        }
    }

    private func firebaseError(_ error: Error) -> String {
        // Convierte errores de Firebase Auth o de la app en mensajes en español
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
