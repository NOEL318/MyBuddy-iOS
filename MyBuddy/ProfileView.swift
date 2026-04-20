import SwiftUI
import FirebaseAuth

struct ProfileView: View {

    @EnvironmentObject var authVM: AuthViewModel

    @State private var profile:     UserProfile? = nil
    @State private var username:    String = ""
    @State private var description: String = ""
    @State private var phoneNumber: String = ""
    @State private var oldUsername: String = ""
    @State private var isEditing:   Bool = false
    @State private var isSaving:    Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surface.ignoresSafeArea()

                if let profile {
                    ScrollView {
                        VStack(spacing: 20) {
                            avatarSection(profile)
                            fieldsSection
                            logoutButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                } else {
                    ProgressView()
                        .tint(Color.actionGreen)
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbar }
        }
        .task { await loadProfile() }
    }

    // Avatar circular con inicial del username
    private func avatarSection(_ profile: UserProfile) -> some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.actionGreen)
                .frame(width: 90, height: 90)
                .overlay(
                    Text(String(profile.username.prefix(1)).uppercased())
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.actionGreen.opacity(0.35), radius: 10, x: 0, y: 4)

            Text(profile.username)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(profile.email)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // Tarjeta de campos editables
    private var fieldsSection: some View {
        VStack(spacing: 0) {
            profileRow(icon: "person.fill", label: "Usuario", binding: $username)
            Divider().padding(.leading, 48)
            profileRow(icon: "text.alignleft", label: "Descripción", binding: $description)
            Divider().padding(.leading, 48)
            profileRow(icon: "phone.fill", label: "Teléfono", binding: $phoneNumber)

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
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // Fila de campo individual con modo lectura/edición
    private func profileRow(icon: String, label: String, binding: Binding<String>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Color.actionGreen)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isEditing {
                    TextField(label, text: binding)
                        .font(.body)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(icon == "phone.fill" ? .never : .words)
                } else {
                    Text(binding.wrappedValue.isEmpty ? "—" : binding.wrappedValue)
                        .font(.body)
                        .foregroundStyle(binding.wrappedValue.isEmpty ? .secondary : .primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // Botón de cierre de sesión
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
            .background(.white)
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
    }

    // Toolbar con botones Editar / Guardar / Cancelar
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if isEditing {
                HStack {
                    Button("Cancelar") {
                        // Restaura valores originales
                        username    = profile?.username    ?? ""
                        description = profile?.description ?? ""
                        phoneNumber = profile?.phoneNumber ?? ""
                        errorMessage = ""
                        isEditing = false
                    }
                    .tint(.secondary)
                    Button(isSaving ? "Guardando…" : "Guardar") {
                        saveProfile()
                    }
                    .tint(Color.actionGreen)
                    .disabled(isSaving)
                }
            } else {
                Button("Editar") { isEditing = true }
                    .tint(Color.actionGreen)
            }
        }
    }

    // Carga el perfil desde Firestore al aparecer la vista
    private func loadProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            if let p = try await FirestoreService.shared.fetchProfile(uid: uid) {
                profile     = p
                username    = p.username
                description = p.description
                phoneNumber = p.phoneNumber
                oldUsername = p.username
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
        isSaving = true
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
