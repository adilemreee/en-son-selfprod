import SwiftUI
import WatchKit

// MARK: - Premium Voice Page View
struct VoicePageView: View {
    @ObservedObject var voiceManager = VoiceManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var waveformPhase: CGFloat = 0
    @State private var appearAnimation = false
    @State private var micScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background
            themeManager.currentPalette.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : -10)
                
                Spacer()
                
                // Main Content
                if voiceManager.hasIncomingMessage {
                    incomingMessageCard
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                
                // Recording UI
                recordingSection
                    .opacity(appearAnimation ? 1 : 0)
                    .scaleEffect(appearAnimation ? 1 : 0.9)
                
                Spacer()
                
                // Bottom instruction
                bottomInstruction
                    .opacity(appearAnimation ? 1 : 0)
                
                // Error message
                if let error = voiceManager.errorMessage {
                    errorBanner(error)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
            voiceManager.subscribeToVoiceMessages()
            voiceManager.checkForIncomingMessages()
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sesli Mesaj")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(voiceManager.isRecording ? "Kaydediliyor..." : "10 saniyeye kadar")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Waveform icon
            WaveformIcon(isActive: voiceManager.isRecording || voiceManager.isPlaying)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Incoming Message Card
    private var incomingMessageCard: some View {
        Button(action: {
            voiceManager.playIncomingMessage()
        }) {
            HStack(spacing: 12) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: voiceManager.isPlaying ? "speaker.wave.2.fill" : "envelope.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yellow)
                        .symbolEffect(.bounce, isActive: voiceManager.isPlaying)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Yeni Mesaj!")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if voiceManager.incomingMessageDuration > 0 {
                            Text("\(Int(voiceManager.incomingMessageDuration))sn")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.yellow.opacity(0.2))
                                )
                        }
                    }
                    
                    Text(voiceManager.isPlaying ? "Çalıyor..." : "Dinlemek için dokun")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.yellow.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Recording Section
    private var recordingSection: some View {
        VStack(spacing: 12) {
            // Main recording button with rings
            ZStack {
                // Outer pulse ring (when recording)
                if voiceManager.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(micScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                micScale = 1.15
                            }
                        }
                        .onDisappear {
                            micScale = 1.0
                        }
                }
                
                // Progress ring background
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 6
                    )
                    .frame(width: 85, height: 85)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: voiceManager.recordingProgress)
                    .stroke(
                        LinearGradient(
                            colors: voiceManager.isRecording ? [.red, .orange] : [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 85, height: 85)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: voiceManager.recordingProgress)
                
                // Center button
                Button(action: {}) {
                    ZStack {
                        // Glassmorphism background
                        Circle()
                            .fill(
                                voiceManager.isRecording ?
                                Color.red.opacity(0.3) :
                                Color.white.opacity(0.1)
                            )
                            .frame(width: 65, height: 65)
                        
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: voiceManager.isRecording ?
                                        [.red.opacity(0.8), .orange.opacity(0.5)] :
                                        [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 65, height: 65)
                        
                        // Icon
                        Image(systemName: voiceManager.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(voiceManager.isRecording ? .red : .white)
                            .symbolEffect(.bounce, value: voiceManager.isRecording)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.1)
                        .onEnded { _ in
                            WKInterfaceDevice.current().play(.start)
                            voiceManager.startRecording()
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in
                            if voiceManager.isRecording {
                                voiceManager.stopRecording()
                            }
                        }
                )
            }
            
            // Waveform visualization (when recording)
            if voiceManager.isRecording {
                WaveformVisualizer()
                    .frame(height: 30)
                    .padding(.horizontal, 30)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: voiceManager.isRecording)
    }
    
    // MARK: - Bottom Instruction
    private var bottomInstruction: some View {
        Group {
            if voiceManager.showSentMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Gönderildi!")
                        .foregroundColor(.green)
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .transition(.scale.combined(with: .opacity))
            } else {
                Text(voiceManager.isRecording ? "Bırak → Gönder" : "Basılı Tut → Kaydet")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.bottom, 8)
        .animation(.easeInOut, value: voiceManager.showSentMessage)
    }
    
    // MARK: - Error Banner
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.red.opacity(0.9))
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.15))
        )
        .padding(.bottom, 8)
    }
}

// MARK: - Waveform Icon
struct WaveformIcon: View {
    let isActive: Bool
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(
                        isActive ?
                            .easeInOut(duration: 0.3)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1) :
                            .default,
                        value: animating
                    )
            }
        }
        .frame(width: 24, height: 20)
        .onAppear {
            if isActive {
                animating = true
            }
        }
        .onChange(of: isActive) { _, newValue in
            animating = newValue
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = isActive && animating ?
            [12, 18, 10, 16, 14] :
            [6, 10, 8, 10, 6]
        return heights[index]
    }
}

// MARK: - Waveform Visualizer
struct WaveformVisualizer: View {
    @State private var levels: [CGFloat] = Array(repeating: 0.3, count: 15)
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<15, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.8), .orange.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: levels[index] * 25)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                levels = (0..<15).map { _ in CGFloat.random(in: 0.2...1.0) }
            }
        }
    }
}
