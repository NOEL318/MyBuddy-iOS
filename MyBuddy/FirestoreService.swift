import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Modelo de perfil de usuario

/// Perfil almacenado en Firestore bajo users/{uid}
struct UserProfile: Identifiable, Hashable {
    let id: String          // UID de Firebase Auth
    var username: String
    var description: String
    var phoneNumber: String
    var email: String
    var createdAt: Date
}

// MARK: - Errores de la aplicación

/// Errores internos de MyBuddy con mensajes en español
enum AppError: LocalizedError {
    case usernameAlreadyTaken
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .usernameAlreadyTaken: return "Ese nombre de usuario ya está en uso."
        case .profileNotFound:      return "Perfil de usuario no encontrado."
        }
    }
}

// MARK: - FirestoreService

/// Servicio centralizado de acceso a Cloud Firestore.
/// Estructura de datos:
///   users/{uid}                              → perfil
///   conversations/{convId}/messages/{id}     → mensajes compartidos (convId = uid1_uid2 ordenados)
///   usernames/{username}                     → { uid } para garantizar unicidad
final class FirestoreService {

    static let shared = FirestoreService()

    private let db: Firestore

    private init() {
        db = Firestore.firestore()
    }

    // MARK: - Conversación: ID compartido

    /// Genera el ID de conversación deterministico entre dos usuarios.
    /// El resultado es el mismo sin importar el orden de los UIDs.
    static func conversationId(myUid: String, recipientUid: String) -> String {
        [myUid, recipientUid].sorted().joined(separator: "_")
    }

    // MARK: - Perfil de usuario

    /// Crea el perfil en Firestore y reserva el username en un batch atómico
    func createProfile(_ profile: UserProfile) async throws {
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

    /// Recupera el perfil completo del usuario dado su UID
    func fetchProfile(uid: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(uid).getDocument()
        return userProfile(from: doc)
    }

    /// Actualiza los campos editables; si el username cambió, reasigna la clave de unicidad
    func updateProfile(_ profile: UserProfile, oldUsername: String?) async throws {
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

    // MARK: - Mensajes de conversación

    /// Persiste un mensaje en el path compartido de la conversación
    func saveMessage(_ message: Message, convId: String) async throws -> String {
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

    /// Obtiene los últimos N mensajes de la conversación (paginación hacia atrás).
    /// Retorna: (mensajes ordenados asc, cursor para página anterior)
    func fetchMessages(
        convId: String,
        currentUid: String,
        limit: Int = 50,
        before: QueryDocumentSnapshot? = nil
    ) async throws -> ([Message], QueryDocumentSnapshot?) {
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

        // Orden descendente: .last = documento más antiguo → cursor para "cargar más"
        return (messages, snapshot.documents.last)
    }

    /// Registra un listener en tiempo real para mensajes NUEVOS cuyo timestamp sea
    /// estrictamente mayor que `afterTimestamp`. Los duplicados se descartan en la capa
    /// de ViewModel mediante firestoreId.
    func listenToNewMessages(
        convId: String,
        currentUid: String,
        afterTimestamp: Double,
        onChange: @escaping ([Message]) -> Void
    ) -> any ListenerRegistration {
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

    // MARK: - Directorio

    /// Obtiene la lista de todos los usuarios registrados
    func fetchAllUsers() async throws -> [UserProfile] {
        let snapshot = try await db.collection("users").getDocuments()
        return snapshot.documents.compactMap { userProfile(from: $0) }
    }

    // MARK: - Helpers

    private func userProfile(from doc: DocumentSnapshot) -> UserProfile? {
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

    /// Convierte un documento de Firestore en un Message.
    /// `currentUid` se usa para determinar si el mensaje fue enviado por el usuario actual.
    func parseMessage(_ doc: DocumentSnapshot, currentUid: String) -> Message? {
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
