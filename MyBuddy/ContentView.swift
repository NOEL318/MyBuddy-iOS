import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var textInput           = ""
    @State private var showImageSourceSheet = false
    @State private var showCamera          = false
    @State private var showGallery         = false
    @State private var scrollProxy: ScrollViewProxy? = nil
    // Controla la escala del botón de enviar al pulsarlo
    @State private var sendButtonScale: CGFloat = 1.0

    // Construye la vista principal con header, mensajes y barra de entrada
    var body: some View {
        VStack(spacing: 0) {
            headerView
            messagesView
            inputBar
        }
        .background(Color.chatBg.ignoresSafeArea())
        .onAppear  { viewModel.connect()    }
        .onDisappear { viewModel.disconnect() }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                viewModel.sendImage(image)
            }
        }
        .sheet(isPresented: $showGallery) {
            ImagePicker(sourceType: .photoLibrary) { image in
                viewModel.sendImage(image)
            }
        }
        .confirmationDialog("Seleccionar imagen", isPresented: $showImageSourceSheet) {
            Button("Cámara")  { showCamera  = true }
            Button("Galería") { showGallery = true }
            Button("Cancelar", role: .cancel) {}
        }
    }

    // Muestra el avatar, nombre del chat y el estado de conexión actual
    private var headerView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.actionGreen)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("M")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("MyBuddy")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 5) {
                    // Punto de estado con efecto pulse cuando hay conexión activa
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
        .background(Color.primaryGreen)
    }

    // Retorna el color del indicador de estado según la conexión actual
    private var statusColor: Color {
        switch viewModel.connectionState {
        case .peerConnected: return Color(red: 0.56, green: 0.96, blue: 0.74)
        case .disconnected:  return Color(red: 1.0,  green: 0.45, blue: 0.45)
        default:             return .white.opacity(0.6)
        }
    }

    // Lista scrolleable de burbujas con paginación al llegar al inicio
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    // Trigger de paginación invisible en la parte superior
                    paginationTrigger(proxy: proxy)

                    ForEach(viewModel.messages) { msg in
                        MessageBubbleView(message: msg)
                            .padding(.horizontal, 8)
                            .id(msg.id)
                            .transition(
                                .scale(scale: 0.88, anchor: msg.isFromMe ? .bottomTrailing : .bottomLeading)
                                .combined(with: .opacity)
                            )
                    }
                }
                .padding(.vertical, 8)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.messages.count)
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: viewModel.messages.last?.id) { _, lastId in
                // Auto-scroll solo cuando llega un mensaje nuevo al final (no en paginación)
                guard !viewModel.isLoadingMore, let id = lastId else { return }
                withAnimation(.spring(response: 0.35)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    // Vista de paginación en la parte superior de la lista
    @ViewBuilder
    private func paginationTrigger(proxy: ScrollViewProxy) -> some View {
        if viewModel.hasMoreMessages {
            Group {
                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(Color.actionGreen)
                        .padding(.vertical, 12)
                } else {
                    Color.clear.frame(height: 1)
                        .onAppear {
                            // Guarda la ID del primer mensaje antes de cargar más
                            let firstId = viewModel.messages.first?.id
                            Task {
                                await viewModel.loadMoreMessages()
                                // Restaura la posición de scroll después de prepend
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

    // Barra inferior con botón de imagen, campo de texto y botón de enviar
    private var inputBar: some View {
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
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .font(.body)

            Button {
                let text = textInput
                textInput = ""
                viewModel.sendText(text)
                // Animación de escala al pulsarlo
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    sendButtonScale = 0.78
                }
                withAnimation(.spring(response: 0.25).delay(0.1)) {
                    sendButtonScale = 1.0
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? Color.gray.opacity(0.35)
                                  : Color.actionGreen)
                    )
            }
            .scaleEffect(sendButtonScale)
            .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.surface)
    }
}

#Preview {
    ContentView()
}
