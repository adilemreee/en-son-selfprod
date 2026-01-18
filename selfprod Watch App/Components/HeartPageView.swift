import SwiftUI
import WatchKit
import CloudKit

// MARK: - Ultimate Heart Page (Sayfa yapısı korundu)
struct HeartPageView: View {
    @ObservedObject var cloudManager = CloudKitManager.shared
    @ObservedObject var presenceManager = PresenceManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var showSuccess = false
    @State private var receivedBeat = false
    @State private var isSending = false
    @State private var appeared = false
    @State private var explosionTrigger = false
    
    var body: some View {
        ZStack {
            // Living background
            LivingBackground(palette: themeManager.currentPalette, intensity: receivedBeat ? 1.0 : 0.5)
            
            // Particle field
            ParticleFieldView(isExploding: $explosionTrigger, palette: themeManager.currentPalette)
            
            // Floating ambient hearts
            AmbientHeartsView()
            
            VStack(spacing: 0) {
                // Glass header
                glassHeader
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)
                
                Spacer()
                
                // THE HEART - Klasik animasyon
                ZStack {
                    // Aura layers
                    AuraView(palette: themeManager.currentPalette, isActive: !isSending)
                    
                    // Klasik Pulsing Heart (Referanstan)
                    ClassicPulsingHeartView(
                        receivedHeartbeat: $receivedBeat,
                        palette: themeManager.currentPalette
                    ) {
                        explosionTrigger.toggle()
                        sendLove()
                    }
                }
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)
                
                Spacer()
                
                // Status display
                statusDisplay
                    .opacity(appeared ? 1 : 0)
            }
            
            // Celebrations
            if showSuccess {
                SuccessCelebration()
            }
            if receivedBeat {
                LoveCelebration()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                appeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HeartbeatReceived"))) { _ in
            triggerReceived()
        }
    }
    
    // MARK: - Glass Header (Aynı kaldı)
    private var glassHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Aşkımmm💖")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, themeManager.currentPalette.primaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: themeManager.currentPalette.primaryColor.opacity(0.5), radius: 8)
                
                HStack(spacing: 4) {
                    PulsingDot(color: statusColor)
                    Text(statusText)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            if let dist = presenceManager.distanceToPartner {
                HStack(spacing: 3) {
                    Image(systemName: presenceManager.isNearPartner ? "heart.fill" : "location")
                        .font(.system(size: 9))
                        .foregroundColor(presenceManager.isNearPartner ? .pink : .cyan)
                    Text(dist.formattedDistance)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }
    
    private var statusColor: Color {
        guard let last = cloudManager.lastReceivedAt else { return .gray }
        let mins = Date().timeIntervalSince(last) / 60
        return mins < 5 ? .green : (mins < 30 ? .yellow : .gray)
    }
    
    private var statusText: String {
        guard let last = cloudManager.lastReceivedAt else { return "Bekliyor" }
        let mins = Date().timeIntervalSince(last) / 60
        return mins < 5 ? "Şu an aktif" : (mins < 30 ? "Yakın zamanda" : last.abbreviatedRelativeString)
    }
    
    // MARK: - Status Display (Aynı kaldı)
    private var statusDisplay: some View {
        Group {
            if isSending {
                SendingStatus(palette: themeManager.currentPalette)
            } else if showSuccess {
                SuccessStatus()
            } else if receivedBeat {
                ReceivedStatus()
            } else {
                IdleStatus(lastHeart: cloudManager.lastReceivedAt)
            }
        }
        .frame(height: 32)
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
    
    // MARK: - Actions
    private func sendLove() {
        guard !isSending else { return }
        isSending = true
        WKInterfaceDevice.current().play(.click)
        
        cloudManager.sendHeartbeat { ok in
            DispatchQueue.main.async {
                isSending = false
                if ok {
                    showSuccess = true
                    WKInterfaceDevice.current().play(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSuccess = false }
                } else {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }
    
    private func triggerReceived() {
        receivedBeat = true
        explosionTrigger.toggle()
        WKInterfaceDevice.current().play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { receivedBeat = false }
    }
}

// MARK: - Klasik Pulsing Heart View (Referanstan)
struct ClassicPulsingHeartView: View {
    @Binding var receivedHeartbeat: Bool
    let palette: ColorPalette
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var innerLightIntensity: Double = 0.5
    @State private var glowRadius: CGFloat = 10
    @State private var glowOpacity: Double = 0.6
    @State private var triggerRippleSignal = false
    @State private var heartbeatTimer: Timer?
    
    let baseFontSize: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Ripple Effect
            HeartRippleEffectView(
                triggerBeat: $triggerRippleSignal,
                baseSize: baseFontSize,
                isReceivedMode: receivedHeartbeat
            )
            
            // Glow
            Image(systemName: "heart.fill")
                .font(.system(size: baseFontSize))
                .foregroundStyle(receivedHeartbeat ? Color.orange : palette.primaryColor)
                .blur(radius: glowRadius)
                .opacity(glowOpacity)
                .scaleEffect(scale * 1.1)
            
            // Button
            Button(action: {
                triggerManualBeat()
                onTap()
            }) {
                ZStack {
                    // Neon body
                    Image(systemName: "heart.fill")
                        .font(.system(size: baseFontSize))
                        .foregroundStyle(
                            LinearGradient(
                                colors: receivedHeartbeat ?
                                [.yellow, .orange, .red] :
                                [palette.primaryColor, palette.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: receivedHeartbeat ? .orange.opacity(0.8) : palette.primaryColor.opacity(0.7), radius: 8)
                    
                    // Inner shine
                    Image(systemName: "heart.fill")
                        .font(.system(size: baseFontSize))
                        .foregroundStyle(
                            LinearGradient(colors: [.white.opacity(innerLightIntensity), .clear], startPoint: .top, endPoint: .bottom)
                        )
                        .mask(
                            Image(systemName: "heart.fill")
                                .font(.system(size: baseFontSize * 0.9))
                                .offset(y: 3)
                        )
                        .blendMode(.overlay)
                }
                .scaleEffect(scale)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onChange(of: receivedHeartbeat) { _, v in if v { rapidExcitement() } }
    }
    
    private func startTimer() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !receivedHeartbeat { modernBeat() }
        }
    }
    
    private func stopTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func modernBeat() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
            scale = 1.2; innerLightIntensity = 0.9; glowRadius = 20; glowOpacity = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { triggerRippleSignal.toggle() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0; innerLightIntensity = 0.5; glowRadius = 10; glowOpacity = 0.6
            }
        }
    }
    
    private func triggerManualBeat() {
        withAnimation(.easeIn(duration: 0.05)) { scale = 0.9 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            triggerRippleSignal.toggle()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
                scale = 1.35; innerLightIntensity = 1.0; glowRadius = 25; glowOpacity = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.5)) {
                scale = 1.0; innerLightIntensity = 0.5; glowRadius = 10; glowOpacity = 0.6
            }
        }
    }
    
    private func rapidExcitement() {
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.18) {
                triggerRippleSignal.toggle()
                withAnimation(.spring(response: 0.12, dampingFraction: 0.4)) {
                    scale = 1.3; glowRadius = 30; glowOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                    withAnimation(.easeOut(duration: 0.08)) {
                        scale = 1.0; glowRadius = 15; glowOpacity = 0.7
                    }
                }
            }
        }
    }
}

