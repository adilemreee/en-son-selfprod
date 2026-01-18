import SwiftUI

// MARK: - Premium Health Page View
struct HealthPageView: View {
    @ObservedObject var cloudManager = CloudKitManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var appearAnimation = false
    @State private var testPulse = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Header
                header
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : -10)
                
                // Test Button
                testButton
                    .opacity(appearAnimation ? 1 : 0)
                    .scaleEffect(appearAnimation ? 1 : 0.95)
                
                // Results
                if cloudManager.healthChecks.isEmpty && !cloudManager.isRunningTest {
                    emptyState
                        .opacity(appearAnimation ? 1 : 0)
                } else {
                    resultsSection
                        .opacity(appearAnimation ? 1 : 0)
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(themeManager.currentPalette.backgroundGradient.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sistem Testi")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                if let lastTest = cloudManager.lastTestDate {
                    Text("Son: \(lastTest.abbreviatedRelativeString)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("Bağlantıyı kontrol et")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .scaleEffect(testPulse ? 1.2 : 1.0)
                    .opacity(testPulse ? 0.5 : 1.0)
                
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
            }
            .onChange(of: cloudManager.isRunningTest) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        testPulse = true
                    }
                } else {
                    testPulse = false
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Test Button
    private var testButton: some View {
        Button(action: { CloudKitManager.shared.runSelfTest() }) {
            HStack(spacing: 10) {
                if cloudManager.isRunningTest {
                    // Animated loading
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 16, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(cloudManager.isRunningTest ? "Test Yapılıyor..." : "Testi Çalıştır")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    
                    if cloudManager.isRunningTest {
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 3)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white)
                                    .frame(width: geo.size.width * cloudManager.testProgress, height: 3)
                            }
                        }
                        .frame(height: 3)
                    }
                }
                
                Spacer()
                
                if !cloudManager.isRunningTest {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .foregroundColor(.white)
            .padding(14)
            .background(
                LinearGradient(
                    colors: cloudManager.isRunningTest ?
                        [.gray.opacity(0.6), .gray.opacity(0.4)] :
                        [.green, .mint],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .green.opacity(cloudManager.isRunningTest ? 0 : 0.4), radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(cloudManager.isRunningTest)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 70, height: 70)
                
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            VStack(spacing: 4) {
                Text("Henüz test yapılmadı")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Sistemin sağlığını kontrol et")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 30)
    }
    
    // MARK: - Results Section
    private var resultsSection: some View {
        VStack(spacing: 12) {
            // Overall Score
            if let scoreCheck = cloudManager.healthChecks.first(where: { $0.title == "Genel Skor" }) {
                HealthScoreCard(check: scoreCheck)
            }
            
            // Categories
            ForEach(groupedHealthChecks(), id: \.0) { category, checks in
                CategoryCard(category: category, checks: checks)
            }
            
            // Refresh Button
            if !cloudManager.healthChecks.isEmpty {
                Button(action: { cloudManager.refreshSubscriptions() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Abonelikleri Yenile")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.cyan)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cyan.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
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
}

// MARK: - Health Score Card
struct HealthScoreCard: View {
    let check: CloudKitManager.HealthCheck
    
    private var scoreValue: Int {
        let components = check.detail.components(separatedBy: " ")
        if let first = components.first, first.hasPrefix("%") {
            return Int(first.dropFirst()) ?? 0
        }
        return 0
    }
    
    private var scoreColor: Color {
        if scoreValue >= 90 { return .green }
        if scoreValue >= 70 { return .yellow }
        return .red
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Score Circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 5)
                    .frame(width: 55, height: 55)
                
                Circle()
                    .trim(from: 0, to: CGFloat(scoreValue) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [scoreColor, scoreColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 55, height: 55)
                    .rotationEffect(.degrees(-90))
                
                Text("\(scoreValue)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(scoreColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Sistem Sağlığı")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(scoreValue >= 90 ? "Mükemmel ✨" : (scoreValue >= 70 ? "İyi durumda" : "Kontrol gerekli"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(scoreColor)
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(scoreColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(scoreColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: String
    let checks: [CloudKitManager.HealthCheck]
    
    private var categoryIcon: String {
        switch category {
        case "Hesap": return "person.circle.fill"
        case "Bağlantı": return "wifi"
        case "Abonelik": return "bell.fill"
        case "Eşleşme": return "heart.fill"
        case "Veri": return "cylinder.split.1x2.fill"
        default: return "checkmark.circle.fill"
        }
    }
    
    private var categoryColor: Color {
        switch category {
        case "Hesap": return .blue
        case "Bağlantı": return .cyan
        case "Abonelik": return .purple
        case "Eşleşme": return .pink
        case "Veri": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category Header
            HStack(spacing: 6) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 11))
                    .foregroundColor(categoryColor)
                
                Text(category)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Check Items
            ForEach(checks) { check in
                HStack(spacing: 8) {
                    Image(systemName: check.severity == .success ? "checkmark.circle.fill" : 
                          check.severity == .warning ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(check.severity == .success ? .green : 
                                        check.severity == .warning ? .yellow : .red)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(check.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(check.detail)
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
    }
}
