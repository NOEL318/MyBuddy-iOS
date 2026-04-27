import SwiftUI
import FirebaseAuth

/// Vista de detalle de un contacto del directorio, con opción de iniciar chat
struct ContactDetailView: View {

    let user: UserProfile
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        ZStack(alignment: .top) {
            Color.surface.ignoresSafeArea()

            // Degradado verde → naranja (mitad de pantalla)
            LinearGradient(
                colors: [
                    Color.primaryGreen,
                    Color.actionGreen.opacity(0.8),
                    Color.accentOrange.opacity(0.55),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.52)
            )
            .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 22) {
                    avatarSection
                    infoCard
                    if let uid = authVM.user?.uid {
                        chatButton(currentUid: uid)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationTitle(user.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // Avatar grande con inicial y nombre
    private var avatarSection: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.actionGreen, Color.accentOrange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .overlay(
                    Text(String(user.username.prefix(1)).uppercased())
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.accentOrange.opacity(0.4), radius: 14, x: 0, y: 7)

            Text(user.username)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(user.email)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.80))
        }
        .padding(.bottom, 4)
    }

    // Tarjeta de información del contacto
    private var infoCard: some View {
        VStack(spacing: 0) {
            if !user.description.isEmpty {
                infoRow(icon: "text.alignleft", label: "Descripción", value: user.description)
                Divider().padding(.leading, 50)
            }
            infoRow(icon: "envelope.fill", label: "Email", value: user.email)
            if !user.phoneNumber.isEmpty {
                Divider().padding(.leading, 50)
                infoRow(icon: "phone.fill", label: "Teléfono", value: user.phoneNumber)
            }
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .colorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Color.actionGreen)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color(uiColor: .label))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // Botón para iniciar la conversación de chat
    @ViewBuilder
    private func chatButton(currentUid: String) -> some View {
        NavigationLink(destination: ContentView(recipient: user, currentUid: currentUid)) {
            HStack(spacing: 10) {
                Image(systemName: "message.fill")
                Text("Iniciar chat")
                    .font(.system(.body, design: .rounded, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color.actionGreen, Color.primaryGreen],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primaryGreen.opacity(0.35), radius: 8, x: 0, y: 4)
        }
    }
}