// MARK: - Living Background (Aynı)
struct LivingBackground: View {
    let palette: ColorPalette
    let intensity: Double
    @State private var animate = false
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, palette.primaryColor.opacity(0.15 * intensity), palette.secondaryColor.opacity(0.1 * intensity), .black], startPoint: animate ? .topLeading : .bottomLeading, endPoint: animate ? .bottomTrailing : .topTrailing)
            Circle().fill(RadialGradient(colors: [palette.primaryColor.opacity(0.3 * intensity), palette.secondaryColor.opacity(0.1 * intensity), .clear], center: .center, startRadius: 0, endRadius: 80)).frame(width: 160, height: 160).scaleEffect(animate ? 1.1 : 0.9).offset(x: animate ? 10 : -10, y: animate ? -5 : 5).blur(radius: 30)
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { animate = true } }
    }
}

// MARK: - Aura View (Aynı)
struct AuraView: View {
    let palette: ColorPalette
    let isActive: Bool
    @State private var scale1: CGFloat = 0.85
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Circle().stroke(AngularGradient(colors: [palette.primaryColor.opacity(0.3), .clear, palette.secondaryColor.opacity(0.2), .clear], center: .center), lineWidth: 2).frame(width: 140, height: 140).rotationEffect(.degrees(rotation))
            ForEach(0..<3, id: \.self) { i in
                Circle().stroke(palette.primaryColor.opacity(Double(3-i) * 0.1), lineWidth: CGFloat(3-i)).frame(width: CGFloat(100 + i * 20), height: CGFloat(100 + i * 20)).scaleEffect(scale1)
            }
        }
        .onAppear {
            guard isActive else { return }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { rotation = 360 }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { scale1 = 1.0 }
        }
    }
}

// MARK: - Particle Field (Aynı)
struct ParticleFieldView: View {
    @Binding var isExploding: Bool
    let palette: ColorPalette
    @State private var particles: [Particle] = []
    struct Particle: Identifiable { let id = UUID(); var x, y: CGFloat; var size: CGFloat; var rotation: Double; var opacity: Double; var color: Color; var symbol: String }
    
    var body: some View {
        ZStack { ForEach(particles) { p in Image(systemName: p.symbol).font(.system(size: p.size)).foregroundColor(p.color).rotationEffect(.degrees(p.rotation)).position(x: p.x, y: p.y).opacity(p.opacity) } }
        .onChange(of: isExploding) { _, _ in explode() }
    }
    
