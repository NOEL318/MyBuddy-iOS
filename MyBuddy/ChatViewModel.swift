import SwiftUI
import UIKit
import FirebaseAuth

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages:       [Message] = []
    @Published var connectionState: WebSocketManager.ConnectionState = .disconnected
    /// true mientras se carga una página anterior de mensajes
    @Published var isLoadingMore:  Bool = false
    /// false cuando Firestore ya devolvió todos los mensajes históricos
    @Published var hasMoreMessages: Bool = true

    private let wsManager = WebSocketManager()
    /// Cursor opaco para paginación; almacenado como Any? para no importar FirebaseFirestore aquí
    private var paginationCursor: Any? = nil

    // Configura los callbacks del WebSocketManager y carga los mensajes históricos de Firestore
    init() {
        wsManager.onStateChange = { [weak self] state in
            self?.connectionState = state
        }
        wsManager.onMessage = { [weak self] incoming in
            self?.handleIncoming(incoming)
        }
        Task { await loadInitialMessages() }
    }

    // Inicia la conexión WebSocket al servidor
    func connect() {
        wsManager.connect()
    }

    // Cierra la conexión WebSocket
    func disconnect() {
        wsManager.disconnect()
    }

    // Agrega el mensaje de texto localmente, lo envía por WebSocket y lo persiste en Firestore
    func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let msg = Message(type: .text, sender: .ios, content: trimmed)
        messages.append(msg)
        wsManager.sendText(trimmed)
        Task { await persistAndConfirm(msg) }
    }

    // Comprime la imagen a JPEG, la agrega localmente, la envía por WebSocket y la persiste en Firestore
    func sendImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let base64 = data.base64EncodedString()
        let msg = Message(type: .image, sender: .ios, content: base64, mimeType: "image/jpeg")
        messages.append(msg)
        wsManager.sendImage(base64: base64, mimeType: "image/jpeg")
        Task { await persistAndConfirm(msg) }
    }

    // Carga la página anterior de mensajes desde Firestore (llamado al hacer scroll al inicio)
    func loadMoreMessages() async {
        guard !isLoadingMore, hasMoreMessages,
              let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingMore = true
        do {
            let (older, cursor) = try await FirestoreService.shared.fetchMessages(
                uid: uid, limit: 50, before: paginationCursor
            )
            if older.isEmpty {
                hasMoreMessages = false
            } else {
                messages = older + messages
                if cursor != nil { paginationCursor = cursor }
                if older.count < 50 { hasMoreMessages = false }
            }
        } catch {
            print("[Firestore] Error cargando más mensajes: \(error)")
        }
        isLoadingMore = false
    }

    // Carga los 50 mensajes más recientes desde Firestore al inicializar el ViewModel
    private func loadInitialMessages() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let (loaded, cursor) = try await FirestoreService.shared.fetchMessages(uid: uid, limit: 50)
            messages        = loaded
            paginationCursor = cursor
            hasMoreMessages  = loaded.count == 50
        } catch {
            print("[Firestore] Error cargando mensajes iniciales: \(error)")
        }
    }

    // Convierte un mensaje entrante del servidor en un Message, lo agrega y lo persiste en Firestore
    private func handleIncoming(_ incoming: IncomingMessage) {
        guard incoming.type == .text || incoming.type == .image,
              let sender  = incoming.sender,
              let content = incoming.content else { return }

        let msg = Message(
            type:      incoming.type,
            sender:    sender,
            content:   content,
            mimeType:  incoming.mimeType,
            timestamp: incoming.timestamp ?? Date().timeIntervalSince1970 * 1000
        )
        messages.append(msg)
        Task { await persistAndConfirm(msg) }
    }

    // Persiste el mensaje en Firestore y actualiza su indicador de confirmación en la UI
    private func persistAndConfirm(_ msg: Message) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let docId = try await FirestoreService.shared.saveMessage(msg, uid: uid)
            // Actualiza el mensaje específico por su UUID local
            if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                messages[idx].firestoreId = docId
                messages[idx].isConfirmed = true
            }
        } catch {
            print("[Firestore] Error persistiendo mensaje: \(error)")
        }
    }
}
