import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var textInput = ""
    @State private var showImageSourceSheet = false
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    // Construye la vista principal con header, mensajes y barra de entrada
    var body: some View {
        VStack(spacing: 0) {
            headerView
            messagesView
            inputBar
        }
        .background(chatBackground)
        .onAppear { viewModel.connect() }
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
            Button("Cámara") { showCamera = true }
            Button("Galería") { showGallery = true }
            Button("Cancelar", role: .cancel) {}
        }
    }

    // Muestra el avatar, nombre del chat y el estado de conexión actual
    private var headerView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(red: 0.145, green: 0.369, blue: 0.329))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("M")
                        .font(.headline)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("MyBuddy")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(viewModel.connectionState.label)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.027, green: 0.369, blue: 0.329))
    }

    // Retorna el color del texto de estado según el estado de conexión actual
    private var statusColor: Color {
        switch viewModel.connectionState {
        case .peerConnected: return Color(red: 0.66, green: 0.96, blue: 0.75)
        case .disconnected:  return Color(red: 1, green: 0.7, blue: 0.7)
        default:             return .white.opacity(0.8)
        }
    }

    // Lista scrolleable de burbujas que hace auto-scroll al recibir un nuevo mensaje
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.messages) { msg in
                        MessageBubbleView(message: msg)
                            .padding(.horizontal, 8)
                            .id(msg.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
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
                    .foregroundStyle(Color(red: 0.027, green: 0.369, blue: 0.329))
            }
            .padding(.leading, 4)

            TextField("Escribe un mensaje...", text: $textInput, axis: .vertical)
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
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? Color.gray.opacity(0.4)
                                  : Color(red: 0.027, green: 0.369, blue: 0.329))
                    )
            }
            .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 0.94, green: 0.95, blue: 0.96))
    }

    // Fondo color crema del área de mensajes
    private var chatBackground: some View {
        Color(red: 0.94, green: 0.92, blue: 0.87)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
