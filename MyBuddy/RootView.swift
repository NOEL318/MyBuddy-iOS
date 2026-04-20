import SwiftUI

/// Vista raíz que decide entre splash, login o la app principal
/// según el estado de autenticación de Firebase.
struct RootView: View {

    @StateObject private var authVM = AuthViewModel()
    @State private var selectedTab  = 0
    // Estado de rebote por tab para la animación del tab bar
    @State private var tabBounce = [false, false, false]
    // Ángulo de rotación del logo en el splash
    @State private var splashRotation: Double = 0

    var body: some View {
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

    // Pantalla de carga mientras Firebase resuelve el estado de auth
    private var splashView: some View {
        ZStack {
            Color.primaryGreen.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(splashRotation))
                    .onAppear {
                        withAnimation(
                            .linear(duration: 1.4).repeatForever(autoreverses: false)
                        ) {
                            splashRotation = 360
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

    // Tab bar principal: Chat | Directorio | Perfil
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            // ── Chat ──────────────────────────────────────────────────
            ContentView()
                .tabItem {
                    Image(systemName: "message.fill")
                        .symbolEffect(.bounce, value: tabBounce[0])
                    Text("Chat")
                }
                .tag(0)

            // ── Directorio ───────────────────────────────────────────
            DirectoryView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                        .symbolEffect(.bounce, value: tabBounce[1])
                    Text("Directorio")
                }
                .tag(1)

            // ── Perfil ────────────────────────────────────────────────
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
            // Dispara la animación de rebote en el ícono del tab seleccionado
            tabBounce[newTab].toggle()
        }
    }
}

#Preview {
    RootView()
}
