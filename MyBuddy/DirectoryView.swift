import SwiftUI

struct DirectoryView: View {

    @State private var users:      [UserProfile] = []
    @State private var searchText: String = ""
    @State private var isLoading:  Bool = true
    @State private var appeared:   Bool = false

    private var filteredUsers: [UserProfile] {
        // Filtra usuarios por username o descripción según el texto de búsqueda
        guard !searchText.isEmpty else { return users }
        return users.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        // Compone el directorio con búsqueda, refresco y navegación al detalle
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
            .colorScheme(.light)
            .navigationTitle("Directorio")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Buscar usuario o descripción")
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
        }
    }

    private var userList: some View {
        // Lista scrolleable con animación escalonada y navegación a ContactDetailView
        List {
            ForEach(Array(filteredUsers.enumerated()), id: \.element.id) { index, user in
                NavigationLink(destination: ContactDetailView(user: user)) {
                    userRow(user, index: index)
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

    private func userRow(_ user: UserProfile, index: Int) -> some View {
        // Construye una fila estilo WhatsApp con avatar, username y descripción
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
                if !user.description.isEmpty {
                    Text(user.description)
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .lineLimit(1)
                }
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
        // Vista mostrada cuando no hay usuarios o la búsqueda está vacía de resultados
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty
                 ? "No hay usuarios registrados"
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
            print("[Directory] Error al cargar usuarios: \(error)")
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
