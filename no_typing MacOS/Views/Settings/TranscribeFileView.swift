import SwiftUI
import UniformTypeIdentifiers

enum TranscribeMode {
    case local, url, podcast
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

// MARK: - Drop Delegate for Reordering
struct PodcastDropDelegate: DropDelegate {
    let itemIndex: Int
    @Binding var tracks: [URL]
    @Binding var speakers: [String]
    @Binding var draggingIndex: Int?

    func performDrop(info: DropInfo) -> Bool {
        draggingIndex = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let sourceIndex = draggingIndex else { return }
        guard sourceIndex != itemIndex else { return }
        
        withAnimation {
            let movedTrack = tracks.remove(at: sourceIndex)
            tracks.insert(movedTrack, at: itemIndex)
            
            if sourceIndex < speakers.count && itemIndex <= speakers.count {
                let movedSpeaker = speakers.remove(at: sourceIndex)
                speakers.insert(movedSpeaker, at: itemIndex)
            }
            draggingIndex = itemIndex
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - Podcast Track Row
private struct PodcastTrackRow: View {
    let index: Int
    let url: URL
    @Binding var speakerNames: [String]
    let onRemove: () -> Void
    let onAddSpeaker: (Int) -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    @ObservedObject private var speakerManager = SpeakerManager.shared
    
    private var currentName: String {
        index < speakerNames.count ? speakerNames[index] : "Unknown"
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.cyan)
                .font(.system(size: 16))
            
            Menu {
                ForEach(speakerManager.speakers, id: \.self) { speaker in
                    Button(action: {
                        if index < speakerNames.count {
                            speakerNames[index] = speaker
                        }
                    }) {
                        HStack {
                            if speaker == currentName {
                                Image(systemName: "checkmark")
                            }
                            Text(speaker)
                        }
                    }
                }
                
                if !speakerManager.speakers.isEmpty { Divider() }
                
                if !speakerManager.speakers.isEmpty {
                    Menu("Remove Speaker…") {
                        ForEach(speakerManager.speakers, id: \.self) { speaker in
                            Button(role: .destructive, action: {
                                speakerManager.remove(speaker)
                                for i in speakerNames.indices where speakerNames[i] == speaker {
                                    speakerNames[i] = "Unknown"
                                }
                            }) {
                                Text(speaker)
                            }
                        }
                    }
                    Divider()
                }
                
                Button(action: { onAddSpeaker(index) }) {
                    Label("Add New Speaker…", systemImage: "plus.circle")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundColor(ThemeColors.secondaryText)
                .lineLimit(1)
            Spacer()
            
            // Reorder controls
            if onMoveUp != nil || onMoveDown != nil {
                VStack(spacing: 6) {
                    Button(action: { onMoveUp?() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(onMoveUp != nil ? .white.opacity(0.8) : .white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .disabled(onMoveUp == nil)
                    
                    Button(action: { onMoveDown?() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(onMoveDown != nil ? .white.opacity(0.8) : .white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .disabled(onMoveDown == nil)
                }
                .padding(.horizontal, 4)
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}

struct TranscribeFileView: View {
    @StateObject private var manager = FileTranscriptionManager.shared
    @StateObject private var ytdlpManager = YTDLPManager.shared
    @StateObject private var webhookManager = WebhookManager.shared
    @StateObject private var whisperManager = WhisperManager.shared
    @ObservedObject private var speakerManager = SpeakerManager.shared
    @State private var fileWebhookEndpointId: String = UserDefaults.standard.string(forKey: "fileTranscriptionWebhookEndpointId") ?? ""
    
    @State private var isHoveringUpload = false
    @State private var hoveredCopied = false
    @State private var downloadProgress: Double = 0.0
    
    @State private var transcribeMode: TranscribeMode = .url
    @State private var urlInput: String = ""
    @State private var metadata: YTDLPMetadata? = nil
    @State private var isFetchingMetadata: Bool = false
    @State private var urlErrorMessage: String? = nil
    @State private var podcastTracks: [URL] = []
    @State private var podcastSpeakerNames: [String] = []
    @State private var showAdvancedOptions: Bool = false
    @State private var draggingPodcastIndex: Int? = nil
    
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
                    
                    Button(action: { 
                        withAnimation { transcribeMode = .podcast }
                    }) {
                        HStack(spacing: 4) {
                            Text("Podcast")
                                .font(.system(size: 13, weight: transcribeMode == .podcast ? .semibold : .medium))
                                .foregroundColor(transcribeMode == .podcast ? .white : .white.opacity(0.6))
                            Text("BETA")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(3)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .background(transcribeMode == .podcast ? ThemeColors.accent : Color.clear)
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
            } else if transcribeMode == .podcast {
                podcastView
            } else {
                localFileView
            }
            
            // Error Message
            if let error = manager.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.system(size: 13))
            }
            
            advancedOptionsCard

            // Output Box
            if !manager.transcribedText.isEmpty {
                outputBox
            } else {
                Spacer()
            }
        }
    }
    
    // MARK: - Advanced Options Card
    
    private var advancedOptionsCard: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showAdvancedOptions.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13))
                    Text("Advanced Options")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(ThemeColors.secondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.25))
            }
            .buttonStyle(.plain)
            
            if showAdvancedOptions {
                advancedOptionsContent
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07)))
        .padding(.bottom, 8)
    }
    
    private var advancedOptionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $manager.translateToEnglish) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                    Text("Translate to English")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(manager.translateToEnglish ? .white : ThemeColors.secondaryText)
            }
            .toggleStyle(.checkbox)
            
