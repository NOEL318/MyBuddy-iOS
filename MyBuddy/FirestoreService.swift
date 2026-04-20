import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Modelo de perfil de usuario

/// Perfil almacenado en Firestore bajo users/{uid}
struct UserProfile: Identifiable {
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

/// Servicio centralizado de acceso a Cloud Firestore
/// Estructura de datos:
///   users/{uid}                → perfil (username, description, phoneNumber, email, createdAt)
///   users/{uid}/messages/{id} → mensajes (type, sender, content, mimeType, timestamp)
///   usernames/{username}       → { uid } para garantizar unicidad
final class FirestoreService {

    static let shared = FirestoreService()

    private let db: Firestore

    private init() {
        db = Firestore.firestore()
        // La persistencia offline está habilitada por defecto en el SDK de iOS
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
            // Verifica que el nuevo username esté disponible
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

    // MARK: - Mensajes

    /// Persiste un mensaje en la subcolección del usuario y devuelve el ID del documento
    func saveMessage(_ message: Message, uid: String) async throws -> String {
        var msgData: [String: Any] = [
            "type":      message.type.rawValue,
            "sender":    message.sender.rawValue,
            "content":   message.content,
            "timestamp": message.timestamp
        ]
        if let mimeType = message.mimeType {
            msgData["mimeType"] = mimeType
        }

        let ref = try await db.collection("users").document(uid)
            .collection("messages").addDocument(data: msgData)
        return ref.documentID
    }

    /// Obtiene los últimos N mensajes ordenados por timestamp.
    /// Devuelve la lista y un cursor opaco para la siguiente página (paginación hacia atrás).
    func fetchMessages(uid: String, limit: Int = 50, before: Any? = nil) async throws -> ([Message], Any?) {
        var query: Query = db.collection("users").document(uid)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)

        if let cursor = before as? DocumentSnapshot {
            query = query.start(afterDocument: cursor)
        }

        let snapshot = try await query.getDocuments()
        let messages = parseMessages(from: snapshot)
        let lastDoc: Any? = snapshot.documents.last
        return (messages, lastDoc)
    }

    // MARK: - Directorio

    /// Obtiene la lista de todos los usuarios registrados
    func fetchAllUsers() async throws -> [UserProfile] {
        let snapshot = try await db.collection("users").getDocuments()
        return snapshot.documents.compactMap { userProfile(from: $0) }
    }

    // MARK: - Helpers privados

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

    /// Convierte un QuerySnapshot en un array de Message ordenado por timestamp ascendente
    private func parseMessages(from snapshot: QuerySnapshot) -> [Message] {
        snapshot.documents.compactMap { doc -> Message? in
            let data = doc.data()
            guard let typeStr    = data["type"]      as? String,
                  let type       = MessageType(rawValue: typeStr),
                  let senderStr  = data["sender"]    as? String,
                  let sender     = MessageSender(rawValue: senderStr),
                  let content    = data["content"]   as? String,
                  let timestamp  = data["timestamp"] as? Double
            else { return nil }

            return Message(
                id:          UUID(),
                firestoreId: doc.documentID,
                type:        type,
                sender:      sender,
                content:     content,
                mimeType:    data["mimeType"] as? String,
                timestamp:   timestamp,
                isConfirmed: true
            )
        }
        .sorted { $0.timestamp < $1.timestamp }
    }
}
