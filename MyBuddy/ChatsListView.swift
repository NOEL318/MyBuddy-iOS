import SwiftUI
import FirebaseAuth

struct ChatsListView: View {

    @EnvironmentObject var authVM: AuthViewModel
    @State private var users:      [UserProfile] = []
    @State private var isLoading:  Bool = true
    @State private var searchText: String = ""
    @State private var appeared:   Bool = false

    private var filteredUsers: [UserProfile] {
        // Filtra usuarios por texto de búsqueda y excluye al usuario actual
        let others = users.filter { $0.id != authVM.user?.uid }
        guard !searchText.isEmpty else { return others }
        return others.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        // Compone la lista de chats con búsqueda, refresco y navegación al detalle
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

    private var contactList: some View {
        // Lista scrolleable de contactos con animación escalonada
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

    private func contactRow(_ user: UserProfile, index: Int) -> some View {
        // Construye una fila estilo WhatsApp con avatar, username y email
        HStack(spacing: 14) {
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

    private var emptyState: some View {
        // Vista mostrada cuando no hay contactos o la búsqueda no devuelve resultados
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

    private func loadUsers() async {
        // Descarga todos los usuarios registrados desde Firestore
        isLoading = true
        appeared  = false
        do {
            users = try await FirestoreService.shared.fetchAllUsers()
        } catch {
            print("[ChatsListView] Error al cargar usuarios: \(error)")
        }
        isLoading = false
    }

    private func avatarColor(for username: String) -> Color {
        // Asigna un color de avatar determinista a partir del username
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
