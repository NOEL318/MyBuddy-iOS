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
            // Devuelve la etiqueta legible asociada al estado de conexión
            switch self {
            case .disconnected:  return "Desconectado"
            case .connecting:    return "Conectando..."
            case .connected:     return "En línea"
            case .peerConnected: return "En línea"
            }
        }

        var isActive: Bool {
            // Indica si el WebSocket está autenticado y operativo
            self == .connected || self == .peerConnected
        }
    }

    var onStateChange: ((ConnectionState) -> Void)?
    var onTyping: (() -> Void)?

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private(set) var state: ConnectionState = .disconnected

    private var userId:      String = ""
    private var recipientId: String = ""

    func connect(userId: String, recipientId: String) {
        // Guarda los identificadores y abre la conexión WebSocket
        self.userId      = userId
        self.recipientId = recipientId
        reconnect()
    }

    func disconnect() {
        // Cierra la conexión y vuelve al estado desconectado
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        setState(.disconnected)
    }

    func sendTyping() {
        // Envía un evento efímero de "escribiendo" al destinatario
        struct TypingMsg: Encodable {
            let type = "typing"
            let from: String
            let to:   String
        }
        guard let data = try? JSONEncoder().encode(TypingMsg(from: userId, to: recipientId)),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    private func setState(_ newState: ConnectionState) {
        // Actualiza el estado interno y notifica al ViewModel vía callback
        state = newState
        onStateChange?(newState)
    }

    private func reconnect() {
        // Crea una nueva tarea WebSocket, se identifica y arranca el loop de recepción
        guard let url = URL(string: SERVER_URL) else { return }
        setState(.connecting)
        task = session.webSocketTask(with: url)
        task?.resume()
        identify()
        receiveLoop()
    }

    private func identify() {
        // Envía el mensaje de identificación con el userId actual
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

    private func receiveLoop() {
        // Escucha mensajes en bucle y reconecta automáticamente al perder la conexión
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

    private func handleRawMessage(_ text: String) {
        // Parsea el JSON entrante y dispara los eventos de presencia y typing
        guard let data = text.data(using: .utf8),
              let incoming = try? JSONDecoder().decode(IncomingMessage.self, from: data) else { return }

        switch incoming.type {
        case .peerConnected:
            if incoming.userId == recipientId { setState(.peerConnected) }
        case .peerDisconnected:
            if incoming.userId == recipientId { setState(.connected) }
        case .typing:
            guard incoming.from == recipientId else { return }
            onTyping?()
        default:
            break
        }
    }
}
