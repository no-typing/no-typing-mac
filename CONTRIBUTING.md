# Contributing to No-Typing

Thank you for your interest in contributing to No-Typing! We're building the best open-source speech-to-text tool for macOS, and community contributions are highly valued. Whether it's adding a new cloud provider, fixing a bug, or polishing the UI, we're excited to see what you build.

## 🐛 Reporting Bugs
Before creating bug reports, please check existing GitHub issues to avoid duplicates. If you create a new bug report, include:
* A clear and descriptive title
* Exact steps to reproduce the issue
* Expected vs. actual behavior
* Your macOS version and Mac hardware (Intel or Apple Silicon)
* Screenshots or videos (if applicable)

## 💡 Suggesting Enhancements
We track feature requests as GitHub issues. Please provide:
* A clear and descriptive title
* Details of the proposed enhancement and why it is useful to the broader community
* Any potential UI/UX examples or mockups

## 🛠️ Development Setup

1. **Fork the Repository**: Create your own fork and clone it locally.
2. **Open the Project**: Open `no_typing.xcodeproj` in Xcode (requires Xcode 15+).
3. **Configure Signing**: Select the project target (`no_typing MacOS`), go to the "Signing & Capabilities" tab, and select your Personal Team for local development.
4. **Dependencies**: All package dependencies are managed natively through Swift Package Manager within Xcode.
5. **Build and Run**: Select the `no_typing MacOS` scheme and press `⌘R`.

### UI Component Guidelines
We use centralized, reusable SwiftUI components to ensure visual consistency across the app. When building new settings screens or UI elements:
* Use components from `no_typing MacOS/Components/Common/UIComponents.swift` (e.g., `CustomTextField`, `PrimaryButton`, `SectionHeaderView`).
* Stick to the colors provided in `ThemeColors` located in `CommonViews.swift` rather than hardcoding colors.

### Adding Cloud Providers
If integrating a new transcription or translation provider (e.g. Gemini, Azure, etc.):
* Add the logic inside the `Services/` directory, following existing patterns found in `CloudTranscriptionManager.swift`.
* Provide a configuration view in the Settings menu that uses secure `@AppStorage` for storing user-provided API keys. Keep the UI consistent by adapting `UIComponents`.

## 🔀 Pull Request Process
1. Create a feature branch: `git checkout -b feature/my-new-feature` or `git checkout -b fix/issue-name`.
2. Commit your changes logically with clean, descriptive commit messages.
3. Push your branch to your fork.
4. Open a Pull Request against our `main` branch.
5. Ensure your code compiles without warnings, follows the existing Swift code style, and doesn't break core app permissions.

## 🎨 Code Style Guides
### Swift
* Use 4 spaces for indentation.
* Prefer standard SwiftUI constructs (`VStack`, `HStack`, etc.).
* Separate business logic (Services/Managers) from UI components (Views).
* Use `@AppStorage` for persisting lightweight user preferences securely.

We look forward to reviewing your PR!