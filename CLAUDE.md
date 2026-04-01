# CLAUDE.md

This file provides architectural guidance for AI assistants (like Claude, Gemini, ChatGPT) when working with the No-Typing repository. Use this to orient yourself within the codebase.

## 🏗️ Architecture Overview

No-Typing is a macOS native application written in Swift and SwiftUI. It bridges low-level audio recording and system-hooking APIs with modern SwiftUI interfaces.

### Core Services Structure

- **`WhisperManager.swift`**: Handles the downloading and file management of local Whisper AI models.
- **`CloudTranscriptionManager.swift`**: Manages API-based transcription requests to third-party providers (OpenAI, Deepgram, Anthropic, Groq, DeepL).
- **`AudioManager.swift`**: Interfaces with `AVFoundation` for capturing multi-channel microphone input.
- **`AudioTranscriptionService.swift`**: The orchestrator that routes captured audio to either the local Whisper pipeline or the selected cloud provider based on the user's `@AppStorage` preferences.
- **`TextInsertionService.swift`**: Core utility that utilizes macOS Accessibility APIs (`AXUIElement`) to simulate typing or pasting transcribed text directly into the user's active application.
- **`GlobalHotkeyManager.swift`**: Detects system-wide keyboard events (like the `Option` or `Fn` key) even when the app is in the background, relying on Accessibility permissions.

### UI Architecture

- **`UnifiedSettingsView.swift`**: The main settings window containing organized tabs for Models, Cloud Services, General settings, Shortcuts, and Support.
- **`UIComponents.swift`** (`no_typing MacOS/Components/Common/UIComponents.swift`): Centralized repository of reusable SwiftUI components (`CustomTextField`, `PrimaryButton`, `SectionHeaderView`, `SettingsSectionView`). **Always use these components for new views to maintain visual consistency.**
- **`OnboardingView.swift`**: Multi-step SwiftUI view that guides users through granting permissions (Microphone & Accessibility) and downloading local models.
- **`HUDMainComponent.swift`**: The floating UI interface that appears dynamically when the hotkey is triggered.

## 🛠️ Build Information

```bash
# Build the macOS app via command line
xcodebuild -scheme "no_typing MacOS" -configuration Debug build
```

The app relies heavily on Apple Silicon / macOS Foundation frameworks and `whisper.cpp` integrations under the hood for local processing.

## 🧹 Codebase Rules & AI Agent Instructions

1. **Permissions Matter**: The app relies fundamentally on macOS `Accessibility` and `Microphone` permissions. When modifying initialization code or hotkey behaviors, ensure permission checks (via `PermissionManager.swift`) are not bypassed or broken.
2. **State Management Protocol**: The app uses `ObservableObject` and `@Published` properties for shared services (singletons like `WhisperManager.shared`), and `@AppStorage` for persisting UI state and user settings. Avoid tight coupling between services.
3. **Open Source & Privacy First**: Do not commit secrets, API keys, or proprietary backend integrations. The app allows users to supply their own API keys via the settings UI ("BYOK - Bring Your Own Key").
4. **No Legacy Authentication**: The app is strictly offline-first or BYOK. In previous iterations, proprietary OAuth/backend sign-in flows existed. These have been deleted. Do not re-introduce centralized user authentication mechanisms or user database integrations.
5. **Component Reusability**: When asked to create or refactor settings screens, aggressively use the components defined in `UIComponents.swift`. Avoid inline `.padding()`, `.background()`, or `.cornerRadius()` modifiers if a pre-built component handles it.