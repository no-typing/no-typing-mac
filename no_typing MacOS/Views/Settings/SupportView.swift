import SwiftUI

struct SupportView: View {
    // TODO: Update this to your actual GitHub repository URL
    private let repoURL = "https://github.com/no-typing/no-typing-mac"
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header Section
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Support & Community")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("No-Typing is open source. Report issues, request features, or contribute on GitHub.")
                        .font(.body)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Quick Action Cards
            VStack(spacing: 12) {
                supportCard(
                    icon: "ant.fill",
                    iconColor: .red,
                    title: "Report a Bug",
                    description: "Found something broken? Open an issue on GitHub with steps to reproduce.",
                    buttonTitle: "Open Bug Report",
                    url: "\(repoURL)/issues/new?template=bug_report.md&labels=bug"
                )
                
                supportCard(
                    icon: "lightbulb.fill",
                    iconColor: .yellow,
                    title: "Request a Feature",
                    description: "Have an idea to improve No-Typing? We'd love to hear it.",
                    buttonTitle: "Open Feature Request",
                    url: "\(repoURL)/issues/new?template=feature_request.md&labels=enhancement"
                )
                
                supportCard(
                    icon: "text.bubble.fill",
                    iconColor: .blue,
                    title: "Discussions",
                    description: "Ask questions, share tips, or connect with other users.",
                    buttonTitle: "Join Discussions",
                    url: "\(repoURL)/discussions"
                )
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Repository Link
            HStack(spacing: 12) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Source Code")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(repoURL)
                        .font(.system(size: 12))
                        .foregroundColor(ThemeColors.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                SecondaryButton(title: "View on GitHub") {
                    if let url = URL(string: repoURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Version Info
            HStack {
                Spacer()
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("No-Typing v\(version) (\(build))")
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(.top, 16)
        .background(Color.clear)
    }
    
    @ViewBuilder
    private func supportCard(icon: String, iconColor: Color, title: String, description: String, buttonTitle: String, url: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            SecondaryButton(title: buttonTitle) {
                if let issueURL = URL(string: url) {
                    NSWorkspace.shared.open(issueURL)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}