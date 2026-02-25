import SwiftUI

// MARK: - App Theme Colors
struct ThemeColors {
    static let sidebarBackground = LinearGradient(
        gradient: Gradient(colors: [Color(red: 40/255, green: 120/255, blue: 210/255), Color(red: 25/255, green: 90/255, blue: 180/255)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let contentBackground = LinearGradient(
        gradient: Gradient(colors: [Color(red: 15/255, green: 25/255, blue: 50/255), Color(red: 10/255, green: 15/255, blue: 30/255)]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardBackground = Color.white.opacity(0.1)
    static let cardHoverBackground = Color.white.opacity(0.15)
    
    static let accent = Color.blue
    static let secondaryText = Color.white.opacity(0.7)
    
    static let pillSelection = Color.white.opacity(0.15)
}

// MARK: - Card Modifiers
struct SettingsCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ThemeColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func settingsCardStyle() -> some View {
        self.modifier(SettingsCardModifier())
    }
}

// MARK: - Reusable Row Components

struct StatusRow: View {
    let title: String
    let status: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(status ? .green : .red)
                .font(.title2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
}

struct StatusActionRow: View {
    let title: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.red)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.title3)
                    .foregroundColor(.white)
            }
            Spacer()
            Button(action: action) {
                Text(actionTitle)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
}

struct TipRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.title2)
            Text(text)
                .font(.body)
                .foregroundColor(ThemeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(12)
        .background(Color.yellow.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var iconGradient: LinearGradient? = nil

    var body: some View {
        HStack {
            if let gradient = iconGradient {
                ZStack {
                    Circle()
                        .fill(gradient)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .foregroundColor(.white)
                }
            } else {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }

            
            Text(title)
                .font(.title3)
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .labelsHidden()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
}

struct RadioCardRow: View {
    let title: String
    let description: String?
    let icon: String
    let iconGradient: LinearGradient
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with circular gradient background
                ZStack {
                    Circle()
                        .fill(iconGradient)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Title & Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    if let description = description {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(ThemeColors.secondaryText)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Radio Button indicator
                ZStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ThemeColors.accent)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 20))
                            .foregroundColor(Color.gray.opacity(0.5))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 25/255, green: 30/255, blue: 40/255))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? ThemeColors.accent : Color.white.opacity(0.05), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

struct RadioGridCard: View {
    let title: String
    let icon: String?
    let iconGradient: LinearGradient?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon, let gradient = iconGradient {
                    ZStack {
                        Circle()
                            .fill(gradient)
                            .frame(width: 24, height: 24)
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : ThemeColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ThemeColors.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color(red: 25/255, green: 30/255, blue: 40/255) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? ThemeColors.accent : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Activity Insights Card
struct InsightCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let iconColors: [Color]
    
    var body: some View {
        HStack(spacing: 0) {
            // Left colored border
            Rectangle()
                .fill(LinearGradient(colors: iconColors, startPoint: .top, endPoint: .bottom))
                .frame(width: 5)
            
            // Content
            VStack(alignment: .center, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold)) // Increased size
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium)) // Slightly larger title
                    .foregroundColor(ThemeColors.secondaryText)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ThemeColors.accent.opacity(0.8))
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity) // Ensures content centers within the available space
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
        }
        .background(Color(red: 25/255, green: 30/255, blue: 40/255))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Color Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        #if os(macOS)
        guard let color = NSColor(self).usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #endif
    }
}