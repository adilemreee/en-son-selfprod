import SwiftUI
import MapKit
import CoreLocation

// MARK: - Map Page View
struct MapPageView: View {
    @ObservedObject var presenceManager = PresenceManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showingBothLocations = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Background
            themeManager.currentPalette.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Map or Placeholder
                if presenceManager.isEnabled {
                    mapContent
                } else {
                    disabledState
                }
                
                // Bottom Info
                bottomInfo
            }
        }
        .onAppear {
            updateRegion()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onChange(of: presenceManager.currentLocation) { _, _ in
            updateRegion()
        }
        .onChange(of: presenceManager.partnerLocation) { _, _ in
            updateRegion()
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Harita")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.currentPalette.primaryColor, themeManager.currentPalette.secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Distance or status
                if let distance = presenceManager.distanceToPartner {
                    Text(distance.formattedDistance + " uzakta")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text(presenceManager.locationStatus.rawValue)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Refresh button
            Button(action: {
                presenceManager.forceRefresh()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(presenceManager.isNearPartner ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: presenceManager.isNearPartner ? .green : .orange, radius: 4)
                
                Text(presenceManager.isNearPartner ? "Yakın" : "Uzak")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    // MARK: - Map Content
    private var mapContent: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $region, annotationItems: mapAnnotations) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    MapMarkerView(
                        isUser: item.isUser,
                        isNear: presenceManager.isNearPartner,
                        palette: themeManager.currentPalette,
                        pulseAnimation: $pulseAnimation
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [themeManager.currentPalette.primaryColor.opacity(0.5), themeManager.currentPalette.secondaryColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: themeManager.currentPalette.primaryColor.opacity(0.3), radius: 10)
            .padding(.horizontal, 8)
            
            // Zoom controls
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    zoomControls
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(height: 140)
    }
    
    // MARK: - Zoom Controls
    private var zoomControls: some View {
        VStack(spacing: 4) {
            Button(action: zoomIn) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: zoomOut) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Disabled State
    private var disabledState: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.gray, .gray.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Text("Konum Kapalı")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            
            Text("Ayarlardan yakınlık algılamayı aç")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            
            Button(action: {
                presenceManager.isEnabled = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                    Text("Aç")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [themeManager.currentPalette.primaryColor, themeManager.currentPalette.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: 140)
    }
    
    // MARK: - Bottom Info
    private var bottomInfo: some View {
        HStack(spacing: 16) {
            // User location
            LocationInfoCard(
                icon: "person.fill",
                title: "Sen",
                subtitle: presenceManager.currentLocation != nil ? "Aktif" : "Bekleniyor",
                color: themeManager.currentPalette.primaryColor,
                isActive: presenceManager.currentLocation != nil
            )
            
            // Partner location
            LocationInfoCard(
                icon: "heart.fill",
                title: "Aşkım",
                subtitle: partnerStatusText,
                color: themeManager.currentPalette.secondaryColor,
                isActive: presenceManager.partnerLocation != nil
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var partnerStatusText: String {
        if let timestamp = presenceManager.partnerLocationTimestamp {
            return timestamp.abbreviatedRelativeString
        }
        return "Bekleniyor"
    }
    
    // MARK: - Annotations
    private var mapAnnotations: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []
        
        if let userLoc = presenceManager.currentLocation {
            items.append(MapAnnotationItem(
                id: "user",
                coordinate: userLoc.coordinate,
                isUser: true
            ))
        }
        
        if let partnerLoc = presenceManager.partnerLocation {
            items.append(MapAnnotationItem(
                id: "partner",
                coordinate: partnerLoc.coordinate,
                isUser: false
            ))
        }
        
        return items
    }
    
    // MARK: - Actions
    private func updateRegion() {
        if let userLoc = presenceManager.currentLocation,
           let partnerLoc = presenceManager.partnerLocation {
            // Show both locations
            let midLat = (userLoc.coordinate.latitude + partnerLoc.coordinate.latitude) / 2
            let midLon = (userLoc.coordinate.longitude + partnerLoc.coordinate.longitude) / 2
            
            let latDelta = abs(userLoc.coordinate.latitude - partnerLoc.coordinate.latitude) * 1.5
            let lonDelta = abs(userLoc.coordinate.longitude - partnerLoc.coordinate.longitude) * 1.5
            
            withAnimation(.easeInOut(duration: 0.5)) {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
                    span: MKCoordinateSpan(
                        latitudeDelta: max(latDelta, 0.01),
                        longitudeDelta: max(lonDelta, 0.01)
                    )
                )
            }
        } else if let userLoc = presenceManager.currentLocation {
            withAnimation(.easeInOut(duration: 0.5)) {
                region.center = userLoc.coordinate
            }
        }
    }
    
    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.3)) {
            region.span.latitudeDelta /= 2
            region.span.longitudeDelta /= 2
        }
    }
    
    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.3)) {
            region.span.latitudeDelta *= 2
            region.span.longitudeDelta *= 2
        }
    }
}

// MARK: - Map Annotation Item
struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let isUser: Bool
}

// MARK: - Map Marker View
struct MapMarkerView: View {
    let isUser: Bool
    let isNear: Bool
    let palette: ColorPalette
    @Binding var pulseAnimation: Bool
    
    var body: some View {
        ZStack {
            // Pulse ring (only for partner when near)
            if !isUser && isNear {
                Circle()
                    .stroke(Color.green.opacity(0.5), lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                    .opacity(pulseAnimation ? 0 : 0.8)
            }
            
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            isUser ? palette.primaryColor.opacity(0.6) : Color.red.opacity(0.6),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 15
                    )
                )
                .frame(width: 30, height: 30)
            
            // Main marker
            ZStack {
                Circle()
                    .fill(isUser ? palette.primaryColor : Color.red)
                    .frame(width: 16, height: 16)
                
                Image(systemName: isUser ? "person.fill" : "heart.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: isUser ? palette.primaryColor : .red, radius: 4)
        }
    }
}

// MARK: - Location Info Card
struct LocationInfoCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(isActive ? 0.2 : 0.1))
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isActive ? color : .gray)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(isActive ? 0.3 : 0.1), lineWidth: 1)
                )
        )
    }
}
