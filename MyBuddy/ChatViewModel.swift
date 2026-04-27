import SwiftUI
import UIKit
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages:          [Message] = []
    @Published var connectionState:   WebSocketManager.ConnectionState = .disconnected
    @Published var isLoadingMore:     Bool = false
    @Published var hasMoreMessages:   Bool = false
    /// true cuando el destinatario está escribiendo
    @Published var recipientIsTyping: Bool = false

    let recipient: UserProfile
    private let currentUid: String
    private let convId: String

    private let wsManager = WebSocketManager()
    private var messagesListener:  (any ListenerRegistration)? = nil
    private var typingHideTask:    Task<Void, Never>?          = nil
    private var lastTypingSent:    Date                        = .distantPast
    private var paginationCursor:  QueryDocumentSnapshot?      = nil
    /// Timestamp del mensaje más reciente ya cargado; el listener sólo entrega mensajes posteriores
    private var listenerTimestamp: Double                      = 0

    init(recipient: UserProfile, currentUid: String) {
        self.recipient  = recipient
        self.currentUid = currentUid
        self.convId     = FirestoreService.conversationId(myUid: currentUid, recipientUid: recipient.id)

        wsManager.onStateChange = { [weak self] state in
            self?.connectionState = state
        }
        // Solo usamos WebSocket para el indicador de escritura
        wsManager.onTyping = { [weak self] in
            self?.showTypingIndicator()
        }

        Task { await loadInitialMessages() }
    }

    // MARK: - Conexión

    /// Inicia la conexión WebSocket (para typing) y el listener de Firestore (para mensajes)
    func connect() {
        wsManager.connect(userId: currentUid, recipientId: recipient.id)
    }

    /// Cancela la conexión WebSocket y el listener de Firestore
    func disconnect() {
        wsManager.disconnect()
        messagesListener?.remove()
        messagesListener = nil
        typingHideTask?.cancel()
    }

    // MARK: - Envío de mensajes

    /// Persiste el mensaje en Firestore; el listener lo añade a la UI automáticamente
    func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let msg = Message(
            type:      .text,
            sender:    currentUid,
            recipient: recipient.id,
            content:   trimmed,
            isFromMe:  true
        )
        Task { await persist(msg) }
    }

    /// Redimensiona, comprime y persiste la imagen en Firestore.
    /// Firestore tiene un límite de 1 MB por documento; el base64 añade ~33% de overhead,
    /// por lo que el JPEG bruto debe quedar bajo 700 KB para garantizar la escritura.
    func sendImage(_ image: UIImage) {
        // 1. Redimensionar al lado más largo en 800 px como máximo
        let maxDimension: CGFloat = 800
        let scale = min(maxDimension / max(image.size.width, image.size.height), 1.0)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // 2. Comprimir con calidad decreciente hasta caber en 700 KB
        var quality: CGFloat = 0.65
        var data: Data?
        repeat {
            data = resized.jpegData(compressionQuality: quality)
            quality -= 0.15
        } while (data?.count ?? 0) > 700_000 && quality > 0.0

        guard let finalData = data, finalData.count <= 700_000 else { return }

        let base64 = finalData.base64EncodedString()
        let msg = Message(
            type:      .image,
            sender:    currentUid,
            recipient: recipient.id,
            content:   base64,
            mimeType:  "image/jpeg",
            isFromMe:  true
        )
        Task { await persist(msg) }
    }

    // MARK: - Typing indicator

    /// Envía un evento de "escribiendo" via WebSocket (máximo 1 vez cada 1.5 s)
    func userDidType() {
        let now = Date()
        guard now.timeIntervalSince(lastTypingSent) > 1.5 else { return }
        lastTypingSent = now
        wsManager.sendTyping()
    }

    // MARK: - Paginación

    /// Carga la página anterior de mensajes (llamado al hacer scroll al inicio)
    func loadMoreMessages() async {
        guard !isLoadingMore, hasMoreMessages else { return }
        isLoadingMore = true
        do {
            let (older, olderCursor) = try await FirestoreService.shared.fetchMessages(
                convId: convId, currentUid: currentUid, limit: 50, before: paginationCursor
            )
            if older.isEmpty {
                hasMoreMessages = false
            } else {
                let existingIds = Set(messages.compactMap { $0.firestoreId })
                let dedupedOlder = older.filter { msg in
                    guard let fid = msg.firestoreId else { return true }
                    return !existingIds.contains(fid)
                }
                messages = dedupedOlder + messages
                if let c = olderCursor { paginationCursor = c }
                if older.count < 50 { hasMoreMessages = false }
            }
        } catch {
            print("[Firestore] Error cargando más mensajes: \(error)")
        }
        isLoadingMore = false
    }

    // MARK: - Privados

    /// Carga el historial inicial y arranca el listener para mensajes nuevos en tiempo real
    private func loadInitialMessages() async {
        do {
            let (loaded, pagCursor) = try await FirestoreService.shared.fetchMessages(
                convId: convId, currentUid: currentUid, limit: 50
            )
            messages          = loaded
            paginationCursor  = pagCursor
            listenerTimestamp = loaded.last?.timestamp ?? 0
            hasMoreMessages   = loaded.count == 50
            startRealtimeListener()
        } catch {
            print("[Firestore] Error cargando mensajes iniciales: \(error)")
            startRealtimeListener()
        }
    }

    /// Registra el listener de Firestore filtrando por timestamp para no re-entregar historial
    private func startRealtimeListener() {
        messagesListener = FirestoreService.shared.listenToNewMessages(
            convId:         convId,
            currentUid:     currentUid,
            afterTimestamp: listenerTimestamp
        ) { [weak self] newMsgs in
            Task { @MainActor [weak self] in
                self?.applyIncomingMessages(newMsgs)
            }
        }
    }

    /// Integra los mensajes recibidos del listener, evitando duplicados por firestoreId
    private func applyIncomingMessages(_ incoming: [Message]) {
        var changed = false
        for msg in incoming {
            guard let fid = msg.firestoreId,
                  !messages.contains(where: { $0.firestoreId == fid }) else { continue }
            messages.append(msg)
            changed = true
        }
        if changed {
            messages.sort { $0.timestamp < $1.timestamp }
        }
    }

    /// Persiste el mensaje en Firestore; la confirmación llega via el listener
    private func persist(_ msg: Message) async {
        do {
            _ = try await FirestoreService.shared.saveMessage(msg, convId: convId)
        } catch {
            print("[Firestore] Error persistiendo mensaje: \(error)")
        }
    }

    /// Muestra el indicador de escritura del destinatario y lo oculta tras 3 segundos de inactividad
    private func showTypingIndicator() {
        recipientIsTyping = true
        typingHideTask?.cancel()
        typingHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            recipientIsTyping = false
        }
    }
}
