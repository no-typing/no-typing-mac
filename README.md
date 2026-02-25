<div align="center">
  <img src="assets/icon.png" alt="No-Typing Icon" width="120" height="120">
  
  # No-Typing - Local Speech-to-Text for macOS
</div>

No-Typing is a powerful macOS application that runs Whisper AI locally to provide fast, private speech-to-text transcription. Replace typing with natural speech - just hold a hotkey, speak, and watch your words appear instantly.

## Key Features

### 🎯 Smart Voice Activity Detection
- Only transcribes when you're actually speaking
- Filters out background noise (TV, music, conversations)
- Visual feedback shows when speech is detected via HUD effects

### 🎙️ Two Recording Modes

**Manual Mode**
- Hold hotkey to record
- Release to transcribe and insert text
- Perfect for quick thoughts and commands

**Streaming Mode**
- Toggle recording on/off with hotkey
- Automatically detects pauses in speech
- Configurable pause detection duration
- Inserts text segment-by-segment
- Ideal for quiet environments and longer dictation

### 🤖 AI-Powered Text Processing
- Leverages macOS 15's foundation models
- Rewrite transcribed text in different tones
- Multiple tone options available

### 🔐 Privacy First
- Runs entirely offline using local Whisper models
- No data leaves your device
- Your speech stays private

### ⚡ Native macOS Integration
- Seamless text insertion into any app
- App-aware functionality
- Accessibility API integration
- System-wide hotkey support

## Installation

### Download Pre-built App

1. Download the latest release from [no_typing.com](https://www.no_typing.com/)
2. Open the DMG and drag No-Typing to Applications
3. Launch No-Typing and grant necessary permissions:
   - Microphone access
   - Accessibility permissions
   - Dictation permissions

### Building from Source

To run No-Typing locally on your Mac:

1. **Clone the repository**
   ```bash
   git clone https://github.com/GiddyNaya/no_typing.git
   cd no_typing
   ```

2. **Open in Xcode**
   ```bash
   open no_typing.xcodeproj
   ```

3. **Configure signing**
   - Select the project in Xcode
   - Go to "Signing & Capabilities" tab
   - Select your development team
   - Xcode will automatically manage the provisioning profile

4. **Select the target**
   - Choose "no_typing MacOS" scheme from the dropdown
   - Select your Mac as the destination

5. **Build and run**
   - Press `⌘R` or click the Run button
   - The app will build and launch automatically

## Usage

1. **Set your hotkey** in Settings (default: Option key)
2. **Select recording mode**:
   - Manual: Hold hotkey → Speak → Release
   - Streaming: Press hotkey → Speak naturally → Press again to stop

## Building from Source

```bash
# Clone the repository
git clone https://github.com/GiddyNaya/no_typing.git
cd no_typing

# Open in Xcode
open no_typing.xcodeproj

# Build for macOS
xcodebuild -scheme "no_typing MacOS" -configuration Release build
```

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow existing Swift/SwiftUI patterns
- Add tests for new features
- Update documentation
- Keep privacy and offline-first principles

## Technical Stack

- **Language**: Swift/SwiftUI
- **AI Model**: Whisper (via whisper.cpp)
- **Platforms**: macOS 14+, iOS support in progress
- **Key Frameworks**: AVFoundation, Accessibility, Speech

## Acknowledgments

- [OpenAI Whisper](https://github.com/openai/whisper) for the amazing speech recognition model
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) for the efficient C++ implementation
- All our contributors and community members

---

<div align="center">
  <img src="assets/icon.png" alt="No-Typing Icon" width="80" height="80">
  
  Built with ❤️ by the No-Typing developers. Let's revolutionize how we interact with our computers through speech!
</div>