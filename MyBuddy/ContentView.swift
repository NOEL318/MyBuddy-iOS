import SwiftUI

struct ContentView: View {
    let recipient: UserProfile

    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: ChatViewModel
    @State private var textInput            = ""
    @State private var showImageSourceSheet = false
    @State private var showCamera           = false
    @State private var showGallery          = false
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var sendButtonScale: CGFloat = 1.0

    init(recipient: UserProfile, currentUid: String) {
        // Crea el ChatViewModel asociado al destinatario y al usuario actual
        self.recipient = recipient
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            recipient:  recipient,
            currentUid: currentUid
        ))
    }

    var body: some View {
        // Compone la pantalla de chat con header, mensajes e input bar
        ZStack(alignment: .bottom) {
            Color.chatBg.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.primaryGreen.opacity(0.28),
                    Color.primaryGreen.opacity(0.10),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.32)
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                messagesView
                inputBar
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear    { viewModel.connect()    }
        .onDisappear { viewModel.disconnect() }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in viewModel.sendImage(image) }
        }
        .sheet(isPresented: $showGallery) {
            ImagePicker(sourceType: .photoLibrary) { image in viewModel.sendImage(image) }
        }
        .confirmationDialog("Seleccionar imagen", isPresented: $showImageSourceSheet) {
            Button("Cámara")  { showCamera  = true }
            Button("Galería") { showGallery = true }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var headerView: some View {
        // Header con botón de regreso, avatar del destinatario y estado de conexión
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(recipient.username.prefix(1)).uppercased())
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(recipient.username)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 5) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(statusColor)
                        .symbolEffect(.pulse, options: .repeating,
                                      isActive: viewModel.connectionState.isActive)

                    Text(viewModel.connectionState.label)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.primaryGreen, Color.actionGreen.opacity(0.88), Color.accentOrange.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .shadow(color: Color.primaryGreen.opacity(0.45), radius: 8, x: 0, y: 4)
    }

    private var statusColor: Color {
        // Devuelve el color del punto de presencia según el estado de la conexión
        switch viewModel.connectionState {
        case .peerConnected: return Color(red: 0.56, green: 0.96, blue: 0.74)
        case .disconnected:  return Color(red: 1.0,  green: 0.45, blue: 0.45)
        default:             return .white.opacity(0.6)
        }
    }

    private var messagesView: some View {
        // Lista scrolleable con paginación al inicio e indicador de escritura al final
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    paginationTrigger(proxy: proxy)

                    ForEach(viewModel.messages) { msg in
                        MessageBubbleView(message: msg)
                            .padding(.horizontal, 8)
                            .id(msg.id)
                            .transition(
                                .scale(scale: 0.88,
                                       anchor: msg.isFromMe ? .bottomTrailing : .bottomLeading)
                                .combined(with: .opacity)
                            )
                    }

                    if viewModel.recipientIsTyping {
                        TypingIndicatorView()
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .id("typing")
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
                    }
                }
                .padding(.vertical, 8)
                .animation(.spring(response: 0.35, dampingFraction: 0.75),
                           value: viewModel.messages.count)
                .animation(.easeInOut(duration: 0.2), value: viewModel.recipientIsTyping)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)
            .onAppear { scrollProxy = proxy }
            .onChange(of: viewModel.messages.last?.id) { _, lastId in
                guard !viewModel.isLoadingMore, let id = lastId else { return }
                withAnimation(.spring(response: 0.35)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.recipientIsTyping) { _, isTyping in
                if isTyping {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func paginationTrigger(proxy: ScrollViewProxy) -> some View {
        // Dispara la carga de mensajes anteriores cuando aparece el sentinel al hacer scroll arriba
        if viewModel.hasMoreMessages {
            Group {
                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(Color.actionGreen)
                        .padding(.vertical, 12)
                } else {
                    Color.clear.frame(height: 1)
                        .onAppear {
                            let firstId = viewModel.messages.first?.id
                            Task {
                                await viewModel.loadMoreMessages()
                                if let id = firstId {
                                    try? await Task.sleep(nanoseconds: 120_000_000)
                                    proxy.scrollTo(id, anchor: .top)
                                }
                            }
                        }
                }
            }
        }
    }

    private var inputBar: some View {
        // Barra inferior con botón de imagen, campo de texto y botón de envío
        HStack(spacing: 8) {
            Button {
                showImageSourceSheet = true
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.actionGreen)
            }
            .padding(.leading, 4)

            TextField("Escribe un mensaje…", text: $textInput, axis: .vertical)
                .lineLimit(1...5)
                .foregroundStyle(Color.primary)
                .tint(Color.actionGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.88))
                .colorScheme(.light)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .font(.body)
                .onChange(of: textInput) { _, _ in
                    viewModel.userDidType()
                }

            Button {
                let text = textInput
                textInput = ""
                viewModel.sendText(text)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { sendButtonScale = 0.78 }
                withAnimation(.spring(response: 0.25).delay(0.1))           { sendButtonScale = 1.0  }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(
                            textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.gray.opacity(0.35)
                            : Color.actionGreen
                        )
                    )
            }
            .scaleEffect(sendButtonScale)
            .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.3)
        }
    }
}

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        // Tres puntos animados dentro de una burbuja para indicar "escribiendo"
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.gray.opacity(0.55))
                    .frame(width: 9, height: 9)
                    .offset(y: animating ? -5 : 5)
                    .animation(
                        .easeInOut(duration: 0.42)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(BubbleShape(isFromMe: false))
        .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
        .onAppear { animating = true }
    }
}
