import SwiftUI
import UniformTypeIdentifiers

enum TranscribeMode {
    case local, url
}

struct SocialIcon: View {
    var name: String
    var title: String
    var isSystem: Bool = true
    var isActive: Bool = false
    var activeColor: Color = ThemeColors.accent
    
    var body: some View {
        HStack(spacing: 4) {
            if isSystem {
                Image(systemName: name)
            } else {
                Text(name) // for custom emojis
            }
            Text(title)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(isActive ? .white : .white.opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .opacity(isActive ? 1 : 0.5)
        .background(isActive ? activeColor : Color.white.opacity(0.1))
        .cornerRadius(6)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

class PastingNSTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown && event.modifierFlags.contains(.command) {
            let key = event.charactersIgnoringModifiers
            
            if key == "x" {
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
            } else if key == "c" {
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
            } else if key == "v" {
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
            } else if key == "z" {
                if NSApp.sendAction(Selector(("undo:")), to: nil, from: self) { return true }
            } else if key == "a" {
                if NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: self) { return true }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// macOS specific TextField wrapper to easily support standard Cmd+C / Cmd+V copy pasting
struct CopyPastingTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = PastingNSTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 14)
        textField.textColor = NSColor.white
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CopyPastingTextField

        init(_ parent: CopyPastingTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return true // handled
            }
            return false
        }
    }
}

struct TranscribeFileView: View {
    @StateObject private var manager = FileTranscriptionManager.shared
    @StateObject private var ytdlpManager = YTDLPManager.shared
    
    @State private var isHoveringUpload = false
    @State private var hoveredCopied = false
    @State private var downloadProgress: Double = 0.0
    
    @State private var transcribeMode: TranscribeMode = .url
    @State private var urlInput: String = ""
    @State private var metadata: YTDLPMetadata? = nil
    @State private var isFetchingMetadata: Bool = false
    @State private var urlErrorMessage: String? = nil
    
    var body: some View {
// ... existing UI ...
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcribe Media")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Upload an audio/video file or paste a social media link to generate a transcription offline.")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                // Mode Toggle
                HStack(spacing: 0) {
                    Button(action: { 
                        withAnimation { transcribeMode = .url }
                    }) {
                        Text("URL Link")
                            .font(.system(size: 13, weight: transcribeMode == .url ? .semibold : .medium))
                            .foregroundColor(transcribeMode == .url ? .white : .white.opacity(0.6))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .background(transcribeMode == .url ? ThemeColors.accent : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { 
                        withAnimation { transcribeMode = .local }
                    }) {
                        Text("Local File")
                            .font(.system(size: 13, weight: transcribeMode == .local ? .semibold : .medium))
                            .foregroundColor(transcribeMode == .local ? .white : .white.opacity(0.6))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .background(transcribeMode == .local ? ThemeColors.accent : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05)))
            }
            .padding(.bottom, 8)
            
            // Input Mode Views
            if transcribeMode == .url {
                urlLinkView
            } else {
                localFileView
            }
            
