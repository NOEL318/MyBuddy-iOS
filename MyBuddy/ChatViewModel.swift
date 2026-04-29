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
    @Published var recipientIsTyping: Bool = false

    let recipient: UserProfile
    private let currentUid: String
    private let convId: String

    private let wsManager = WebSocketManager()
    private var messagesListener:  (any ListenerRegistration)? = nil
    private var typingHideTask:    Task<Void, Never>?          = nil
    private var lastTypingSent:    Date                        = .distantPast
    private var paginationCursor:  QueryDocumentSnapshot?      = nil
    private var listenerTimestamp: Double                      = 0

    init(recipient: UserProfile, currentUid: String) {
        // Configura los IDs de la conversación, los callbacks del WebSocket y carga el historial
        self.recipient  = recipient
        self.currentUid = currentUid
        self.convId     = FirestoreService.conversationId(myUid: currentUid, recipientUid: recipient.id)

        wsManager.onStateChange = { [weak self] state in
            self?.connectionState = state
        }
        wsManager.onTyping = { [weak self] in
            self?.showTypingIndicator()
        }

        Task { await loadInitialMessages() }
    }

    func connect() {
        // Abre la conexión WebSocket usada para el indicador de escritura
        wsManager.connect(userId: currentUid, recipientId: recipient.id)
    }

    func disconnect() {
        // Cancela el WebSocket, el listener de Firestore y el task del indicador
        wsManager.disconnect()
        messagesListener?.remove()
        messagesListener = nil
        typingHideTask?.cancel()
    }

    func sendText(_ text: String) {
        // Construye un mensaje de texto y lo persiste en Firestore
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

    func sendImage(_ image: UIImage) {
        // Redimensiona, comprime a menos de 700 KB y persiste la imagen en Firestore como base64
        let maxDimension: CGFloat = 800
        let scale = min(maxDimension / max(image.size.width, image.size.height), 1.0)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

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

    func userDidType() {
        // Envía un evento de "escribiendo" como máximo una vez cada 1.5 segundos
        let now = Date()
        guard now.timeIntervalSince(lastTypingSent) > 1.5 else { return }
        lastTypingSent = now
        wsManager.sendTyping()
    }

    func loadMoreMessages() async {
        // Carga la página anterior de mensajes y la antepone al historial actual
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

    private func loadInitialMessages() async {
        // Carga los últimos 50 mensajes y arranca el listener para los nuevos
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

    private func startRealtimeListener() {
        // Registra el listener de Firestore filtrando por timestamp para no recibir el historial
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

    private func applyIncomingMessages(_ incoming: [Message]) {
        // Inserta los mensajes nuevos descartando los que ya estén por firestoreId
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

    private func persist(_ msg: Message) async {
        // Escribe el mensaje en Firestore; el listener lo añadirá a la UI
        do {
            _ = try await FirestoreService.shared.saveMessage(msg, convId: convId)
        } catch {
            print("[Firestore] Error persistiendo mensaje: \(error)")
        }
    }

    private func showTypingIndicator() {
        // Muestra el indicador de escritura y lo oculta tras 3 segundos sin actividad
        recipientIsTyping = true
        typingHideTask?.cancel()
        typingHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            recipientIsTyping = false
        }
    }
}
