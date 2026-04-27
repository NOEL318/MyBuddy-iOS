import SwiftUI
import FirebaseAuth

/// Lista de contactos disponibles para iniciar una conversación de chat
struct ChatsListView: View {

    @EnvironmentObject var authVM: AuthViewModel
    @State private var users:      [UserProfile] = []
    @State private var isLoading:  Bool = true
    @State private var searchText: String = ""
    @State private var appeared:   Bool = false

    // Filtra usuarios según el texto de búsqueda, excluyendo al usuario actual
    private var filteredUsers: [UserProfile] {
        let others = users.filter { $0.id != authVM.user?.uid }
        guard !searchText.isEmpty else { return others }
        return others.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surface.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(Color.actionGreen)
                } else if filteredUsers.isEmpty {
                    emptyState
                } else {
                    contactList
                }
            }
            .colorScheme(.light)
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Buscar por nombre o email")
            .task { await loadUsers() }
            .refreshable { await loadUsers() }
            .toolbarBackground(
                LinearGradient(
                    colors: [Color.primaryGreen, Color.actionGreen, Color.accentOrange.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: UserProfile.self) { user in
                if let uid = authVM.user?.uid {
                    ContentView(recipient: user, currentUid: uid)
                }
            }
        }
    }

    // Lista de contactos con entrada escalonada y navegación al chat
    private var contactList: some View {
        List {
            ForEach(Array(filteredUsers.enumerated()), id: \.element.id) { index, user in
                NavigationLink(value: user) {
                    contactRow(user, index: index)
                }
                .listRowBackground(Color.white)
                .listRowSeparatorTint(Color.gray.opacity(0.18))
            }
        }
        .listStyle(.plain)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
        }
    }

    // Fila individual de contacto estilo WhatsApp
    private func contactRow(_ user: UserProfile, index: Int) -> some View {
        HStack(spacing: 14) {
            // Avatar con inicial del username
            Circle()
                .fill(avatarColor(for: user.username))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(user.username.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(user.username)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(Color(uiColor: .label))
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(
            .easeOut(duration: 0.35).delay(min(Double(index) * 0.05, 0.5)),
            value: appeared
        )
    }

    // Vista de estado vacío cuando no hay contactos o resultados
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty
                 ? "No hay contactos disponibles"
                 : "Sin resultados para «\(searchText)»")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // Carga todos los usuarios registrados desde Firestore
    private func loadUsers() async {
        isLoading = true
        appeared  = false
        do {
            users = try await FirestoreService.shared.fetchAllUsers()
        } catch {
            print("[ChatsListView] Error al cargar usuarios: \(error)")
        }
        isLoading = false
    }

    // Color de avatar determinista basado en el username
    private func avatarColor(for username: String) -> Color {
        let palette: [Color] = [
            Color.actionGreen,
            Color(red: 0.2,  green: 0.47, blue: 0.78),
            Color(red: 0.7,  green: 0.35, blue: 0.15),
            Color(red: 0.55, green: 0.27, blue: 0.67),
            Color(red: 0.18, green: 0.57, blue: 0.51)
        ]
        return palette[abs(username.hashValue) % palette.count]
    }
}
