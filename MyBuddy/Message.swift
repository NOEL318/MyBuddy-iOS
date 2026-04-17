import Foundation

enum MessageType: String, Codable {
    case text
    case image
    case peerConnected = "peer_connected"
    case peerDisconnected = "peer_disconnected"
    case identify
}

enum MessageSender: String, Codable {
    case ios
    case web
}

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let type: MessageType
    let sender: MessageSender
    let content: String
    let mimeType: String?
    let timestamp: TimeInterval

    // Inicializa un mensaje con UUID y timestamp automáticos si no se proveen
    init(id: UUID = UUID(), type: MessageType, sender: MessageSender, content: String, mimeType: String? = nil, timestamp: TimeInterval = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.type = type
        self.sender = sender
        self.content = content
        self.mimeType = mimeType
        self.timestamp = timestamp
    }

    // Retorna true si el mensaje fue enviado desde este dispositivo iOS
    var isFromMe: Bool { sender == .ios }

    // Retorna la hora del mensaje formateada como HH:MM
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct IncomingMessage: Codable {
    let type: MessageType
    let sender: MessageSender?
    let content: String?
    let mimeType: String?
    let timestamp: TimeInterval?
}
