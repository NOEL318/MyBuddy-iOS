import SwiftUI
import FirebaseAuth

struct ProfileView: View {

    @EnvironmentObject var authVM: AuthViewModel

    @State private var profile:      UserProfile? = nil
    @State private var username:     String = ""
    @State private var description:  String = ""
    @State private var phoneNumber:  String = ""
    @State private var oldUsername:  String = ""
    @State private var isEditing:    Bool = false
    @State private var isSaving:     Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // ── Fondo base ──────────────────────────────────────────────────
                Color.surface.ignoresSafeArea()

                // ── Degradado verde a naranja que cubre casi toda la pantalla ──
                LinearGradient(
                    colors: [
                        Color.primaryGreen,
                        Color.actionGreen.opacity(0.85),
                        Color.accentOrange.opacity(0.72),
                        Color.accentOrange.opacity(0.18),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.95)
                )
                .ignoresSafeArea()

                // ── Contenido scrolleable ───────────────────────────────────────
                if let profile {
                    ScrollView {
                        VStack(spacing: 20) {
                            avatarSection(profile)
                            fieldsSection
                            logoutButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 48)
                    }
                } else {
                    ProgressView()
                        .tint(Color.actionGreen)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)   // título blanco sobre el degradado
            .toolbar { toolbar }
        }
        .task { await loadProfile() }
    }

    // Avatar circular con inicial + nombre y correo
    private func avatarSection(_ profile: UserProfile) -> some View {
        VStack(spacing: 10) {
            // Círculo con blur glass detrás del avatar
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 98, height: 98)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.actionGreen, Color.accentOrange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .overlay(
                        Text(String(profile.username.prefix(1)).uppercased())
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Color.accentOrange.opacity(0.45), radius: 14, x: 0, y: 7)
            }

            Text(profile.username)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(profile.email)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // Tarjeta de campos con fondo blur (vidrio esmerilado)
    private var fieldsSection: some View {
        VStack(spacing: 0) {
            profileRow(icon: "person.fill",    label: "Usuario",     binding: $username)
            Divider().padding(.leading, 50)
            profileRow(icon: "text.alignleft", label: "Descripción", binding: $description)
            Divider().padding(.leading, 50)
            profileRow(icon: "phone.fill",     label: "Teléfono",    binding: $phoneNumber)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        // Blur glass para la tarjeta de campos
        .background(.regularMaterial)
        .colorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    // Fila de campo individual en modo lectura o edición
    private func profileRow(icon: String, label: String, binding: Binding<String>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Color.actionGreen)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                if isEditing {
                    TextField(label, text: binding)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .tint(Color.actionGreen)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(icon == "phone.fill" ? .never : .words)
                } else {
                    Text(binding.wrappedValue.isEmpty ? "—" : binding.wrappedValue)
                        .font(.body)
                        .foregroundStyle(binding.wrappedValue.isEmpty
                                         ? Color(uiColor: .tertiaryLabel)
                                         : Color(uiColor: .label))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // Botón de cierre de sesión con fondo blur
    private var logoutButton: some View {
        Button(role: .destructive) {
            authVM.signOut()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Cerrar sesión")
                    .font(.system(.body, design: .rounded, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .foregroundStyle(.red)
        .background(.regularMaterial)
        .colorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // Toolbar con botones Editar / Guardar / Cancelar
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if isEditing {
                HStack {
                    Button("Cancelar") {
                        username     = profile?.username    ?? ""
                        description  = profile?.description ?? ""
                        phoneNumber  = profile?.phoneNumber ?? ""
                        errorMessage = ""
                        isEditing    = false
                    }
                    .tint(.white.opacity(0.75))

                    Button(isSaving ? "Guardando…" : "Guardar") {
                        saveProfile()
                    }
                    .tint(.white)
                    .disabled(isSaving)
                }
            } else {
                Button("Editar") { isEditing = true }
                    .tint(.white)
            }
        }
    }

    // Carga el perfil desde Firestore al aparecer la vista
    private func loadProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            if let p = try await FirestoreService.shared.fetchProfile(uid: uid) {
                profile      = p
                username     = p.username
                description  = p.description
                phoneNumber  = p.phoneNumber
                oldUsername  = p.username
            }
        } catch {
            print("[Profile] Error al cargar: \(error)")
        }
    }

    // Guarda los cambios en Firestore
    private func saveProfile() {
        guard var p = profile else { return }
        let newUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard newUsername.count >= 3 else {
            errorMessage = "El nombre de usuario debe tener al menos 3 caracteres."
            return
        }
        isSaving     = true
        errorMessage = ""
        p.username    = newUsername
        p.description = description
        p.phoneNumber = phoneNumber

        Task {
            do {
                try await FirestoreService.shared.updateProfile(p, oldUsername: oldUsername)
                profile     = p
                oldUsername = p.username
                isEditing   = false
            } catch {
                errorMessage = (error as? AppError)?.localizedDescription
                              ?? "Error al guardar. Intenta de nuevo."
            }
            isSaving = false
        }
    }
}
