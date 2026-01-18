import SwiftUI

// MARK: - Modern Status Dot
struct ModernStatusView: View {
    let isConnected: Bool
    
    var body: some View {
        Circle()
            .fill(isConnected ? Color.green : Color.red)
            .frame(width: 8, height: 8)
            .shadow(color: isConnected ? .green.opacity(0.8) : .red.opacity(0.8), radius: 4)
    }
}

// MARK: - Message Capsule
struct MessageCapsule: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(color)
                    .shadow(color: color.opacity(0.5), radius: 5)
            )
            .padding(.bottom, 5)
    }
}

// MARK: - Status Row
struct StatusRow: View {
    let title: String
    let icon: String
    let color: Color
    let date: Date?
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(date?.relativeString ?? "Henüz yok")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding()
        .background(Theme.subtleWhite)
        .cornerRadius(Theme.cornerRadius)
    }
}

// MARK: - Presence Row
struct PresenceRow: View {
    let lastReceived: Date?
    private let onlineWindow: TimeInterval = 5 * 60
    
    @State private var refreshTimer: Timer?
    @State private var refreshTrigger = false
    
    private var isOnline: Bool {
        let _ = refreshTrigger
        guard let last = lastReceived else { return false }
        return Date().timeIntervalSince(last) <= onlineWindow
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isOnline ? "dot.radiowaves.left.and.right" : "zzz")
                .foregroundColor(isOnline ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Eş Durumu")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(statusText)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding()
        .background(Theme.subtleWhite)
        .cornerRadius(Theme.cornerRadius)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }
    
    private var statusText: String {
        if isOnline { return "Çevrimiçi görünüyor" }
        guard let last = lastReceived else { return "Henüz kalp alınmadı" }
        return "Son kalp \(last.shortRelativeString)"
    }
    
    // MARK: - Timer (Memory Leak Fix)
    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            refreshTrigger.toggle()
        }
    }
    
    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Modern Button
struct ModernButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    Capsule()
                        .fill(color.opacity(0.2))
                    Capsule()
                        .stroke(color.opacity(0.8), lineWidth: 1)
                }
            )
            .shadow(color: color.opacity(0.3), radius: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
