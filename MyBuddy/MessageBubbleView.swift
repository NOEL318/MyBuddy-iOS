import SwiftUI

struct MessageBubbleView: View {
    let message: Message

    private var bubbleColor: Color {
        // Verde propio si lo envié yo, blanco si es del otro
        message.isFromMe ? Color.ownBubble : .white
    }

    var body: some View {
        // Compone la burbuja alineada a la derecha o izquierda según el remitente
        HStack {
            if message.isFromMe { Spacer(minLength: 60) }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 3) {
                ZStack(alignment: message.isFromMe ? .bottomTrailing : .bottomLeading) {
                    if message.type == .text {
                        textBubble
                    } else {
                        imageBubble
                    }
                }

                HStack(spacing: 4) {
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if message.isFromMe {
                        Image(systemName: message.isConfirmed ? "checkmark" : "clock")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(message.isConfirmed ? Color.actionGreen : .secondary)
                            .animation(.easeInOut(duration: 0.2), value: message.isConfirmed)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !message.isFromMe { Spacer(minLength: 60) }
        }
    }

    private var textBubble: some View {
        // Burbuja con el texto del mensaje y forma de cola
        Text(message.content)
            .font(.body)
            .foregroundColor(Color(red: 0.067, green: 0.11, blue: 0.13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleColor)
            .clipShape(BubbleShape(isFromMe: message.isFromMe))
            .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
    }

    private var imageBubble: some View {
        // Burbuja que decodifica la imagen base64 y muestra un placeholder si falla
        Group {
            if let image = decodedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 280)
                    .clipShape(BubbleShape(isFromMe: message.isFromMe))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .padding(20)
                    .foregroundStyle(.secondary)
                    .background(bubbleColor)
                    .clipShape(BubbleShape(isFromMe: message.isFromMe))
            }
        }
    }

    private var decodedImage: UIImage? {
        // Intenta decodificar el base64 del contenido en un UIImage
        guard let data = Data(base64Encoded: message.content) else { return nil }
        return UIImage(data: data)
    }
}

struct BubbleShape: Shape {

    let isFromMe: Bool

    func path(in rect: CGRect) -> Path {
        // Dibuja la burbuja con la cola en la esquina inferior según el remitente
        let radius:   CGFloat = 16
        let tailSize: CGFloat = 7

        var path = Path()

        if isFromMe {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                        radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - tailSize))
            path.addLine(to: CGPoint(x: rect.maxX + tailSize, y: rect.maxY - tailSize))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                        radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                        radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                        radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                        radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                        radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                        radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius + tailSize))
            path.addLine(to: CGPoint(x: rect.minX - tailSize, y: rect.minY + tailSize))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                        radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 8) {
        MessageBubbleView(message: Message(type: .text, sender: "uid_yo", recipient: "uid_otro", content: "Hola! Cómo estás?", isFromMe: true, isConfirmed: true))
        MessageBubbleView(message: Message(type: .text, sender: "uid_otro", recipient: "uid_yo", content: "Todo bien gracias, y tú?", isFromMe: false))
        MessageBubbleView(message: Message(type: .text, sender: "uid_yo", recipient: "uid_otro", content: "Enviando…", isFromMe: true, isConfirmed: false))
    }
    .padding()
    .background(Color.chatBg)
}
