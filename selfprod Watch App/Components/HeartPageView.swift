import SwiftUI
import WatchKit

// MARK: - Premium Heart Page View
struct HeartPageView: View {
    @ObservedObject var cloudManager = CloudKitManager.shared
    @ObservedObject var presenceManager = PresenceManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var showSentMessage = false
    @State private var receivedHeartbeat = false
    @State private var isSending = false
    @State private var appearAnimation = false
    @State private var sparkleActive = false
    
    var body: some View {
        ZStack {
            // Background
            themeManager.currentPalette.backgroundGradient
                .ignoresSafeArea()
            
            // Floating hearts background (received mode)
            FloatingHeartsView(isActive: $receivedHeartbeat)
            
            // Sparkle particles
            SparkleEffectView(isActive: $sparkleActive, palette: themeManager.currentPalette)
            
            VStack(spacing: 0) {
                // Premium header
                header
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : -10)
                
                Spacer()
                
                Spacer()
                ZStack {
                    // Orbit rings
                    OrbitRingsView(palette: themeManager.currentPalette, isActive: receivedHeartbeat)
                    
                    // Heart button
                    UltraPremiumHeartButton(
                        receivedHeartbeat: $receivedHeartbeat,
                        isSending: $isSending,
                        palette: themeManager.currentPalette
                    ) {
                        sendHeart()
                    }
                }
                .scaleEffect(appearAnimation ? 1 : 0.9)
                .opacity(appearAnimation ? 1 : 0)
                
                Spacer()
                
                // Bottom status
                bottomStatus
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)
                
                // Quick actions
                quickActions
                    .opacity(appearAnimation ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HeartbeatReceived"))) { _ in
            receivedHeartbeat = true
            sparkleActive = true
            WKInterfaceDevice.current().play(.notification)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                receivedHeartbeat = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                sparkleActive = false
            }
        }
    }
    
    // MARK: - Premium Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Aşkımmm💖")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.currentPalette.primaryColor, themeManager.currentPalette.secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Partner activity
                HStack(spacing: 4) {
                    Circle()
                        .fill(partnerActivityColor)
                        .frame(width: 5, height: 5)
                    
                    Text(partnerActivityText)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            connectionPill
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }
    

    
    private var connectionPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(cloudManager.isPaired ? Color.green : Color.red)
                .frame(width: 5, height: 5)
                .shadow(color: cloudManager.isPaired ? .green : .red, radius: 2)
            
            Image(systemName: cloudManager.isPaired ? "link" : "link.badge.plus")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(cloudManager.isPaired ? .white.opacity(0.8) : .red)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }
    
    // MARK: - Bottom Status
    private var bottomStatus: some View {
        Group {
            if showSentMessage {
                statusPill(text: "Gönderildi! 💖", color: .green, icon: "checkmark.circle.fill")
                    .transition(.scale.combined(with: .opacity))
            } else if receivedHeartbeat {
                statusPill(text: "Seni Düşünüyor 💛", color: .yellow, icon: "heart.fill")
                    .transition(.scale.combined(with: .opacity))
            } else if isSending {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                    Text("Gönderiliyor...")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                EmptyView()
            }
        }
        .frame(height: 25)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSentMessage)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: receivedHeartbeat)
    }
    
    private func statusPill(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Quick Actions
    private var quickActions: some View {
        HStack(spacing: 12) {
            if presenceManager.isEnabled && presenceManager.distanceToPartner != nil {
                HStack(spacing: 3) {
                    Image(systemName: presenceManager.isNearPartner ? "location.fill" : "location")
                        .font(.system(size: 8))
                        .foregroundColor(presenceManager.isNearPartner ? .cyan : .gray)
                    
                    Text(presenceManager.distanceToPartner?.formattedDistance ?? "")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
        .padding(.bottom, 6)
    }
    
    // MARK: - Helper Properties
    private var partnerActivityColor: Color {
        if let lastReceived = cloudManager.lastReceivedAt {
            let minutes = Date().timeIntervalSince(lastReceived) / 60
            if minutes < 5 { return .green }
            if minutes < 30 { return .yellow }
        }
        return .gray
    }
    
    private var partnerActivityText: String {
        if let lastReceived = cloudManager.lastReceivedAt {
            let minutes = Date().timeIntervalSince(lastReceived) / 60
            if minutes < 5 { return "Aktif" }
            if minutes < 30 { return "Yakın zamanda" }
            return lastReceived.abbreviatedRelativeString
        }
        return "Bekleniyor"
    }
    

    
    // MARK: - Actions
    private func sendHeart() {
        guard !isSending else { return }
        
        isSending = true
        sparkleActive = true
        WKInterfaceDevice.current().play(.click)
        
        cloudManager.sendHeartbeat { success in
            DispatchQueue.main.async {
                isSending = false
                sparkleActive = false
                
                if success {
                    showSentMessage = true
                    WKInterfaceDevice.current().play(.success)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSentMessage = false
                    }
                } else {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }
}

// MARK: - Sparkle Effect View
struct SparkleEffectView: View {
    @Binding var isActive: Bool
    let palette: ColorPalette
    
    @State private var sparkles: [Sparkle] = []
    
    struct Sparkle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var rotation: Double
        var opacity: Double
    }
    
    var body: some View {
        ZStack {
            ForEach(sparkles) { sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: sparkle.size, weight: .bold))
                    .foregroundColor(palette.primaryColor)
                    .rotationEffect(.degrees(sparkle.rotation))
                    .position(x: sparkle.x, y: sparkle.y)
                    .opacity(sparkle.opacity)
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                createSparkles()
            }
        }
    }
    
    private func createSparkles() {
        let centerX: CGFloat = 100
        let centerY: CGFloat = 110
        
        for i in 0..<12 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                let angle = Double(i) * 30.0
                let radius: CGFloat = 50
                let x = centerX + CGFloat(cos(angle * .pi / 180)) * radius + CGFloat.random(in: -20...20)
                let y = centerY + CGFloat(sin(angle * .pi / 180)) * radius + CGFloat.random(in: -20...20)
                
                var sparkle = Sparkle(
                    x: x,
                    y: y,
                    size: CGFloat.random(in: 8...14),
                    rotation: Double.random(in: 0...360),
                    opacity: 1.0
                )
                sparkles.append(sparkle)
                
                withAnimation(.easeOut(duration: 0.8)) {
                    if let index = sparkles.firstIndex(where: { $0.id == sparkle.id }) {
                        sparkles[index].opacity = 0
                        sparkles[index].y -= 30
                        sparkles[index].rotation += 180
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    sparkles.removeAll { $0.id == sparkle.id }
                }
            }
        }
    }
}

// MARK: - Orbit Rings View
struct OrbitRingsView: View {
    let palette: ColorPalette
    let isActive: Bool
    
    @State private var rotation1: Double = 0
    @State private var rotation2: Double = 0
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [palette.primaryColor.opacity(0.1), palette.secondaryColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .frame(width: 130, height: 130)
            
            // Mini hearts orbiting
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "heart.fill")
                    .font(.system(size: 6))
                    .foregroundColor(palette.primaryColor.opacity(0.4))
                    .offset(x: 65)
                    .rotationEffect(.degrees(rotation1 + Double(i * 120)))
            }
            
            // Inner ring
            Circle()
                .stroke(
                    palette.secondaryColor.opacity(0.08),
                    lineWidth: 1
                )
                .frame(width: 100, height: 100)
            
            ForEach(0..<2, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 4))
                    .foregroundColor(palette.secondaryColor.opacity(0.3))
                    .offset(x: 50)
                    .rotationEffect(.degrees(rotation2 + Double(i * 180)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                rotation1 = 360
            }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotation2 = -360
            }
        }
    }
}

