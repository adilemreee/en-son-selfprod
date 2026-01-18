import SwiftUI
import CloudKit

// MARK: - Premium Settings View
struct SettingsView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var presenceManager = PresenceManager.shared
    @ObservedObject var cloudManager = CloudKitManager.shared
    
    @State private var showAbout = false
    @State private var appearAnimation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Animated Header
                headerSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : -10)
                
                // Theme Section
                themeSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)
                
                // Location Section
                locationSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 15)
                
                // Account Section
                accountSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                
                // App Info
                appInfoSection
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
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ayarlar")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.currentPalette.primaryColor, themeManager.currentPalette.secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Uygulamayı kişiselleştir")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Decorative icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [themeManager.currentPalette.primaryColor.opacity(0.3), themeManager.currentPalette.secondaryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.currentPalette.primaryColor, themeManager.currentPalette.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Theme Section
    private var themeSection: some View {
        SettingsSection(
            title: "Tema",
            icon: "paintpalette.fill",
            iconColor: themeManager.currentPalette.primaryColor
        ) {
            VStack(spacing: 8) {
                ForEach(ColorPalette.allCases) { palette in
                    PremiumThemeRow(
                        palette: palette,
                        isSelected: themeManager.currentPalette == palette
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            themeManager.currentPalette = palette
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Location Section
    private var locationSection: some View {
        SettingsSection(
            title: "Konum",
            icon: "location.fill",
            iconColor: .cyan
        ) {
            VStack(spacing: 10) {
                // Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Yakınlık Algılama")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(presenceManager.isEnabled ? "Partner konumunu takip et" : "Konum paylaşımı kapalı")
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $presenceManager.isEnabled)
                        .labelsHidden()
                        .tint(themeManager.currentPalette.primaryColor)
                }
                
                // Status indicator
                if presenceManager.isEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: authorizationIcon)
                            .font(.system(size: 10))
                            .foregroundColor(authorizationColor)
                        
                        Text(authorizationText)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(authorizationColor)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(authorizationColor.opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        SettingsSection(
            title: "Hesap",
            icon: "person.circle.fill",
            iconColor: .orange
        ) {
            VStack(spacing: 10) {
                // Pairing status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Eşleşme Durumu")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(cloudManager.isPaired ? "Eşleşildi ✓" : "Eşleşilmedi")
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(cloudManager.isPaired ? .green : .orange)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(cloudManager.isPaired ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: cloudManager.isPaired ? .green : .orange, radius: 4)
                }
                
                // iCloud status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(iCloudStatusText)
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Image(systemName: iCloudIcon)
                        .font(.system(size: 14))
                        .foregroundColor(iCloudColor)
                }
            }
        }
    }
    
    // MARK: - App Info Section
    private var appInfoSection: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack {
                Text("Selfprod")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                
                Text("v1.0")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Text("Made with 💜")
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    private var authorizationIcon: String {
        switch presenceManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var authorizationColor: Color {
        switch presenceManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        default:
            return .orange
        }
    }
    
    private var authorizationText: String {
        switch presenceManager.authorizationStatus {
        case .authorizedWhenInUse:
            return "Kullanırken izin verildi"
        case .authorizedAlways:
            return "Her zaman izin verildi"
        case .denied:
            return "İzin reddedildi"
        case .restricted:
            return "Kısıtlı"
        default:
            return "İzin bekleniyor"
        }
    }
    
    private var iCloudStatusText: String {
        switch cloudManager.permissionStatus {
        case .available:
            return "Bağlı"
        case .noAccount:
            return "Hesap yok"
        case .restricted:
            return "Kısıtlı"
        default:
            return "Kontrol ediliyor..."
        }
    }
    
    private var iCloudIcon: String {
        cloudManager.permissionStatus == .available ? "icloud.fill" : "icloud.slash.fill"
    }
    
    private var iCloudColor: Color {
        cloudManager.permissionStatus == .available ? .cyan : .gray
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Content
            content
        }
        .padding(14)
        .background(
            ZStack {
                // Glassmorphism effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

// MARK: - Compact Theme Row
struct PremiumThemeRow: View {
    let palette: ColorPalette
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Compact color preview
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [palette.primaryColor, palette.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 1.5 : 0)
                    )
                
                // Name
                Text(palette.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? palette.primaryColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
