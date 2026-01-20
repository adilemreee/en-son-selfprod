import SwiftUI
import CoreLocation

// MARK: - Live Partner Location Card
/// Premium card showing real-time partner location with radar-style visualization
struct LivePartnerLocationCard: View {
    @ObservedObject var presenceManager = PresenceManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var pulseAnimation = false
    @State private var radarRotation = 0.0
    @State private var refreshing = false
    @State private var showCountdown = true
    @State private var countdownTimer: Timer?
    @State private var secondsSinceUpdate: Int = 0
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            headerView
            
            // Main Content
            HStack(spacing: 16) {
                // Radar/Location Visual
                radarView
                
                // Info Section
                infoSection
            }
            
            // Bottom: Last update & refresh
            bottomBar
        }
        .padding(14)
        .background(cardBackground)
        .onAppear {
            startAnimations()
            startCountdownTimer()
        }
        .onDisappear {
            stopCountdownTimer()
        }
        .onChange(of: presenceManager.partnerLocationTimestamp) { _, _ in
            secondsSinceUpdate = 0
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(presenceManager.continuousTrackingEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                    .shadow(color: presenceManager.continuousTrackingEnabled ? .green : .clear, radius: 4)
                
                Text("Canlı Konum")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $presenceManager.continuousTrackingEnabled)
                .labelsHidden()
                .tint(themeManager.currentPalette.primaryColor)
                .scaleEffect(0.8)
        }
    }
    
    // MARK: - Radar View
    private var radarView: some View {
        ZStack {
            // Background circles
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        themeManager.currentPalette.primaryColor.opacity(0.15 - Double(i) * 0.05),
                        lineWidth: 1
                    )
                    .frame(width: CGFloat(30 + i * 12), height: CGFloat(30 + i * 12))
            }
            
            // Radar sweep (only when active)
            if presenceManager.continuousTrackingEnabled {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(
                        AngularGradient(
                            colors: [themeManager.currentPalette.primaryColor.opacity(0.6), .clear],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(90)
                        ),
                        lineWidth: 20
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(radarRotation))
            }
            
            // Center point (you)
            Circle()
                .fill(themeManager.currentPalette.primaryColor)
                .frame(width: 8, height: 8)
            
            // Partner dot (if location available)
            if let distance = presenceManager.distanceToPartner {
                partnerDot(distance: distance)
            }
            
            // Pulse ring (when near)
            if presenceManager.isNearPartner {
                Circle()
                    .stroke(Color.green.opacity(0.5), lineWidth: 2)
                    .frame(width: 50, height: 50)
                    .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                    .opacity(pulseAnimation ? 0 : 0.8)
            }
        }
        .frame(width: 60, height: 60)
    }
    
    private func partnerDot(distance: CLLocationDistance) -> some View {
        // Position based on distance (closer = more centered)
        let maxRadius: CGFloat = 22
        let normalizedDistance = min(distance / 5000, 1.0) // 5km = max radius
        let dotRadius = CGFloat(normalizedDistance) * maxRadius
        
        return Circle()
            .fill(presenceManager.isNearPartner ? Color.green : Color.red)
            .frame(width: 10, height: 10)
            .shadow(color: presenceManager.isNearPartner ? .green : .red, radius: 4)
            .offset(y: -dotRadius)
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Distance
            if let distance = presenceManager.distanceToPartner {
                Text(distance.formattedDistance)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: presenceManager.isNearPartner 
                                ? [.green, .mint] 
                                : [themeManager.currentPalette.primaryColor, themeManager.currentPalette.secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(presenceManager.isNearPartner ? "Yakınınızda! 💕" : "uzaklıkta")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text("—")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                
                Text("Konum bekleniyor")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Status indicator
            if presenceManager.continuousTrackingEnabled {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Aktif takip")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.green.opacity(0.8))
                }
            }
        }
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack {
            // Last update countdown
            if let timestamp = presenceManager.partnerLocationTimestamp {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(countdownText(from: timestamp))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                Text("Güncelleme bekleniyor")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Refresh button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    refreshing = true
                }
                presenceManager.forceRefresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        refreshing = false
                    }
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .rotationEffect(.degrees(refreshing ? 360 : 0))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(refreshing)
        }
    }
    
    // MARK: - Card Background
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            themeManager.currentPalette.primaryColor.opacity(0.4),
                            themeManager.currentPalette.secondaryColor.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
    
    // MARK: - Helpers
    private func countdownText(from timestamp: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(timestamp))
        if elapsed < 60 {
            return "\(elapsed) sn önce"
        } else if elapsed < 3600 {
            return "\(elapsed / 60) dk önce"
        } else {
            return "\(elapsed / 3600) sa önce"
        }
    }
    
    private func startAnimations() {
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
        
        // Radar rotation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            radarRotation = 360
        }
    }
    
    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            secondsSinceUpdate += 1
            // Force view refresh for countdown
            showCountdown.toggle()
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LivePartnerLocationCard()
    }
}
