# MyBuddy

App de mensajería para iOS construida con SwiftUI y Firebase. Permite chatear en tiempo real con otros usuarios registrados, enviar imágenes y ver cuándo el otro está escribiendo.

Es un proyecto personal con el que estoy trabajando la integración entre Firestore (para historial y persistencia) y un canal WebSocket (para señalización efímera tipo "typing" y presencia).

## Características

- Autenticación con email y contraseña usando Firebase Auth
- Conversaciones uno a uno sincronizadas en tiempo real desde Firestore
- Paginación de mensajes hacia atrás (50 por página)
- Envío de imágenes redimensionadas y comprimidas, embebidas como base64 dentro del documento
- Indicador de "escribiendo..." vía WebSocket
- Estado de presencia del peer (en línea / desconectado)
- Directorio con todos los usuarios registrados
- Perfil editable con username único garantizado a nivel de base de datos
- Splash con transición animada según el estado de autenticación
- UI con paleta inspirada en WhatsApp y animaciones nativas de SF Symbols

## Stack

- Swift 5 / SwiftUI
- Firebase Auth y Cloud Firestore
- URLSessionWebSocketTask para señalización efímera
- Combine para el estado reactivo
- iOS 17+ (uso de `symbolEffect`, `onChange` con dos parámetros, etc.)

## Arquitectura

La app sigue el patrón MVVM. Las vistas SwiftUI consumen ViewModels marcados como `@MainActor` que exponen estado vía `@Published`.

La capa de datos está concentrada en `FirestoreService`, un singleton que encapsula todas las lecturas y escrituras contra Cloud Firestore. `WebSocketManager` se usa exclusivamente para eventos efímeros que no tiene sentido persistir (typing y presencia).

`AuthViewModel` se inyecta como `@EnvironmentObject` y mantiene sincronizado el estado de Firebase Auth con la UI mediante `addStateDidChangeListener`.

## Estructura del proyecto

```
MyBuddy/
├── MyBuddyApp.swift          Punto de entrada y configuración de Firebase
├── RootView.swift            Decide entre splash, login o tab principal
├── AuthViewModel.swift       Observa el estado de Firebase Auth
├── LoginView.swift           Pantalla de inicio de sesión
├── RegisterView.swift        Pantalla de registro y creación de perfil
├── ChatsListView.swift       Lista de contactos para iniciar chat
├── DirectoryView.swift       Listado del directorio de usuarios
├── ProfileView.swift         Perfil propio editable
├── ContactDetailView.swift   Detalle de perfil de otro contacto
├── ContentView.swift         Pantalla de conversación
├── ChatViewModel.swift       Estado, paginación y listener de la conversación
├── MessageBubbleView.swift   Burbuja de mensaje (texto e imagen)
├── FirestoreService.swift    Acceso centralizado a Firestore
├── WebSocketManager.swift    Cliente WebSocket para typing y presencia
├── Message.swift             Modelo de mensaje y enums
├── AppColors.swift           Paleta de colores
├── ImagePicker.swift         Wrapper de UIImagePickerController
├── MyBuddyLogoView.swift     Logo reutilizable
└── Assets.xcassets/
```

## Modelo de datos en Firestore

```
users/{uid}
    username, description, phoneNumber, email, createdAt

usernames/{username}
    uid

conversations/{convId}/messages/{messageId}
    type, sender, recipient, content, mimeType, timestamp
```

`convId` se genera concatenando los UIDs de los dos participantes ordenados alfabéticamente y separados por `_`. Esto garantiza que los dos extremos de una conversación apunten siempre al mismo documento sin necesidad de búsqueda previa.

La colección `usernames` se usa como índice de unicidad: cada documento guarda el UID del dueño, por lo que crear un perfil implica un batch atómico que reserva el username y crea el documento del perfil al mismo tiempo.

## Reglas de seguridad

Las reglas (en `firestore.rules`) restringen la edición de perfiles a su dueño y permiten lectura a cualquier usuario autenticado. La colección `usernames` solo puede ser creada por el usuario que reclama el UID, lo cual evita que alguien reserve un nombre a nombre de otro. No se permite borrar ni actualizar perfiles desde el cliente.

## WebSocket

El servidor WebSocket no almacena nada: solo enruta eventos `identify`, `typing`, `peer_connected` y `peer_disconnected` entre los dos clientes de una conversación. La URL del servidor está definida en `WebSocketManager.swift` mediante la constante `SERVER_URL`.

## Configuración

1. Crear un proyecto en Firebase y habilitar Auth (email/password) y Cloud Firestore
2. Descargar `GoogleService-Info.plist` y agregarlo al target de la app
3. Aplicar las reglas de `firestore.rules` desde la consola o vía CLI
4. Crear los índices que solicite Firestore al ejecutar las queries por primera vez
5. Levantar un servidor WebSocket que reenvíe los eventos descritos arriba y actualizar `SERVER_URL`
6. Abrir el proyecto en Xcode y correr en simulador o dispositivo

## Requisitos

- Xcode 15 o superior
- iOS 17 o superior
- Cuenta de Firebase con plan Spark (suficiente para desarrollo)
