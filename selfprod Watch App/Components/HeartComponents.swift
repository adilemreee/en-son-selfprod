import SwiftUI
import WatchKit

// MARK: - Pulse Wave Model
struct PulseWave: Identifiable {
    let id = UUID()
    var scale: CGFloat = 1.0
    var opacity: Double = 0.8
}

// MARK: - Heart Ripple Effect View
struct HeartRippleEffectView: View {
    @Binding var triggerBeat: Bool
    @State private var waves: [PulseWave] = []
    let baseSize: CGFloat
    let isReceivedMode: Bool
    
    var body: some View {
        ZStack {
            ForEach(waves) { wave in
                Image(systemName: "heart.fill")
                    .font(.system(size: baseSize))
                    .foregroundStyle(
                        .linearGradient(
                            colors: isReceivedMode ? [.yellow, .orange] : [.pink.opacity(0.8), .purple.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Image(systemName: "heart")
                            .font(.system(size: baseSize * 1.05))
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.3))
                    )
                    .scaleEffect(wave.scale)
                    .opacity(wave.opacity)
                    .blur(radius: 2)
            }
        }
        .onChange(of: triggerBeat) { _, _ in
            spawnWave()
        }
    }
    
    private func spawnWave() {
        let newWave = PulseWave()
        waves.append(newWave)
        
        withAnimation(.easeOut(duration: 0.8)) {
            if let index = waves.firstIndex(where: { $0.id == newWave.id }) {
                waves[index].scale = 3.0
                waves[index].opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            waves.removeAll { $0.id == newWave.id }
        }
    }
}

// MARK: - Pulsing Heart View
struct PulsingHeartView: View {
    @Binding var receivedHeartbeat: Bool
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var innerLightIntensity: Double = 0.5
    @State private var glowRadius: CGFloat = 10
    @State private var glowOpacity: Double = 0.6
    @State private var triggerRippleSignal = false
    @State private var heartbeatTimer: Timer?
    
    private let baseFontSize: CGFloat = Theme.baseFontSize
    
    var body: some View {
        ZStack {
            // Ripple Effect Layer
            HeartRippleEffectView(
                triggerBeat: $triggerRippleSignal,
                baseSize: baseFontSize,
                isReceivedMode: receivedHeartbeat
            )
            
            // Glow Layer
            Image(systemName: "heart.fill")
                .font(.system(size: baseFontSize))
                .foregroundStyle(receivedHeartbeat ? Color.orange : Color.pink)
                .blur(radius: glowRadius)
                .opacity(glowOpacity)
                .scaleEffect(scale * 1.1)
            
            // Main Heart Button
            Button(action: {
                triggerManualBeat()
                onTap()
            }) {
                ZStack {
                    // Neon Body
                    Image(systemName: "heart.fill")
                        .font(.system(size: baseFontSize))
                        .foregroundStyle(
                            receivedHeartbeat ? Theme.receivedHeartGradient : Theme.heartGradient
                        )
                        .shadow(
                            color: receivedHeartbeat ? .orange.opacity(0.8) : Color.pink.opacity(0.7),
                            radius: 8, x: 0, y: 0
                        )
                    
                    // Inner Shine
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
        .onAppear {
            startHeartbeatTimer()
        }
        .onDisappear {
            heartbeatTimer?.invalidate()
            heartbeatTimer = nil
        }
        .onChange(of: receivedHeartbeat) { _, newValue in
            if newValue {
                performRapidExcitementHeartbeat()
            }
        }
    }
    
    // MARK: - Timer Management (Memory Leak Fix)
    private func startHeartbeatTimer() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !receivedHeartbeat {
                performModernHeartbeat()
            }
        }
    }
    
    // MARK: - Animations
    private func performModernHeartbeat() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4, blendDuration: 0)) {
            scale = 1.2
            innerLightIntensity = 0.9
            glowRadius = 20
            glowOpacity = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            triggerRippleSignal.toggle()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                innerLightIntensity = 0.5
                glowRadius = 10
                glowOpacity = 0.6
            }
        }
    }
    
    private func triggerManualBeat() {
        withAnimation(.easeIn(duration: 0.05)) {
            scale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            triggerRippleSignal.toggle()
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
                scale = 1.35
                innerLightIntensity = 1.0
                glowRadius = 25
                glowOpacity = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.5)) {
                scale = 1.0
                innerLightIntensity = 0.5
                glowRadius = 10
                glowOpacity = 0.6
            }
        }
    }
    
    private func performRapidExcitementHeartbeat() {
        let beatCount = 6
        let duration = 0.18
        
        for i in 0..<beatCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * duration)) {
                triggerRippleSignal.toggle()
                withAnimation(.spring(response: 0.12, dampingFraction: 0.4)) {
                    scale = 1.3
                    glowRadius = 30
                    glowOpacity = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + (duration * 0.5)) {
                    withAnimation(.easeOut(duration: 0.08)) {
                        scale = 1.0
                        glowRadius = 15
                        glowOpacity = 0.7
                    }
                }
            }
        }
    }
}

// MARK: - Floating Hearts Background
struct FloatingHeart: Identifiable {
    let id: UUID
    var position: CGPoint
    var size: CGFloat
    var color: Color
    var opacity: Double
}

struct FloatingHeartsView: View {
    @Binding var isActive: Bool
    @State private var hearts: [FloatingHeart] = []
    
    var body: some View {
        ZStack {
            ForEach(hearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: heart.size))
                    .foregroundColor(heart.color)
                    .position(heart.position)
                    .opacity(heart.opacity)
                    .blur(radius: 1)
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                createFloatingHearts()
            }
        }
    }
    
    private func createFloatingHearts() {
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                let heart = FloatingHeart(
                    id: UUID(),
                    position: CGPoint(x: CGFloat.random(in: 10...190), y: 210),
                    size: CGFloat.random(in: 8...16),
                    color: [Color.pink, Color.purple, Color.orange, Color.cyan].randomElement()!,
                    opacity: 0.7
                )
                hearts.append(heart)
                
                withAnimation(.easeOut(duration: 3.0)) {
                    if let index = hearts.firstIndex(where: { $0.id == heart.id }) {
                        hearts[index].position.y = -40
                        hearts[index].position.x += CGFloat.random(in: -30...30)
                        hearts[index].opacity = 0
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
                    hearts.removeAll { $0.id == heart.id }
                }
            }
        }
    }
}
