import SwiftUI
import UIKit
import Combine

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages: [Message] = []
    @Published var connectionState: WebSocketManager.ConnectionState = .disconnected

    private let wsManager = WebSocketManager()

    // Configura los callbacks del WebSocketManager para recibir estados y mensajes
    init() {
        wsManager.onStateChange = { [weak self] state in
            self?.connectionState = state
        }
        wsManager.onMessage = { [weak self] incoming in
            self?.handleIncoming(incoming)
        }
    }

    // Inicia la conexión WebSocket al servidor
    func connect() {
        wsManager.connect()
    }

    // Cierra la conexión WebSocket
    func disconnect() {
        wsManager.disconnect()
    }

    // Agrega el mensaje de texto localmente y lo envía por WebSocket
    func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let msg = Message(type: .text, sender: .ios, content: trimmed)
        messages.append(msg)
        wsManager.sendText(trimmed)
    }

    // Comprime la imagen a JPEG, la convierte a base64, la agrega localmente y la envía
    func sendImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let base64 = data.base64EncodedString()
        let msg = Message(type: .image, sender: .ios, content: base64, mimeType: "image/jpeg")
        messages.append(msg)
        wsManager.sendImage(base64: base64, mimeType: "image/jpeg")
    }

    // Convierte un mensaje entrante del servidor en un Message y lo agrega a la lista
    private func handleIncoming(_ incoming: IncomingMessage) {
        guard incoming.type == .text || incoming.type == .image,
              let sender = incoming.sender,
              let content = incoming.content else { return }

        let msg = Message(
            type: incoming.type,
            sender: sender,
            content: content,
            mimeType: incoming.mimeType,
            timestamp: incoming.timestamp ?? Date().timeIntervalSince1970 * 1000
        )
        messages.append(msg)
    }
}
