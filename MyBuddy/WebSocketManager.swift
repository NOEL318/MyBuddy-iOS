import Foundation

let SERVER_URL = "ws://kristie-cystocarpic-nonremediably.ngrok-free.dev"

@MainActor
class WebSocketManager {

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case peerConnected

        var label: String {
            switch self {
            case .disconnected:  return "Desconectado"
            case .connecting:    return "Conectando..."
            case .connected:     return "En línea"
            case .peerConnected: return "En línea"
            }
        }

        var isActive: Bool {
            self == .connected || self == .peerConnected
        }
    }

    var onStateChange: ((ConnectionState) -> Void)?
    /// Notifica que el destinatario está escribiendo
    var onTyping: (() -> Void)?

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private(set) var state: ConnectionState = .disconnected

    private var userId:      String = ""
    private var recipientId: String = ""

    /// Inicia la conexión WebSocket identificándose con el userId dado
    func connect(userId: String, recipientId: String) {
        self.userId      = userId
        self.recipientId = recipientId
        reconnect()
    }

    /// Cierra la conexión WebSocket
    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        setState(.disconnected)
    }

    /// Envía un evento de "escribiendo" al destinatario (efímero, no se persiste)
    func sendTyping() {
        struct TypingMsg: Encodable {
            let type = "typing"
            let from: String
            let to:   String
        }
        guard let data = try? JSONEncoder().encode(TypingMsg(from: userId, to: recipientId)),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    // Actualiza el estado de conexión y notifica al ViewModel vía callback
    private func setState(_ newState: ConnectionState) {
        state = newState
        onStateChange?(newState)
    }

    /// Crea la tarea WebSocket y comienza la conexión
    private func reconnect() {
        guard let url = URL(string: SERVER_URL) else { return }
        setState(.connecting)
        task = session.webSocketTask(with: url)
        task?.resume()
        identify()
        receiveLoop()
    }

    /// Envía el mensaje de identificación con el userId del usuario actual
    private func identify() {
        struct IdentifyMsg: Encodable { let type = "identify"; let userId: String }
        guard let data = try? JSONEncoder().encode(IdentifyMsg(userId: userId)),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { [weak self] error in
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                self?.setState(.connected)
            }
        }
    }

    /// Escucha mensajes entrantes en loop; reconecta automáticamente si se pierde la conexión
    private func receiveLoop() {
        task?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    let text: String?
                    switch message {
                    case .string(let s): text = s
                    case .data(let d):   text = String(data: d, encoding: .utf8)
                    @unknown default:    text = nil
                    }
                    if let text { self.handleRawMessage(text) }
                    self.receiveLoop()
                case .failure:
                    self.setState(.disconnected)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    self.reconnect()
                }
            }
        }
    }

    /// Parsea el JSON recibido: maneja estado de peers y eventos de typing
    private func handleRawMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let incoming = try? JSONDecoder().decode(IncomingMessage.self, from: data) else { return }

        switch incoming.type {
        case .peerConnected:
            if incoming.userId == recipientId { setState(.peerConnected) }
        case .peerDisconnected:
            if incoming.userId == recipientId { setState(.connected) }
        case .typing:
            // Solo notifica si el evento viene de nuestro destinatario
            guard incoming.from == recipientId else { return }
            onTyping?()
        default:
            break
        }
    }
}
