import SwiftUI
import WatchKit
import Combine
import CloudKit

// MARK: - Heart View (Main)
struct HeartView: View {
    @ObservedObject var cloudManager = CloudKitManager.shared
    @ObservedObject var presenceManager = PresenceManager.shared
    @ObservedObject var voiceManager = VoiceManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var showSentMessage = false
    @State private var receivedHeartbeat = false
    @State private var isSending = false
    @State private var lastSentTime: Date?
    @State private var showUnpairConfirmation = false
    
    var body: some View {
        TabView {
            HeartPageView()
            VoicePageView()
            MapPageView()
            StatusPageView()
            HealthPageView()
            SettingsView()
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .background(themeManager.currentPalette.backgroundGradient.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HeartbeatReceived"))) { _ in
            receiveLove()
        }
    }
    
    // MARK: - Main Heart Page
    private var mainHeartPage: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            
            FloatingHeartsView(isActive: $receivedHeartbeat)
            
            VStack {
                // Header
                header
                
                Spacer()
                
                // Heart
                PulsingHeartView(receivedHeartbeat: $receivedHeartbeat) {
                    sendLove()
                }
                .frame(maxHeight: .infinity)
                
                Spacer()
                
                // Bottom Message
                bottomMessage
                
                // Error Display
                errorDisplay
            }
        }
    }
    
    private var header: some View {
        ZStack {
            VStack(spacing: 6) {
                Text("ÖZLEDİM AŞKIMI")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .pink.opacity(0.4), radius: 3, x: 0, y: 0)
            }
            
            VStack {
                HStack {
                    Spacer()
                    ModernStatusView(isConnected: cloudManager.isPaired)
                        .padding(.trailing, 8)
                        .padding(.top, 2)
                }
                Spacer()
            }
        }
        .padding(.top, 15)
    }
    
    private var bottomMessage: some View {
        ZStack {
            if showSentMessage {
                MessageCapsule(text: "Aşkıma Kalp..💖", color: .pink)
                    .transition(.scale.combined(with: .opacity).animation(.spring))
            } else if receivedHeartbeat {
                MessageCapsule(text: "Aşkın Seni Düşünüyor..", color: .yellow)
                    .transition(.scale.combined(with: .opacity).animation(.spring))
            } else {
                Text("Aşkına dokunn")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .frame(height: 40)
    }
    
    @ViewBuilder
    private var errorDisplay: some View {
        if let error = cloudManager.errorMessage {
            Text(error)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.red.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            
            HStack(spacing: 8) {
                if cloudManager.permissionStatus == .restricted || cloudManager.permissionStatus == .couldNotDetermine {
                    Text("iCloud kısıtlı, ayarları kontrol et.")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                }
                Button("Aboneliği Yenile") {
                    CloudKitManager.shared.refreshSubscriptions()
                }
                .font(.system(size: 10, weight: .bold, design: .rounded))
            }
        }
    }
    
    // MARK: - Status Page
    private var statusPage: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer(minLength: 8)
                Text("Durum")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.statusGradient)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                StatusRow(title: "Son Gönderilen", icon: "paperplane.fill", color: .pink, date: cloudManager.lastSentAt)
                StatusRow(title: "Son Alınan", icon: "heart.circle.fill", color: .yellow, date: cloudManager.lastReceivedAt)
                PresenceRow(lastReceived: cloudManager.lastReceivedAt)
                
                Divider().background(Color.white.opacity(0.2)).padding(.vertical, 4)
                
                Text("Yakınlık")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ProximitySection()
                
                Divider().background(Color.white.opacity(0.2)).padding(.vertical, 4)
                
                unpairButton
                
                Spacer(minLength: 0)
            }
            .padding()
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
    }
    
    private var unpairButton: some View {
        Button(action: { showUnpairConfirmation = true }) {
            Text("Eşleşmeyi Bitir")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(14)
                .shadow(color: .red.opacity(0.4), radius: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .alert("Eşleşmeyi Bitir", isPresented: $showUnpairConfirmation) {
            Button("İptal", role: .cancel) { }
            Button("Evet, Bitir", role: .destructive) {
                cloudManager.unpair()
            }
        } message: {
            Text("Eşleşmeyi bitirmek istediğinden emin misin?")
        }
    }
    
    // MARK: - Health Page
    private var healthPage: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer(minLength: 8)
                
                HStack {
                    Text("Sistem Testi")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.healthGradient)
                    
                    Spacer()
                    
                    if let lastTest = cloudManager.lastTestDate {
                        Text(lastTest.timeString)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal)
                
                // Test Button
                testButton
                
                // Results
                healthResults
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
    }
    
    private var testButton: some View {
        VStack(spacing: 8) {
            Button(action: { CloudKitManager.shared.runSelfTest() }) {
                HStack(spacing: 8) {
                    if cloudManager.isRunningTest {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(cloudManager.isRunningTest ? "Test Yapılıyor..." : "Testi Çalıştır")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: cloudManager.isRunningTest ? [.gray, .gray.opacity(0.8)] : [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(cloudManager.isRunningTest)
            
            if cloudManager.isRunningTest {
                progressBar
            }
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.healthGradient)
                    .frame(width: geo.size.width * cloudManager.testProgress, height: 4)
                    .animation(.easeInOut(duration: 0.2), value: cloudManager.testProgress)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 4)
    }
    
    @ViewBuilder
    private var healthResults: some View {
        if cloudManager.healthChecks.isEmpty && !cloudManager.isRunningTest {
            emptyHealthState
        } else {
            healthChecksList
        }
    }
    
    private var emptyHealthState: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.3))
            Text("Henüz test çalıştırılmadı")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Text("Sistemin sağlığını kontrol etmek için\ntesti çalıştırın")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
    
    private var healthChecksList: some View {
        VStack(spacing: 12) {
            if let scoreCheck = cloudManager.healthChecks.first(where: { $0.title == "Genel Skor" }) {
                HealthScoreView(check: scoreCheck)
                    .padding(.bottom, 4)
            }
            
            ForEach(groupedHealthChecks(), id: \.0) { category, checks in
                VStack(alignment: .leading, spacing: 6) {
                    Text(category)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.leading, 4)
                    
                    ForEach(checks) { item in
                        HealthCheckRow(item: item)
                    }
                }
            }
            
            if !cloudManager.healthChecks.isEmpty {
                Button(action: { cloudManager.refreshSubscriptions() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Abonelikleri Yenile")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.cyan)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Helpers
    private func groupedHealthChecks() -> [(String, [CloudKitManager.HealthCheck])] {
        let checks = cloudManager.healthChecks.filter { $0.title != "Genel Skor" }
        let grouped = Dictionary(grouping: checks) { $0.category.rawValue }
        let order = ["Hesap", "Bağlantı", "Abonelik", "Eşleşme", "Veri"]
        return order.compactMap { key in
            if let items = grouped[key], !items.isEmpty {
                return (key, items)
            }
            return nil
        }
    }
    
    // MARK: - Actions
    func sendLove() {
        let now = Date()
        if let lastSent = lastSentTime, now.timeIntervalSince(lastSent) < 2.0 {
            return
        }
        
        guard !isSending else { return }
        
        isSending = true
        lastSentTime = now
        
        playAttentionHaptic()
        withAnimation { showSentMessage = true }
        
        cloudManager.sendHeartbeat { success in
            DispatchQueue.main.async {
                isSending = false
                
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { showSentMessage = false }
                    }
                } else {
                    withAnimation { showSentMessage = false }
                    lastSentTime = nil
                }
            }
        }
    }
    
    func receiveLove() {
        withAnimation { receivedHeartbeat = true }
        CloudKitManager.shared.markHeartbeatReceived()
        playAttentionHaptic()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation { receivedHeartbeat = false }
        }
    }
    
    private func playAttentionHaptic() {
        WKInterfaceDevice.current().play(.success)
    }
}

struct HeartView_Previews: PreviewProvider {
    static var previews: some View {
        HeartView()
    }
}
