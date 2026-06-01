import SwiftUI

struct AlertOverlayView: View {

    let title: String
    let body: String
    let memeIndex: Int
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var shake = false

    private let gradients: [[Color]] = [
        [Color(red:0.1, green:0.1, blue:0.18), Color(red:0.09, green:0.13, blue:0.24)],
        [Color(red:0.06, green:0.20, blue:0.38), Color(red:0.33, green:0.20, blue:0.51)],
        [Color(red:0.11, green:0.26, blue:0.20), Color(red:0.03, green:0.11, blue:0.08)],
        [Color(red:0.48, green:0.18, blue:0.00), Color(red:0.24, green:0.08, blue:0.00)],
        [Color(red:0.18, green:0.00, blue:0.78), Color(red:0.42, green:0.00, blue:0.78)],
        [Color(red:0.22, green:0.02, blue:0.09), Color(red:0.42, green:0.02, blue:0.06)],
    ]

    private var gradient: [Color] {
        gradients[memeIndex % gradients.count]
    }

    var body: some View {
        ZStack {
            // Dark blurred background
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Card
            VStack(spacing: 0) {
                // Meme image area
                ZStack {
                    LinearGradient(
                        colors: gradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    memeImageView
                }
                .frame(width: 440, height: 280)

                // Text area
                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(body)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button(action: onDismiss) {
                        Text("OK, I'll sit up 🙄")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(width: 440)
                .padding(.vertical, 24)
                .background(Color(red: 0.08, green: 0.08, blue: 0.12))
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 20)
            .scaleEffect(appeared ? 1.0 : 0.6)
            .opacity(appeared ? 1.0 : 0.0)
            .offset(x: shake ? -10 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.65), value: appeared)
            .animation(
                .easeInOut(duration: 0.05).repeatCount(6, autoreverses: true),
                value: shake
            )
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shake = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    shake = false
                }
            }
        }
    }

    @ViewBuilder
    private var memeImageView: some View {
        if let url = memeURL(),
           let cgImage = NSImage(contentsOf: url).flatMap({ img -> CGImage? in
               var rect = CGRect(origin: .zero, size: img.size)
               return img.cgImage(forProposedRect: &rect, context: nil, hints: nil)
           }) {
            Image(decorative: cgImage, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: 440, height: 280)
                .clipped()
        } else {
            // Fallback: big emoji text
            let emojis = ["🍌","💀","🗼","🦒","🤕","🐢","😱","🔥","💥","🧘"]
            Text(emojis[memeIndex % emojis.count])
                .font(.system(size: 100))
        }
    }

    private func memeURL() -> URL? {
        let name = "meme\(memeIndex + 1)"
        return Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Memes")
            ?? Bundle.main.url(forResource: name, withExtension: "png")
    }
}
