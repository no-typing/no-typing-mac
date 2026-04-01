<div align="center">
  <img src="assets/icon.png" alt="No-Typing Icon" width="120" height="120">
  
  # No-Typing - Open Source Speech-to-Text for macOS
</div>

No-Typing is a powerful, open-source macOS application that provides fast speech-to-text transcription. Replace typing with natural speech - just hold down a hotkey, speak, and watch your words appear instantly. It supports both **Local, privacy-first AI** via Whisper, and **Lightning-fast Cloud AI** via top providers.

## Key Features

### Flexible Recording Modes
- **Push-to-Talk Mode**: Hold the hotkey to record, release to transcribe and insert text. Perfect for quick thoughts and commands.
- **Streaming Mode**: Press hotkey to start recording, press again to stop. Ideal for longer dictation sessions.

### Bring Your Own AI Models
- **Local Transcriptions**: Runs completely offline using Whisper AI. No data leaves your Mac, ensuring maximum privacy.
- **Cloud Transcriptions**: Supercharge your speed and accuracy using top-tier Cloud providers like OpenAI, Deepgram, Anthropic, and Groq by bringing your own API keys.
- **Cloud Translation**: Seamlessly translate spoken words into other languages using DeepL integration.

### Native macOS Integration
- **Accessibility Integration**: Transcribed text is seamlessly inserted directly into whatever app you are currently using.
- **System-wide Hotkey**: Works anywhere, anytime.

### Privacy Focused & Open Source
- Your data remains yours. Inspect the codebase freely, and rest easy knowing we don't harvest your data. Use local models for air-gapped security, or your own secure API keys for cloud providers.

## Installation

### Download Pre-built App
1. Go to our [GitHub Releases](https://github.com/no-typing/no-typing-mac/releases) page and download the latest `.dmg` file.
2. Open the DMG and drag No-Typing to your Applications folder.
3. Launch No-Typing and follow the onboarding wizard to grant the necessary Microphone and Accessibility permissions.

### Build from Source
```bash
git clone https://github.com/no-typing/no-typing-mac.git
cd no-typing-mac
open "no_typing.xcodeproj"
```
Select the `no_typing MacOS` scheme in Xcode, choose your local Mac as the run destination, and hit `⌘R`.

## Contributing
We love our open-source community! Whether you want to fix a bug, add a new cloud provider, or improve the UI, please see our [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to set up your development environment and submit pull requests.

## Acknowledgments
- [OpenAI Whisper](https://github.com/openai/whisper) 
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) for the efficient C++ implementation

## License
No-Typing is released under the MIT License. See the LICENSE file for details.