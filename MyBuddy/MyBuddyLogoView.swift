import SwiftUI

/// Logo circular de MyBuddy con degradado verde→naranja y el ícono de chat
struct MyBuddyLogoView: View {

    var size: CGFloat = 80

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.primaryGreen, Color.actionGreen, Color.accentOrange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.accentOrange.opacity(0.35), radius: size * 0.18, x: 0, y: size * 0.06)

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: size * 0.40))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    ZStack {
        Color.primaryGreen.ignoresSafeArea()
        MyBuddyLogoView(size: 100)
    }
}
