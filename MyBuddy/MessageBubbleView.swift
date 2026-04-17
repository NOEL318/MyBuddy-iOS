import SwiftUI

struct MessageBubbleView: View {
    let message: Message

    private var bubbleColor: Color {
        message.isFromMe ? Color(red: 0.85, green: 0.99, blue: 0.82) : .white
    }

    // Compone la burbuja alineada a la derecha si es enviada, a la izquierda si es recibida
    var body: some View {
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

                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            if !message.isFromMe { Spacer(minLength: 60) }
        }
    }

    // Muestra el texto del mensaje dentro de una burbuja con forma de cola
    private var textBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(Color(red: 0.067, green: 0.11, blue: 0.13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleColor)
            .clipShape(BubbleShape(isFromMe: message.isFromMe))
            .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
    }

    // Decodifica el base64 del mensaje y muestra la imagen dentro de una burbuja
    private var imageBubble: some View {
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

    // Intenta decodificar el contenido base64 del mensaje en un UIImage
    private var decodedImage: UIImage? {
        guard let data = Data(base64Encoded: message.content) else { return nil }
        return UIImage(data: data)
    }
}

struct BubbleShape: Shape {

    let isFromMe: Bool

    // Dibuja la forma de la burbuja con una cola en la esquina inferior según el remitente
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
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
        MessageBubbleView(message: Message(type: .text, sender: .ios, content: "Hola! Cómo estás?"))
        MessageBubbleView(message: Message(type: .text, sender: .web, content: "Todo bien gracias, y tú?"))
        MessageBubbleView(message: Message(type: .text, sender: .ios, content: "Excelente! Mira esta foto"))
    }
    .padding()
    .background(Color(red: 0.94, green: 0.92, blue: 0.87))
}