            // Transcription Service
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: manager.useCloudEngine ? "cloud.fill" : "desktopcomputer")
                        .font(.system(size: 14))
                        .foregroundColor(manager.useCloudEngine ? .cyan : ThemeColors.accent)
                    Text("Transcription Service")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    transcriptionServicePicker
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05)))
            
            // Webhook
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Forward to Webhook")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    webhookPicker
                }
                Text("Only manually transcribed media is sent to this endpoint. Voice webhook can be found under App Settings.")
                    .font(.system(size: 11))
                    .foregroundColor(ThemeColors.secondaryText)
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05)))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.35))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var transcriptionServicePicker: some View {
        Picker("Service", selection: Binding<String>(
            get: {
                manager.useCloudEngine ? manager.cloudProvider.rawValue : manager.selectedLocalModel
            },
            set: { newValue in
                if let provider = CloudTranscriptionProvider.allCases.first(where: { $0.rawValue == newValue }) {
                    manager.useCloudEngine = true
                    manager.cloudProvider = provider
                } else {
                    manager.useCloudEngine = false
                    manager.selectedLocalModel = newValue
                }
            }
        )) {
            let availableLocals = whisperManager.availableModels.filter { $0.isAvailable }
            if availableLocals.isEmpty {
                Text("Local (Not Downloaded)").tag("local_none")
            } else {
                ForEach(availableLocals) { model in
                    Text("\(model.displayInfo.displayName) (Local)").tag(model.id)
                }
            }
            
            Divider()
            
            ForEach(CloudTranscriptionProvider.allCases) { provider in
                Text(provider.rawValue).tag(provider.rawValue)
            }
        }
        .frame(width: 220)
    }
    
    private var webhookPicker: some View {
        Picker("Webhook", selection: Binding(
            get: { fileWebhookEndpointId },
            set: { newValue in
                fileWebhookEndpointId = newValue
                UserDefaults.standard.set(newValue, forKey: "fileTranscriptionWebhookEndpointId")
            }
        )) {
            Text("None").tag("")
            ForEach(webhookManager.endpoints) { endpoint in
                Text(endpoint.name).tag(endpoint.id.uuidString)
            }
        }
        .frame(width: 220)
    }
    
    // MARK: - Podcast View
    private var podcastView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    Text("Podcast Multi-Track")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                    Text("BETA")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                }
                Text("Select one audio file per host/speaker. Tracks will be combined and transcribed together.")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            // Track List
            ForEach(Array(podcastTracks.enumerated()), id: \.offset) { index, url in
                PodcastTrackRow(
                    index: index,
                    url: url,
                    speakerNames: $podcastSpeakerNames,
                    onRemove: {
                        podcastTracks.remove(at: index)
                        if index < podcastSpeakerNames.count {
                            podcastSpeakerNames.remove(at: index)
                        }
                    },
                    onAddSpeaker: { idx in promptAddSpeaker(forTrackIndex: idx) },
                    onMoveUp: index > 0 ? { swapPodcastTrack(from: index, to: index - 1) } : nil,
                    onMoveDown: index < podcastTracks.count - 1 ? { swapPodcastTrack(from: index, to: index + 1) } : nil
                )
                .onDrag {
                    self.draggingPodcastIndex = index
                    return NSItemProvider(object: url.absoluteString as NSString)
                }
                .onDrop(of: [.url, .text], delegate: PodcastDropDelegate(
                    itemIndex: index,
                    tracks: $podcastTracks,
                    speakers: $podcastSpeakerNames,
                    draggingIndex: $draggingPodcastIndex
                ))
            }
            
            HStack(spacing: 12) {
                Button(action: selectPodcastTrack) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Host Tracks")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                if podcastTracks.count >= 2 {
                    Button(action: {
                        PodcastTrackCombiner.shared.combineAndTranscribe(trackURLs: podcastTracks, speakerNames: podcastSpeakerNames)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.path")
                            Text("Combine & Transcribe")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(ThemeColors.accent)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(manager.isTranscribing)
                }
            }
            
            // Preloader + Cancel row — shown while transcribing
            if manager.isTranscribing {
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.75)
                            .frame(width: 18, height: 18)
                        Text("\(manager.currentPhase.isEmpty ? "Transcribing" : manager.currentPhase)... \(timeString(from: manager.elapsedTime))")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    
                    Button(action: {
                        manager.cancelTranscription()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }
    
    private func swapPodcastTrack(from source: Int, to destination: Int) {
        withAnimation {
            podcastTracks.swapAt(source, destination)
            if source < podcastSpeakerNames.count && destination < podcastSpeakerNames.count {
                podcastSpeakerNames.swapAt(source, destination)
            }
        }
    }
    
    private func selectPodcastTrack() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["mp3", "wav", "m4a", "ogg", "opus", "flac", "aac"]
        panel.title = "Select Host Audio Tracks"
        panel.message = "Choose the audio recordings for the podcast hosts."
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                podcastTracks.append(url)
                podcastSpeakerNames.append("Unknown")
            }
        }
    }
    
    private func promptAddSpeaker(forTrackIndex trackIndex: Int) {
        let alert = NSAlert()
        alert.messageText = "Add Speaker"
        alert.informativeText = "Enter a name for this speaker. They will be saved to your speaker list."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.placeholderString = "Speaker name..."
        input.bezelStyle = .roundedBezel
        alert.accessoryView = input
        
        alert.window.initialFirstResponder = input
        
        if alert.runModal() == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            speakerManager.add(name)
            if trackIndex < podcastSpeakerNames.count {
                podcastSpeakerNames[trackIndex] = name
            }
        }
    }
    
    // MARK: - Local File View
    private var localFileView: some View {
        VStack(spacing: 12) {
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
                        
                        if manager.isTranscribing {
                            let total = manager.totalInBatch
                            let remaining = manager.transcriptionQueue.count
                            let current = total - remaining
                            Text("Transcribing \(current) of \(total)...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text(manager.currentFileName ?? "File")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(ThemeColors.secondaryText)
                                .lineLimit(1)
                                .padding(.horizontal, 20)
                        } else {
                            Text("Click to select audio/video files")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
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
                
                var droppedURLs: [URL] = []
                let group = DispatchGroup()
                
                for provider in providers {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                        defer { group.leave() }
                        
                        guard let data = item as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) else {
                            return
                        }
                        droppedURLs.append(url)
                    }
                }
                
                group.notify(queue: .main) {
                    if !droppedURLs.isEmpty {
                        self.manager.queueFiles(droppedURLs)
                    }
                }
                
                return true
            }
            
            // Cancel / Timer row — shown only during transcription
            if manager.isTranscribing {
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                        Text("\(manager.currentPhase.isEmpty ? "Transcribing" : manager.currentPhase)... \(timeString(from: manager.elapsedTime))")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    
                    Button(action: {
                        manager.cancelTranscription()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
            }
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
                        
                        if manager.isTranscribing {
                            HStack(spacing: 8) {
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "hourglass")
                                        Text("\(manager.currentPhase) \(md.title?.prefix(15) ?? "Video")... \(timeString(from: manager.elapsedTime))")
                                    }
                                    if downloadProgress > 0.0 && downloadProgress < 1.0 {
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
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                                
                                Button(action: {
                                    manager.cancelTranscription()
                                    // if there was a download it won't be transcribed thanks to safety checks added below
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            }
                        } else {
                            Button(action: {
                                startURLTranscription()
                            }) {
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Transcribe Media")
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(ThemeColors.accent)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
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
                
                if manager.wordCount > 0 {
                    Text("• \(manager.wordCount) words")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                if manager.lastTranscriptionDuration > 0 {
                    Text("• \(timeString(from: manager.lastTranscriptionDuration))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
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
            .background(.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .frame(minHeight: 200, maxHeight: 400)
        }
        .onChange(of: manager.isTranscribing) { isTranscribing in
            if !isTranscribing {
                withAnimation { showAdvancedOptions = false }
            }
        }
    }
    
    // MARK: - Handlers
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.audio, UTType.mpeg4Audio, UTType.wav, UTType.mp3,
            UTType.movie, UTType.mpeg4Movie, UTType.quickTimeMovie
        ]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            let urls = panel.urls
            if !urls.isEmpty {
                manager.queueFiles(urls)
            }
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
    
    private func timeString(from time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
    
    private func startURLTranscription() {
        guard let md = metadata else { return }
        let link = urlInput

        // collapse the advanced options
        withAnimation {
            showAdvancedOptions = false
        }
        
        manager.isTranscribing = true
        manager.errorMessage = nil
        manager.transcribedText = ""
        manager.currentPhase = "Downloading"
        manager.currentFileName = "Downloading \(md.title ?? "Media")..."
        manager.startTimer()
        downloadProgress = 0.0
        
        ytdlpManager.downloadAudio(from: link, onProgress: { progress in
            self.downloadProgress = progress
        }) { result in
            DispatchQueue.main.async {
                self.downloadProgress = 1.0
                switch result {
                case .success(let url):
                    if !manager.isTranscribing { // User cancelled while downloading
                        try? FileManager.default.removeItem(at: url)
                        return
                    }
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
