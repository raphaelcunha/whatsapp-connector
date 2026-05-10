import SwiftUI

struct ModernAppIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.95), Color.teal.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .white.opacity(0.9))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .frame(width: 64, height: 64)
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

struct ModernMenuBarIcon: View {
    var body: some View {
        Image(systemName: "bubble.left.and.bubble.right.fill")
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .accessibilityLabel("WhatsApp Connector")
            .help("WhatsApp Connector")
    }
}

#Preview {
    VStack(spacing: 24) {
        ModernAppIcon()
        ModernMenuBarIcon()
            .padding()
            .background(.bar)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .padding()
}
