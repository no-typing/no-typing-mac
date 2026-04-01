import SwiftUI

// MARK: - Section Header

/// A reusable section header with a title and optional description text.
/// Used across all settings views for consistent heading styling.
struct SectionHeaderView: View {
    let title: String
    var description: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            if let description = description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
        }
    }
}

// MARK: - Page Title Header

/// A large page-level title with optional subtitle, used at the top of settings sections.
struct PageTitleView: View {
    let title: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Text Field

/// A styled text field with a dark background, subtle border, and rounded corners.
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .padding()
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Secure Field

/// A styled secure field with a dark background, subtle border, and rounded corners.
struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        SecureField(placeholder, text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .padding()
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Primary Button

/// A filled primary action button with optional loading state.
/// Uses `ThemeColors.accent` when enabled, gray when disabled.
struct PrimaryButton: View {
    let title: String
    var loadingTitle: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(isLoading ? (loadingTitle ?? title) : title)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isDisabled ? Color.gray.opacity(0.3) : ThemeColors.accent)
            .foregroundColor(isDisabled ? .gray : .white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button

/// A subtle secondary button with a translucent background.
struct SecondaryButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Icon Button

/// A plain icon-only button, useful for toolbar-style actions.
struct IconButton: View {
    let iconName: String
    var color: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - API Key Test Status

/// A small inline status indicator used after testing API keys.
struct APIKeyStatusView: View {
    let status: String
    let isSuccess: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isSuccess ? .green : .red)
            
            Text(status)
                .font(.caption)
                .foregroundColor(isSuccess ? .green : .red)
        }
        .transition(.opacity)
    }
}

// MARK: - Search Bar

/// A reusable search bar with icon, clear button, and dark background.
struct SearchBar: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ThemeColors.secondaryText)
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ThemeColors.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Section Divider

/// A standard section divider with vertical padding used between settings groups.
struct SectionDivider: View {
    var body: some View {
        Divider().padding(.vertical, 8)
    }
}

// MARK: - Settings Section Container

/// Groups a section icon, title, description, and child content into a standard settings block.
struct SettingsSectionView<Content: View>: View {
    let icon: String
    let title: String
    var description: String? = nil
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                Text(title)
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            if let description = description {
                Text(description)
                    .font(.body)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            content
        }
    }
}
