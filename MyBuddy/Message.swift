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
    /// ID del documento en Firestore; nil hasta que el mensaje se confirma
    var firestoreId: String?
    let type: MessageType
    /// UID de Firebase del remitente
    let sender: String
    /// UID de Firebase del destinatario
    let recipient: String
    let content: String
    let mimeType: String?
    let timestamp: TimeInterval
    /// true cuando el mensaje fue enviado por el usuario actual
    var isFromMe: Bool
    /// true cuando el mensaje fue persistido exitosamente en Firestore
    var isConfirmed: Bool

    // Inicializa un mensaje con UUID y timestamp automáticos si no se proveen
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
    /// UID del remitente (mensajes de texto/imagen/typing)
    let from: String?
    /// UID del destinatario
    let to: String?
    /// UID del peer que se conectó o desconectó
    let userId: String?
    let content: String?
    let mimeType: String?
    let timestamp: TimeInterval?
}
