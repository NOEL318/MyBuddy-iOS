import Foundation

enum MessageType: String, Codable {
    case text
    case image
    case typing
    case peerConnected    = "peer_connected"
    case peerDisconnected = "peer_disconnected"
    case identify
}

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    var firestoreId: String?
    let type: MessageType
    let sender: String
    let recipient: String
    let content: String
    let mimeType: String?
    let timestamp: TimeInterval
    var isFromMe: Bool
    var isConfirmed: Bool

    init(
        id:          UUID = UUID(),
        firestoreId: String? = nil,
        type:        MessageType,
        sender:      String,
        recipient:   String,
        content:     String,
        mimeType:    String? = nil,
        timestamp:   TimeInterval = Date().timeIntervalSince1970 * 1000,
        isFromMe:    Bool,
        isConfirmed: Bool = false
    ) {
        // Inicializa el mensaje aplicando UUID y timestamp por defecto si no se proveen
        self.id          = id
        self.firestoreId = firestoreId
        self.type        = type
        self.sender      = sender
        self.recipient   = recipient
        self.content     = content
        self.mimeType    = mimeType
        self.timestamp   = timestamp
        self.isFromMe    = isFromMe
        self.isConfirmed = isConfirmed
    }

    var formattedTime: String {
        // Devuelve la hora del mensaje formateada como HH:mm
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct IncomingMessage: Codable {
    let type: MessageType
    let from: String?
    let to: String?
    let userId: String?
    let content: String?
    let mimeType: String?
    let timestamp: TimeInterval?
}