    private func explode() {
        let symbols = ["heart.fill", "star.fill", "sparkle", "circle.fill"]
        let colors = [palette.primaryColor, palette.secondaryColor, .pink, .orange, .yellow]
        for i in 0..<30 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.015) {
                let angle = Double.random(in: 0...360) * .pi / 180
                var p = Particle(x: 100 + CGFloat(cos(angle)) * 10, y: 110 + CGFloat(sin(angle)) * 10, size: CGFloat.random(in: 6...14), rotation: Double.random(in: 0...360), opacity: 1, color: colors.randomElement()!, symbol: symbols.randomElement()!)
                particles.append(p)
                let targetDist: CGFloat = CGFloat.random(in: 60...120)
                withAnimation(.easeOut(duration: Double.random(in: 0.8...1.4))) { if let idx = particles.firstIndex(where: { $0.id == p.id }) { particles[idx].x = 100 + CGFloat(cos(angle)) * targetDist; particles[idx].y = 110 + CGFloat(sin(angle)) * targetDist; particles[idx].rotation += Double.random(in: 180...540); particles[idx].opacity = 0; particles[idx].size = 0 } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { particles.removeAll { $0.id == p.id } }
            }
        }
    }
}

// MARK: - Ambient Hearts (Aynı)
struct AmbientHeartsView: View {
    @State private var hearts: [AH] = []
    struct AH: Identifiable { let id = UUID(); var x, y: CGFloat; var size: CGFloat; var opacity: Double }
    var body: some View {
        ZStack { ForEach(hearts) { h in Image(systemName: "heart.fill").font(.system(size: h.size)).foregroundColor(.pink.opacity(0.3)).position(x: h.x, y: h.y).opacity(h.opacity).blur(radius: 1) } }
        .onAppear { Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in let h = AH(x: CGFloat.random(in: 20...180), y: 220, size: CGFloat.random(in: 4...10), opacity: 0.5); hearts.append(h); withAnimation(.easeOut(duration: 8)) { if let idx = hearts.firstIndex(where: { $0.id == h.id }) { hearts[idx].y = -30; hearts[idx].opacity = 0 } }; DispatchQueue.main.asyncAfter(deadline: .now() + 8.5) { hearts.removeAll { $0.id == h.id } } } }
    }
}

// MARK: - Pulsing Dot (Aynı)
struct PulsingDot: View {
    let color: Color
    @State private var pulse = false
    var body: some View {
        ZStack { Circle().fill(color.opacity(0.3)).frame(width: 10, height: 10).scaleEffect(pulse ? 1.5 : 1).opacity(pulse ? 0 : 0.5); Circle().fill(color).frame(width: 6, height: 6).shadow(color: color, radius: 3) }
        .onAppear { withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) { pulse = true } }
    }
}

// MARK: - Status Views (Aynı)
struct SendingStatus: View { let palette: ColorPalette; @State private var dots = 0; var body: some View { HStack(spacing: 6) { ForEach(0..<3, id: \.self) { i in Circle().fill(palette.primaryColor).frame(width: 6, height: 6).opacity(dots > i ? 1 : 0.3) }; Text("Kalbin yolda...").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.7)) }.onAppear { Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in dots = (dots + 1) % 4 } } } }
struct SuccessStatus: View { @State private var pop = false; var body: some View { HStack(spacing: 6) { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundColor(.green).scaleEffect(pop ? 1 : 0); Text("Ulaştı! 💖").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.white) }.onAppear { withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pop = true } } } }
struct ReceivedStatus: View { @State private var beat = false; var body: some View { HStack(spacing: 6) { Image(systemName: "heart.fill").font(.system(size: 12)).foregroundColor(.yellow).scaleEffect(beat ? 1.3 : 1); Text("Seni düşünüyor! 💛").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.white) }.onAppear { withAnimation(.easeInOut(duration: 0.4).repeatForever()) { beat = true } } } }
struct IdleStatus: View { let lastHeart: Date?; var body: some View { if let d = lastHeart { HStack(spacing: 5) { Image(systemName: "heart.text.square").font(.system(size: 10)).foregroundColor(.white.opacity(0.4)); Text("Son: \(d.abbreviatedRelativeString)").font(.system(size: 9, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.4)) } } else { Text("Dokun 💕").font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.4)) } } }
struct SuccessCelebration: View { @State private var scale: CGFloat = 0; var body: some View { Text("💖").font(.system(size: 40)).scaleEffect(scale).onAppear { withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { scale = 1 } } } }
struct LoveCelebration: View { @State private var scale: CGFloat = 0; var body: some View { Text("💛").font(.system(size: 50)).scaleEffect(scale).onAppear { withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) { scale = 1 } } } }
