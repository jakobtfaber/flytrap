import SwiftUI

struct ToastView: View {
    let message: String
    let isError: Bool

    var body: some View {
        Text(message)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(isError ? .white : Color(.systemGreen))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isError ? Color.red.opacity(0.25) : Color.green.opacity(0.1))
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
