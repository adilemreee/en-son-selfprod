import SwiftUI

// MARK: - Premium Status Page View
struct StatusPageView: View {
    @ObservedObject var cloudManager = CloudKitManager.shared
    @ObservedObject var presenceManager = PresenceManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var appearAnimation = false
    @State private var showUnpairConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Header
                header
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : -10)
                
                // Activity Cards
                activitySection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)
                
                // Partner Status
                partnerStatusSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 15)
                
                
                // Proximity Section
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "Yakınlık", icon: "location.fill", color: .cyan)
                    ProximitySection()
                }
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
                
                Divider().background(Color.white.opacity(0.1))
                
                // Unpair Button
                unpairButton
                    .opacity(appearAnimation ? 1 : 0)
                
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
                Text("Durum")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Aktivite özeti")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Connection indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(cloudManager.isPaired ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: cloudManager.isPaired ? .green : .orange, radius: 4)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Activity Section
    private var activitySection: some View {
        HStack(spacing: 10) {
            // Sent Card
            ActivityCard(
                icon: "paperplane.fill",
                title: "Gönderilen",
                time: cloudManager.lastSentAt?.abbreviatedRelativeString ?? "—",
                color: themeManager.currentPalette.primaryColor,
                isActive: cloudManager.lastSentAt != nil
            )
            
            // Received Card
            ActivityCard(
                icon: "heart.fill",
                title: "Alınan",
                time: cloudManager.lastReceivedAt?.abbreviatedRelativeString ?? "—",
                color: .yellow,
                isActive: cloudManager.lastReceivedAt != nil
            )
        }
    }
    
    // MARK: - Partner Status Section
    private var partnerStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Partner", icon: "person.2.fill", color: .purple)
            
            HStack(spacing: 12) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(partnerStatusColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: partnerStatusIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(partnerStatusColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(partnerStatusTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(partnerStatusSubtitle)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    
                    if presenceManager.isEnabled {
                        if presenceManager.isNearPartner {
                            Text("Buluştunuz! 💑")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                                .padding(.top, 2)
                        } else if let distance = presenceManager.distanceToPartner {
                            Text("Mesafe: \(distance.formattedDistance)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.cyan)
                                .padding(.top, 2)
                        } else {
                            Text("Konum bekleniyor...")
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 2)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(partnerStatusColor.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    
    // MARK: - Section Header
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Unpair Button
    private var unpairButton: some View {
        Button(action: { showUnpairConfirmation = true }) {
            HStack(spacing: 8) {
                Image(systemName: "link.badge.plus")
                    .rotationEffect(.degrees(45))
                Text("Eşleşmeyi Bitir")
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.red.opacity(0.8), .pink.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
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
    
    // MARK: - Helper Properties
    private var partnerStatusColor: Color {
        if let lastReceived = cloudManager.lastReceivedAt {
            let minutes = Date().timeIntervalSince(lastReceived) / 60
            if minutes < 5 { return .green }
            if minutes < 30 { return .yellow }
        }
        return .gray
    }
    
    private var partnerStatusIcon: String {
        if let lastReceived = cloudManager.lastReceivedAt {
            let minutes = Date().timeIntervalSince(lastReceived) / 60
            if minutes < 5 { return "heart.fill" }
            if minutes < 30 { return "heart.circle" }
        }
        return "heart.slash"
    }
    
    private var partnerStatusTitle: String {
        if let lastReceived = cloudManager.lastReceivedAt {
            let minutes = Date().timeIntervalSince(lastReceived) / 60
            if minutes < 5 { return "Çevrimiçi 💚" }
            if minutes < 30 { return "Kısa süre önce" }
        }
        return "Çevrimdışı"
    }
    
    private var partnerStatusSubtitle: String {
        if let lastReceived = cloudManager.lastReceivedAt {
            return "Son kalp: \(lastReceived.relativeString)"
        }
        return "Henüz kalp almadın"
    }
}

// MARK: - Activity Card
struct ActivityCard: View {
    let icon: String
    let title: String
    let time: String
    let color: Color
    let isActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isActive ? color : .gray)
                
                Spacer()
                
                Circle()
                    .fill(isActive ? color : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
            
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            
            Text(time)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isActive ? .white : .white.opacity(0.5))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isActive ? color.opacity(0.3) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
    }
}
