import Foundation

enum MessageType: String, Codable {
    case text
    case image
    case peerConnected    = "peer_connected"
    case peerDisconnected = "peer_disconnected"
    case identify
}

enum MessageSender: String, Codable {
    case ios
    case web
}

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    /// ID del documento en Firestore; nil hasta que el mensaje se confirma
    var firestoreId: String?
    let type: MessageType
    let sender: MessageSender
    let content: String
    let mimeType: String?
    let timestamp: TimeInterval
    /// true cuando el mensaje fue persistido exitosamente en Firestore
    var isConfirmed: Bool

    // Inicializa un mensaje con UUID y timestamp automáticos si no se proveen
    init(
        id:          UUID = UUID(),
        firestoreId: String? = nil,
        type:        MessageType,
        sender:      MessageSender,
        content:     String,
        mimeType:    String? = nil,
        timestamp:   TimeInterval = Date().timeIntervalSince1970 * 1000,
        isConfirmed: Bool = false
    ) {
        self.id          = id
        self.firestoreId = firestoreId
        self.type        = type
        self.sender      = sender
        self.content     = content
        self.mimeType    = mimeType
        self.timestamp   = timestamp
        self.isConfirmed = isConfirmed
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
