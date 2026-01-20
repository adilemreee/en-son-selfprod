import SwiftUI
import CoreLocation
import Combine

// MARK: - Color Palette Enum
enum ColorPalette: String, CaseIterable, Identifiable {
    case romantic = "romantic"
    case ocean = "ocean"
    case sunset = "sunset"
    case night = "night"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .romantic: return "💕 Romantik"
        case .ocean: return "🌊 Okyanus"
        case .sunset: return "🌅 Gün Batımı"
        case .night: return "🌙 Gece"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .romantic: return Color(red: 1.0, green: 0.2, blue: 0.6)
        case .ocean: return Color(red: 0.0, green: 0.7, blue: 0.9)
        case .sunset: return Color(red: 1.0, green: 0.5, blue: 0.2)
        case .night: return Color(red: 0.3, green: 0.4, blue: 0.7)
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .romantic: return Color(red: 0.8, green: 0.1, blue: 0.9)
        case .ocean: return Color(red: 0.1, green: 0.4, blue: 0.7)
        case .sunset: return Color(red: 1.0, green: 0.2, blue: 0.3)
        case .night: return Color(red: 0.1, green: 0.2, blue: 0.4)
        }
    }
    
    var heartGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var backgroundGradient: RadialGradient {
        switch self {
        case .romantic:
            return RadialGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.05, blue: 0.15), Color.black]),
                center: .center, startRadius: 10, endRadius: 180
            )
        case .ocean:
            return RadialGradient(
                gradient: Gradient(colors: [Color(red: 0.0, green: 0.15, blue: 0.25), Color.black]),
                center: .center, startRadius: 10, endRadius: 180
            )
        case .sunset:
            return RadialGradient(
                gradient: Gradient(colors: [Color(red: 0.2, green: 0.1, blue: 0.05), Color.black]),
                center: .center, startRadius: 10, endRadius: 180
            )
        case .night:
            return RadialGradient(
                gradient: Gradient(colors: [Color(red: 0.05, green: 0.1, blue: 0.2), Color.black]),
                center: .center, startRadius: 10, endRadius: 180
            )
        }
    }
}

// MARK: - Theme Manager
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    private let paletteKey = "selectedColorPalette"
    
    @Published var currentPalette: ColorPalette {
        didSet {
            UserDefaults.standard.set(currentPalette.rawValue, forKey: paletteKey)
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: paletteKey),
           let palette = ColorPalette(rawValue: saved) {
            self.currentPalette = palette
        } else {
            self.currentPalette = .romantic
        }
    }
}

// MARK: - Theme Constants
/// Centralized theme configuration for consistent styling across the app
enum Theme {
    // MARK: - Dynamic Gradients (based on selected palette)
    static var backgroundGradient: RadialGradient {
        ThemeManager.shared.currentPalette.backgroundGradient
    }
    
    static var heartGradient: LinearGradient {
        ThemeManager.shared.currentPalette.heartGradient
    }
    
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [ThemeManager.shared.currentPalette.primaryColor, ThemeManager.shared.currentPalette.secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Static Gradients
    static let receivedHeartGradient = LinearGradient(
        colors: [.yellow, .orange, .red],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let statusGradient = LinearGradient(
        colors: [.cyan, .blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let healthGradient = LinearGradient(
        colors: [.green, .mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let voiceGradient = LinearGradient(
        colors: [.purple, .pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Colors
    static var appPink: Color { ThemeManager.shared.currentPalette.primaryColor }
    static var appPurple: Color { ThemeManager.shared.currentPalette.secondaryColor }
    static let subtleWhite = Color.white.opacity(0.05)
    static let mutedText = Color.white.opacity(0.6)
    
    // MARK: - Sizes
    static let baseFontSize: CGFloat = 80
    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
}

// MARK: - Date Extension
extension Date {
    // MARK: - Static Formatters (Performance Optimization)
    private static let relativeFullFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    private static let relativeShortFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
    private static let relativeAbbreviatedFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    // MARK: - Computed Properties
    var relativeString: String {
        Self.relativeFullFormatter.localizedString(for: self, relativeTo: Date())
    }
    
    var shortRelativeString: String {
        Self.relativeShortFormatter.localizedString(for: self, relativeTo: Date())
    }
    
    var abbreviatedRelativeString: String {
        Self.relativeAbbreviatedFormatter.localizedString(for: self, relativeTo: Date())
    }
    
    var timeString: String {
        Self.timeFormatter.string(from: self)
    }
}
