import SwiftUI

// MARK: - Health Score View
struct HealthScoreView: View {
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
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: CGFloat(scoreValue) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [scoreColor, scoreColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(scoreValue)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(scoreColor)
                    Text("%")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(scoreColor.opacity(0.7))
                }
            }
            
            Text(scoreValue >= 90 ? "Mükemmel! ✨" : (scoreValue >= 70 ? "İyi Durumda" : "Kontrol Gerekli"))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(scoreColor)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(scoreColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                        .stroke(scoreColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Health Check Row
struct HealthCheckRow: View {
    let item: CloudKitManager.HealthCheck
    
    private var iconName: String {
        switch item.severity {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch item.severity {
        case .success: return .green
        case .warning: return .yellow
        case .error: return .red
        case .info: return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(item.detail)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Circle()
                .fill(iconColor)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}
