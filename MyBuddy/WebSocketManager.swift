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
            case .connected:     return "Esperando Web..."
            case .peerConnected: return "Web conectado"
            }
        }

        var isActive: Bool {
            self == .connected || self == .peerConnected
        }
    }

    var onStateChange: ((ConnectionState) -> Void)?
    var onMessage: ((IncomingMessage) -> Void)?

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private(set) var state: ConnectionState = .disconnected

    // Crea la tarea WebSocket y comienza la conexión al servidor
    func connect() {
        guard let url = URL(string: SERVER_URL) else { return }
        setState(.connecting)
        task = session.webSocketTask(with: url)
        task?.resume()
        identify()
        receiveLoop()
    }

    // Cierra la conexión WebSocket y actualiza el estado a desconectado
    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        setState(.disconnected)
    }

    // Empaqueta y envía un mensaje de texto al servidor
    func sendText(_ text: String) {
        send(OutgoingMessage(type: "text", sender: "ios", content: text, mimeType: nil, timestamp: Date().msTimestamp))
    }

    // Empaqueta y envía una imagen codificada en base64 al servidor
    func sendImage(base64: String, mimeType: String) {
        send(OutgoingMessage(type: "image", sender: "ios", content: base64, mimeType: mimeType, timestamp: Date().msTimestamp))
    }

    // Actualiza el estado de conexión y notifica al ViewModel vía callback
    private func setState(_ newState: ConnectionState) {
        state = newState
        onStateChange?(newState)
    }

    // Envía el mensaje de identificación como cliente iOS y confirma la conexión al recibir respuesta
    private func identify() {
        struct IdentifyMsg: Encodable { let type = "identify"; let clientType = "ios" }
        guard let data = try? JSONEncoder().encode(IdentifyMsg()),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { [weak self] error in
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                self?.setState(.connected)
            }
        }
    }

    // Serializa el mensaje a JSON y lo envía por la conexión WebSocket
    private func send(_ msg: OutgoingMessage) {
        guard let data = try? JSONEncoder().encode(msg),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { error in
            if let error { print("[WS] Error enviando: \(error)") }
        }
    }

    // Escucha mensajes entrantes en loop y reconecta automáticamente si se pierde la conexión
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
                    self.connect()
                }
            }
        }
    }

    // Parsea el JSON recibido y actualiza el estado o entrega el mensaje al ViewModel
    private func handleRawMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let incoming = try? JSONDecoder().decode(IncomingMessage.self, from: data) else { return }

        switch incoming.type {
        case .peerConnected:    setState(.peerConnected)
        case .peerDisconnected: setState(.connected)
        case .text, .image:     onMessage?(incoming)
        default:                break
        }
    }
}

private struct OutgoingMessage: Encodable {
    let type: String
    let sender: String
    let content: String
    let mimeType: String?
    let timestamp: Double
}

private extension Date {
    var msTimestamp: Double { timeIntervalSince1970 * 1000 }
}
