import Foundation
import FirebaseFirestore
import FirebaseAuth

struct UserProfile: Identifiable, Hashable {
    let id: String
    var username: String
    var description: String
    var phoneNumber: String
    var email: String
    var createdAt: Date
}

enum AppError: LocalizedError {
    case usernameAlreadyTaken
    case profileNotFound

    var errorDescription: String? {
        // Devuelve el mensaje en español asociado a cada error
        switch self {
        case .usernameAlreadyTaken: return "Ese nombre de usuario ya está en uso."
        case .profileNotFound:      return "Perfil de usuario no encontrado."
        }
    }
}

final class FirestoreService {

    static let shared = FirestoreService()

    private let db: Firestore

    private init() {
        // Obtiene la instancia compartida de Firestore
        db = Firestore.firestore()
    }

    static func conversationId(myUid: String, recipientUid: String) -> String {
        // Genera un ID determinista para la conversación entre dos usuarios
        [myUid, recipientUid].sorted().joined(separator: "_")
    }

    func createProfile(_ profile: UserProfile) async throws {
        // Crea el perfil y reserva el username de forma atómica en un batch
        let usernameRef = db.collection("usernames").document(profile.username)
        let usernameDoc = try await usernameRef.getDocument()
        if usernameDoc.exists {
            throw AppError.usernameAlreadyTaken
        }

        let data: [String: Any] = [
            "username":    profile.username,
            "description": profile.description,
            "phoneNumber": profile.phoneNumber,
            "email":       profile.email,
            "createdAt":   Timestamp(date: profile.createdAt)
        ]

        let batch = db.batch()
        batch.setData(data, forDocument: db.collection("users").document(profile.id))
        batch.setData(["uid": profile.id], forDocument: usernameRef)
        try await batch.commit()
    }

    func fetchProfile(uid: String) async throws -> UserProfile? {
        // Recupera el perfil completo del usuario dado su UID
        let doc = try await db.collection("users").document(uid).getDocument()
        return userProfile(from: doc)
    }

    func updateProfile(_ profile: UserProfile, oldUsername: String?) async throws {
        // Actualiza los campos editables y reasigna la reserva si el username cambió
        let data: [String: Any] = [
            "username":    profile.username,
            "description": profile.description,
            "phoneNumber": profile.phoneNumber
        ]

        if let old = oldUsername, old != profile.username {
            let newRef = db.collection("usernames").document(profile.username)
            let newDoc = try await newRef.getDocument()
            if newDoc.exists {
                throw AppError.usernameAlreadyTaken
            }
            let batch = db.batch()
            batch.deleteDocument(db.collection("usernames").document(old))
            batch.setData(["uid": profile.id], forDocument: newRef)
            batch.updateData(data, forDocument: db.collection("users").document(profile.id))
            try await batch.commit()
        } else {
            try await db.collection("users").document(profile.id).updateData(data)
        }
    }

    func saveMessage(_ message: Message, convId: String) async throws -> String {
        // Persiste el mensaje en el path compartido de la conversación
        var msgData: [String: Any] = [
            "type":      message.type.rawValue,
            "sender":    message.sender,
            "recipient": message.recipient,
            "content":   message.content,
            "timestamp": message.timestamp
        ]
        if let mimeType = message.mimeType {
            msgData["mimeType"] = mimeType
        }

        let ref = try await db
            .collection("conversations").document(convId)
            .collection("messages").addDocument(data: msgData)
        return ref.documentID
    }

    func fetchMessages(
        convId: String,
        currentUid: String,
        limit: Int = 50,
        before: QueryDocumentSnapshot? = nil
    ) async throws -> ([Message], QueryDocumentSnapshot?) {
        // Devuelve la página de mensajes ordenada ascendente y el cursor para paginar atrás
        var query: Query = db
            .collection("conversations").document(convId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)

        if let cursor = before {
            query = query.start(afterDocument: cursor)
        }

        let snapshot = try await query.getDocuments()
        let messages = snapshot.documents
            .compactMap { parseMessage($0, currentUid: currentUid) }
            .sorted { $0.timestamp < $1.timestamp }

        return (messages, snapshot.documents.last)
    }

    func listenToNewMessages(
        convId: String,
        currentUid: String,
        afterTimestamp: Double,
        onChange: @escaping ([Message]) -> Void
    ) -> any ListenerRegistration {
        // Registra un listener en tiempo real para mensajes con timestamp posterior al dado
        let query: Query = db
            .collection("conversations").document(convId)
            .collection("messages")
            .order(by: "timestamp")
            .whereField("timestamp", isGreaterThan: afterTimestamp)

        return query.addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let msgs = snapshot.documentChanges
                .filter { $0.type == .added }
                .compactMap { [weak self] change in
                    self?.parseMessage(change.document, currentUid: currentUid)
                }
            if !msgs.isEmpty { onChange(msgs) }
        }
    }

    func fetchAllUsers() async throws -> [UserProfile] {
        // Devuelve la lista de todos los usuarios registrados en Firestore
        let snapshot = try await db.collection("users").getDocuments()
        return snapshot.documents.compactMap { userProfile(from: $0) }
    }

    private func userProfile(from doc: DocumentSnapshot) -> UserProfile? {
        // Convierte un documento de Firestore en un UserProfile o nil si falta el username
        guard doc.exists, let data = doc.data(),
              let username = data["username"] as? String else { return nil }
        return UserProfile(
            id:          doc.documentID,
            username:    username,
            description: data["description"] as? String ?? "",
            phoneNumber: data["phoneNumber"] as? String ?? "",
            email:       data["email"]       as? String ?? "",
            createdAt:   (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    func parseMessage(_ doc: DocumentSnapshot, currentUid: String) -> Message? {
        // Convierte un documento de Firestore en Message marcando si lo envió el usuario actual
        let data = doc.data() ?? [:]
        guard let typeStr   = data["type"]      as? String,
              let type      = MessageType(rawValue: typeStr),
              let sender    = data["sender"]    as? String,
              let recipient = data["recipient"] as? String,
              let content   = data["content"]   as? String,
              let timestamp = data["timestamp"] as? Double
        else { return nil }

        return Message(
            id:          UUID(),
            firestoreId: doc.documentID,
            type:        type,
            sender:      sender,
            recipient:   recipient,
            content:     content,
            mimeType:    data["mimeType"] as? String,
            timestamp:   timestamp,
            isFromMe:    sender == currentUid,
            isConfirmed: true
        )
    }
}