            // Error Message
            if let error = manager.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.system(size: 13))
            }
            
            // Output Box
            if !manager.transcribedText.isEmpty {
                outputBox
            } else {
                Spacer()
            }
        }
    }
    
    // MARK: - Local File View
    private var localFileView: some View {
        Button(action: {
            if !manager.isTranscribing {
                selectFile()
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(isHoveringUpload ? ThemeColors.accent : Color.white.opacity(0.1))
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(16)
                
                VStack(spacing: 12) {
                    Image(systemName: manager.isTranscribing ? "hourglass" : "arrow.up.doc")
                        .font(.system(size: 32))
                        .foregroundColor(isHoveringUpload && !manager.isTranscribing ? ThemeColors.accent : .white.opacity(0.5))
                        .symbolEffect(.pulse, options: .repeating, isActive: manager.isTranscribing)
                    
                    Text(manager.isTranscribing ? "Transcribing \(manager.currentFileName ?? "File")..." : "Click to select an audio file")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    if manager.isTranscribing {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle(tint: ThemeColors.accent))
                            .padding(.horizontal, 60)
                            .padding(.top, 4)
                    } else {
                        Text("MP3, WAV, M4A, MP4")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .frame(height: 160)
        }
        .buttonStyle(.plain)
        .onHover { isHoveringUpload = $0 }
        .disabled(manager.isTranscribing)
        .onDrop(of: [.fileURL], isTargeted: $isHoveringUpload) { providers in
            guard !manager.isTranscribing else { return false }
            
            guard let provider = providers.first else { return false }
            
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.manager.transcribeFile(url: url)
                }
            }
            
            return true
        }
    }
    
    // Helper to extract root domain
    private func activeDomainMatches(_ keywords: [String]) -> Bool {
        let lowerUrl = urlInput.lowercased()
        return keywords.contains(where: { lowerUrl.contains($0) })
    }
    
    // MARK: - URL Link View
    private var urlLinkView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Social Icons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SocialIcon(name: "play.rectangle.fill", title: "YouTube", isActive: activeDomainMatches(["youtube", "youtu.be"]), activeColor: Color.red)
                    SocialIcon(name: "🎵", title: "TikTok", isSystem: false, isActive: activeDomainMatches(["tiktok"]), activeColor: Color(hex: "fe2c55"))
                    SocialIcon(name: "camera.fill", title: "Instagram", isActive: activeDomainMatches(["instagram"]), activeColor: Color(hex: "be00e8"))
                    SocialIcon(name: "person.2.fill", title: "Facebook", isActive: activeDomainMatches(["facebook", "fb.watch"]), activeColor: Color(hex: "0645d6"))
                    SocialIcon(name: "video.fill", title: "Vimeo", isActive: activeDomainMatches(["vimeo"]), activeColor: Color(hex: "029ee0"))
                    SocialIcon(name: "link", title: "Direct Link", isActive: urlInput.contains("http") && !activeDomainMatches(["youtube", "youtu.be", "tiktok", "instagram", "facebook", "fb.watch", "vimeo"]), activeColor: ThemeColors.accent)
                }
            }
            .padding(.bottom, 4)
            
            if ytdlpManager.isDownloadingBinary {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Downloading media engine...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle(tint: ThemeColors.accent))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
            } else {
                CopyPastingTextField(placeholder: "Paste link here...", text: $urlInput)
                    .frame(height: 18) // standard textfield height matching
                    .padding(14)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .onChange(of: urlInput) { newValue in
                        handleURLInput(newValue)
                    }
                
                if isFetchingMetadata {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                        Text("Analyzing link...")
                            .font(.system(size: 13))
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                    .padding(.top, 4)
                } else if let error = urlErrorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.top, 4)
                } else if let md = metadata {
                    // Preview Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            if let thumb = md.thumbnail, let tURL = URL(string: thumb) {
                                AsyncImage(url: tURL) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle().fill(Color.black.opacity(0.3)).frame(width: 120, height: 68)
                                            .overlay(ProgressView().scaleEffect(0.5))
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill).frame(width: 120, height: 68).clipped()
                                    case .failure:
                                        Rectangle().fill(Color.black.opacity(0.3)).frame(width: 120, height: 68)
                                            .overlay(Image(systemName: "photo").foregroundColor(.white.opacity(0.5)))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .cornerRadius(8)
                            } else {
                                Rectangle().fill(Color.black.opacity(0.3)).frame(width: 120, height: 68)
                                    .overlay(Image(systemName: "video").foregroundColor(.white.opacity(0.5)))
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(md.title ?? "Unknown Video")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                if let uploader = md.uploader {
                                    Text(uploader)
                                        .font(.system(size: 13))
                                        .foregroundColor(ThemeColors.secondaryText)
                                }
                            }
                            Spacer()
                        }
                        
                        Button(action: {
                            startURLTranscription()
                        }) {
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: manager.isTranscribing ? "hourglass" : "play.fill")
                                    Text(manager.isTranscribing ? "Transcribing \(md.title?.prefix(15) ?? "Video")..." : "Transcribe Media")
                                }
                                if manager.isTranscribing && downloadProgress > 0.0 && downloadProgress < 1.0 {
                                    ProgressView(value: downloadProgress, total: 1.0)
                                        .progressViewStyle(LinearProgressViewStyle(tint: Color.white))
                                        .scaleEffect(y: 0.5, anchor: .center)
                                        .padding(.horizontal, 32)
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, downloadProgress > 0.0 && downloadProgress < 1.0 ? 8 : 14)
                            .background(manager.isTranscribing ? Color.white.opacity(0.2) : ThemeColors.accent)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(manager.isTranscribing)
                    }
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
                }
            }
        }
    }
    
    // MARK: - Output Box View
    private var outputBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transcription Result")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    Button(action: {
                        manager.clearResult()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Clear")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundColor(.red.opacity(0.9))
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(manager.transcribedText, forType: .string)
                        withAnimation { hoveredCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { hoveredCopied = false }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: hoveredCopied ? "checkmark" : "doc.on.doc")
                            Text(hoveredCopied ? "Copied" : "Copy")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            ScrollView {
                Text(manager.transcribedText)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
                    .textSelection(.enabled)
            }
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .frame(minHeight: 200, maxHeight: 400)
        }
    }
    
    // MARK: - Handlers
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.audio, UTType.mpeg4Audio, UTType.wav, UTType.mp3,
            UTType.movie, UTType.mpeg4Movie, UTType.quickTimeMovie
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            manager.transcribeFile(url: url)
        }
    }
    
    private func handleURLInput(_ rawString: String) {
        let cleanString = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleanString), url.host != nil else {
            metadata = nil
            urlErrorMessage = nil
            return
        }
        
        isFetchingMetadata = true
        urlErrorMessage = nil
        metadata = nil
        
        ytdlpManager.fetchMetadata(for: cleanString) { result in
            DispatchQueue.main.async {
                self.isFetchingMetadata = false
                switch result {
                case .success(let md):
                    self.metadata = md
                case .failure(let error):
                    self.urlErrorMessage = "Could not identify media: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func startURLTranscription() {
        guard let md = metadata else { return }
        let link = urlInput
        
        manager.isTranscribing = true
        manager.errorMessage = nil
        manager.transcribedText = ""
        manager.currentFileName = "Downloading \(md.title ?? "Media")..."
        downloadProgress = 0.0
        
        ytdlpManager.downloadAudio(from: link, onProgress: { progress in
            self.downloadProgress = progress
        }) { result in
            DispatchQueue.main.async {
                self.downloadProgress = 1.0
                switch result {
                case .success(let url):
                    manager.isTranscribing = false
                    manager.currentFileName = md.title ?? "External Media"
                    manager.transcribeFile(url: url)
                case .failure(let error):
                    manager.isTranscribing = false
                    manager.currentFileName = nil
                    manager.errorMessage = "Failed to download media stream: \(error.localizedDescription)"
                }
            }
        }
    }
}
