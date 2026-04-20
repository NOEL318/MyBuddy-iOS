import SwiftUI

struct DirectoryView: View {

    @State private var users:       [UserProfile] = []
    @State private var searchText:  String = ""
    @State private var isLoading:   Bool = true
    @State private var appeared:    Bool = false

    // Filtra usuarios según el texto de búsqueda
    private var filteredUsers: [UserProfile] {
        guard !searchText.isEmpty else { return users }
        return users.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
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
                    userList
                }
            }
            .navigationTitle("Directorio")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Buscar usuario o descripción")
            .task { await loadUsers() }
            .refreshable { await loadUsers() }
        }
    }

    // Lista de usuarios con entrada escalonada
    private var userList: some View {
        List {
            ForEach(Array(filteredUsers.enumerated()), id: \.element.id) { index, user in
                userRow(user, index: index)
                    .listRowBackground(Color.white)
                    .listRowSeparatorTint(.gray.opacity(0.2))
            }
        }
        .listStyle(.plain)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
        }
    }

    // Fila individual de usuario estilo WhatsApp
    private func userRow(_ user: UserProfile, index: Int) -> some View {
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
                    .foregroundStyle(.primary)
                if !user.description.isEmpty {
                    Text(user.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        // Entrada escalonada; se limita el delay para listas largas
        .animation(
            .easeOut(duration: 0.35).delay(min(Double(index) * 0.05, 0.5)),
            value: appeared
        )
    }

    // Vista de estado vacío cuando no hay resultados
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No hay usuarios registrados" : "Sin resultados para «\(searchText)»")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // Carga todos los usuarios desde Firestore
    private func loadUsers() async {
        isLoading = true
        appeared  = false
        do {
            users = try await FirestoreService.shared.fetchAllUsers()
        } catch {
            print("[Directory] Error al cargar usuarios: \(error)")
        }
        isLoading = false
    }

    // Genera un color de avatar determinista a partir del username
    private func avatarColor(for username: String) -> Color {
        let palette: [Color] = [
            Color.actionGreen,
            Color(red: 0.2, green: 0.47, blue: 0.78),
            Color(red: 0.7, green: 0.35, blue: 0.15),
            Color(red: 0.55, green: 0.27, blue: 0.67),
            Color(red: 0.18, green: 0.57, blue: 0.51)
        ]
        let index = abs(username.hashValue) % palette.count
        return palette[index]
    }
}
