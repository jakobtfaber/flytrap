import SwiftUI

struct CaptureItemRow: View {
    let item: CaptureItem
    @State private var isHovered = false

    private let rowRadius: CGFloat = 10

    var body: some View {
        switch item {
        case .text:
            EmptyView()

        case .image(let filename, _):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.3))
                    )
                Text(filename)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.04))
            )
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)

        case .video(let filename, _):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.3))
                    )
                Text(filename)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.04))
            )
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)

        case .link(let url):
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue.opacity(0.8))
                    .frame(width: 28, height: 28)
                Text(url.host ?? url.absoluteString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.blue.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.04))
            )
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
    }
}
