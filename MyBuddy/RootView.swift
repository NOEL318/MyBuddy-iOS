import SwiftUI
import FirebaseAuth

struct RootView: View {

    @StateObject private var authVM = AuthViewModel()
    @State private var selectedTab  = 0
    @State private var tabBounce = [false, false, false]
    @State private var splashScale: CGFloat = 1.0

    var body: some View {
        // Decide entre splash, login o el tab principal según el estado de auth
        Group {
            if authVM.isLoading {
                splashView
                    .transition(.opacity)
            } else if authVM.user != nil {
                mainTabView
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authVM.isLoading)
        .animation(.easeInOut(duration: 0.35), value: authVM.user?.uid)
        .environmentObject(authVM)
    }

    private var splashView: some View {
        // Pantalla de carga con logo pulsante mientras Firebase resuelve la sesión
        ZStack {
            LinearGradient(
                colors: [Color.primaryGreen, Color.actionGreen.opacity(0.9), Color.accentOrange.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 18) {
                MyBuddyLogoView(size: 100)
                    .scaleEffect(splashScale)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                        ) {
                            splashScale = 1.08
                        }
                    }
                Text("MyBuddy")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                ProgressView()
                    .tint(.white.opacity(0.7))
                    .padding(.top, 8)
            }
        }
    }

    private var mainTabView: some View {
        // Tab bar principal con Chats, Directorio y Perfil
        TabView(selection: $selectedTab) {
            ChatsListView()
                .tabItem {
                    Image(systemName: "message.fill")
                        .symbolEffect(.bounce, value: tabBounce[0])
                    Text("Chats")
                }
                .tag(0)

            DirectoryView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                        .symbolEffect(.bounce, value: tabBounce[1])
                    Text("Directorio")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                        .symbolEffect(.bounce, value: tabBounce[2])
                    Text("Perfil")
                }
                .tag(2)
        }
        .tint(Color.primaryGreen)
        .onChange(of: selectedTab) { _, newTab in
            tabBounce[newTab].toggle()
        }
    }
}

#Preview {
    RootView()
}
