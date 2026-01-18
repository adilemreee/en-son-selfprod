import SwiftUI
import CoreLocation

// MARK: - Proximity Section
struct ProximitySection: View {
    @ObservedObject var presenceManager = PresenceManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // Toggle Row
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yakınlık Algılama")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text(presenceManager.isEnabled ? "Açık" : "Kapalı")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Toggle("", isOn: $presenceManager.isEnabled)
                    .labelsHidden()
                    .tint(.cyan)
            }
            .padding()
            .background(Theme.subtleWhite)
            .cornerRadius(Theme.cornerRadius)
            
            // Status Row (only if enabled)
            if presenceManager.isEnabled {
                proximityStatusRow
                
                // Partner location timestamp
                if let timestamp = presenceManager.partnerLocationTimestamp {
                    partnerTimestampRow(timestamp: timestamp)
                }
                
                // Last Encounter
                if let lastEncounter = presenceManager.lastEncounter {
                    lastEncounterRow(lastEncounter: lastEncounter)
                }
            }
            
            // Authorization warning
            if presenceManager.isEnabled && presenceManager.authorizationStatus != .authorizedWhenInUse && presenceManager.authorizationStatus != .authorizedAlways {
                authorizationWarningRow
            }
        }
    }
    
    // MARK: - Subviews
    private var proximityStatusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: presenceManager.isNearPartner ? "figure.2" : "figure.walk")
                .foregroundColor(presenceManager.isNearPartner ? .green : .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(presenceManager.isNearPartner ? "Yakınınızda! 💕" : "Partner Mesafesi")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(presenceManager.isNearPartner ? .green : .white)
                if let distance = presenceManager.distanceToPartner {
                    Text(distance.formattedDistance)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("Konum bekleniyor...")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
        }
        .padding()
        .background(presenceManager.isNearPartner ? Color.green.opacity(0.15) : Theme.subtleWhite)
        .cornerRadius(Theme.cornerRadius)
        .animation(.easeInOut, value: presenceManager.isNearPartner)
    }
    
    private func partnerTimestampRow(timestamp: Date) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 10))
                .foregroundColor(.cyan.opacity(0.7))
            Text("Partner konumu: \(timestamp.relativeString)")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal)
    }
    
    private func lastEncounterRow(lastEncounter: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("Son Buluşma")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(lastEncounter.relativeString)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding()
        .background(Theme.subtleWhite)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private var authorizationWarningRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text("Konum izni gerekli")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.yellow)
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(Theme.cornerRadius)
        .onTapGesture {
            presenceManager.requestAuthorization()
        }
    }
}