// MARK: - Ultra Premium Heart Button
struct UltraPremiumHeartButton: View {
    @Binding var receivedHeartbeat: Bool
    @Binding var isSending: Bool
    let palette: ColorPalette
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var glowRadius: CGFloat = 12
    @State private var glowOpacity: Double = 0.5
    @State private var innerShine: Double = 0.4
    @State private var triggerRipple = false
    @State private var heartbeatTimer: Timer?
    
    private let baseSize: CGFloat = 70
    
    var body: some View {
        ZStack {
            // Ripple
            HeartRippleEffectView(
                triggerBeat: $triggerRipple,
                baseSize: baseSize,
                isReceivedMode: receivedHeartbeat
            )
            
            // Outer glow
            Image(systemName: "heart.fill")
                .font(.system(size: baseSize))
                .foregroundColor(receivedHeartbeat ? .orange : palette.primaryColor)
                .blur(radius: glowRadius)
                .opacity(glowOpacity)
                .scaleEffect(scale * 1.2)
            
            // Main button
            Button(action: {
                triggerTap()
                onTap()
            }) {
                ZStack {
                    // Body
                    Image(systemName: "heart.fill")
                        .font(.system(size: baseSize))
                        .foregroundStyle(
                            receivedHeartbeat ?
                                LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom) :
                                LinearGradient(colors: [palette.primaryColor, palette.secondaryColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(
                            color: receivedHeartbeat ? .orange.opacity(0.6) : palette.primaryColor.opacity(0.5),
                            radius: 15
                        )
                    
                    // Shine
                    Image(systemName: "heart.fill")
                        .font(.system(size: baseSize))
                        .foregroundStyle(
                            LinearGradient(colors: [.white.opacity(innerShine), .clear], startPoint: .top, endPoint: .center)
                        )
                        .mask(
                            Image(systemName: "heart.fill")
                                .font(.system(size: baseSize * 0.8))
                                .offset(y: 6)
                        )
                        .blendMode(.overlay)
                    
                    // Sending
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    }
                }
                .scaleEffect(scale)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSending)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onChange(of: receivedHeartbeat) { _, v in if v { excitedBeat() } }
    }
    
    private func startTimer() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.3, repeats: true) { _ in
            if !receivedHeartbeat && !isSending { idleBeat() }
        }
    }
    
    private func stopTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func idleBeat() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.4)) {
            scale = 1.12
            innerShine = 0.7
            glowRadius = 20
            glowOpacity = 0.7
        }
        triggerRipple.toggle()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                scale = 1.0
                innerShine = 0.4
                glowRadius = 12
                glowOpacity = 0.5
            }
        }
    }
    
    private func triggerTap() {
        withAnimation(.easeIn(duration: 0.04)) { scale = 0.85 }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            triggerRipple.toggle()
            withAnimation(.spring(response: 0.18, dampingFraction: 0.3)) {
                scale = 1.45
                innerShine = 1.0
                glowRadius = 35
                glowOpacity = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.0
                innerShine = 0.4
                glowRadius = 12
                glowOpacity = 0.5
            }
        }
    }
    
    private func excitedBeat() {
        for i in 0..<7 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                triggerRipple.toggle()
                withAnimation(.spring(response: 0.1, dampingFraction: 0.35)) {
                    scale = 1.4
                    glowRadius = 40
                    glowOpacity = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    withAnimation(.easeOut(duration: 0.06)) {
                        scale = 1.0
                        glowRadius = 18
                        glowOpacity = 0.6
                    }
                }
            }
        }
    }
}
