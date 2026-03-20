import SwiftUI

struct TranscriptDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var item: TranscriptionHistoryItem
    
    @State private var isCompactMode = false
    @State private var searchText = ""
    @State private var localSegments: [WhisperTranscriptionSegment] = []
    @State private var rawText: String = ""
    @State private var timeOffsetString: String = ""
    @State private var playerURL: URL? = nil
    
    // Sync Timeline
    @State private var currentTime: TimeInterval = 0
    let playerTimePublisher = NotificationCenter.default.publisher(for: NSNotification.Name("AVPlayerTimeUpdated"))
    
    // Translation State
    @State private var isTranslating = false
    @State private var translationLanguage = "DE"
    
    var onUpdate: (TranscriptionHistoryItem) -> Void
    var onClose: (() -> Void)?
    
    init(item: TranscriptionHistoryItem, onUpdate: @escaping (TranscriptionHistoryItem) -> Void, onClose: (() -> Void)? = nil) {
        self._item = State(initialValue: item)
        self.onUpdate = onUpdate
        self.onClose = onClose
        
        let initialSegments = item.segments ?? []
        self._localSegments = State(initialValue: initialSegments)
        self._rawText = State(initialValue: item.text)
        
        // If there are no segments, force compact mode
        if initialSegments.isEmpty {
            self._isCompactMode = State(initialValue: true)
        }
        
        let initialOffset = item.timeOffset ?? 0
        self._timeOffsetString = State(initialValue: Self.formatOffsetForInput(initialOffset))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if let url = playerURL {
                AVPlayerControlsView(
                    url: url,
                    segments: item.segments ?? [],
                    timeOffset: item.timeOffset ?? 0
                )
                .frame(height: 320)
                
                Divider()
                    .background(Color.white.opacity(0.1))
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            controlsView
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Content
            if isCompactMode {
                compactTextView
            } else {
                segmentsView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            resolveBookmarkIfAvailable()
        }
        .onDisappear {
            saveChanges()
            if let url = playerURL {
                url.stopAccessingSecurityScopedResource()
            }
        }
        .onReceive(playerTimePublisher) { notification in
            if let time = notification.userInfo?["time"] as? Double {
                self.currentTime = time
            }
        }
    }
    
    // MARK: - Media Resolution
    private func resolveBookmarkIfAvailable() {
        guard let data = item.sourceMediaData else { return }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("Warning: Bookmark data for AVPlayer is stale.")
            }
            
            if url.startAccessingSecurityScopedResource() {
                self.playerURL = url
            } else {
                print("Failed to access security scoped resource for AVPlayer.")
            }
        } catch {
            print("Failed to resolve bookmark data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { 
                if let onClose = onClose {
                    onClose()
                } else {
                    presentationMode.wrappedValue.dismiss() 
                }
            }) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.blue)
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(item.timestamp, style: .date)
                    .font(.headline)
                if let duration = item.duration {
                    Text(formatDuration(duration))
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Controls
    private var controlsView: some View {
        HStack {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ThemeColors.secondaryText)
                TextField("Search transcript...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
            
            // Start Time Offset
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(ThemeColors.secondaryText)
                TextField("Offset (00:00:00)", text: $timeOffsetString)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 80)
                    .onChange(of: timeOffsetString) { newValue in
                        let parsed = Self.parseOffsetFromInput(newValue)
                        item.timeOffset = parsed
                    }
            }
            .padding(8)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
            
            // Translate Control
            if DeepLManager.shared.hasValidKey {
                Menu {
                    let languages = ["DE": "German", "FR": "French", "ES": "Spanish", "IT": "Italian", "NL": "Dutch", "PL": "Polish", "PT-BR": "Portuguese (BR)"]
                    ForEach(Array(languages.keys.sorted()), id: \.self) { key in
                        Button(action: {
                            translationLanguage = key
                            translateText()
                        }) {
                            Text(languages[key] ?? key)
                        }
                    }
                } label: {
                    HStack {
                        if isTranslating {
                            ProgressView()
                                .controlSize(.small)
                            Text("Translating...")
                                .foregroundColor(ThemeColors.secondaryText)
                        } else {
                            Image(systemName: "globe")
                                .foregroundColor(ThemeColors.secondaryText)
                            Text("Translate")
                                .foregroundColor(ThemeColors.secondaryText)
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding(8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
                .disabled(isTranslating)
            }
            
            Spacer()
            
            // Mode Toggle
            if !(item.segments?.isEmpty ?? true) {
                Toggle("Compact", isOn: $isCompactMode)
                    .toggleStyle(.switch)
                    .labelsHidden()
                
                Text(isCompactMode ? "Compact" : "Segments")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
                    .frame(width: 70, alignment: .leading)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Filtered Segments
    private var filteredSegments: [WhisperTranscriptionSegment] {
        if searchText.isEmpty {
            return localSegments
        }
        return localSegments.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Views
    private var compactTextView: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if !searchText.isEmpty {
                    HighlightedText(text: rawText, highlighted: searchText)
                        .font(.body)
                        .padding()
                } else {
                    TextEditor(text: $rawText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding()
                        .onChange(of: rawText) { _ in
                            // Sync raw text down to a modified state if necessary.
                            // Due to simplicity, changing raw text overrides segments temporarily.
                            item.text = rawText
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var segmentsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach($localSegments) { $segment in
                    // Only show if it matches search
                    if searchText.isEmpty || segment.text.localizedCaseInsensitiveContains(searchText) {
                        let isActive = (segment.startTime...segment.endTime).contains(currentTime)
                        
                        SegmentRowView(
                            segment: $segment,
                            searchText: searchText,
                            timeOffset: item.timeOffset ?? 0,
                            isActive: isActive,
                            onDelete: {
                                deleteSegment(id: segment.id)
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func deleteSegment(id: UUID) {
        localSegments.removeAll { $0.id == id }
    }
    
    private func saveChanges() {
        // Re-construct the full text from the segments if we were in segment mode and segments exist
        if !isCompactMode && !localSegments.isEmpty {
            let combinedText = localSegments.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: " ")
            item.text = combinedText
            rawText = combinedText
        } else {
            // We were in compact mode, `rawText` holds the truth.
            item.text = rawText
        }
        
        item.segments = localSegments
        
        // Recalculate word count
        let words = item.text.split { $0.isWhitespace || $0.isPunctuation }.count
        item.wordCount = words
        
        onUpdate(item)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "0:00"
    }
    
    // MARK: - Translation Action
    private func translateText() {
        guard !rawText.isEmpty else { return }
        
        isTranslating = true
        let targetLang = translationLanguage
        
        Task {
            do {
                if var segments = item.segments, !segments.isEmpty {
                    // Batch process segments to avoid DeepL payload limits
                    let batchSize = 40
                    for i in stride(from: 0, to: segments.count, by: batchSize) {
                        let end = min(i + batchSize, segments.count)
                        let chunk = Array(segments[i..<end])
                        let textsToTranslate = chunk.map { $0.text }
                        
                        let translatedChunk = try await DeepLManager.shared.translate(texts: textsToTranslate, targetLanguage: targetLang)
                        
                        for (idx, translation) in translatedChunk.enumerated() {
                            if idx < translatedChunk.count {
                                segments[i + idx].translatedText = translation
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.item.segments = segments
                        self.isTranslating = false
                        self.saveChanges()
                    }
                } else {
                    // Fallback to bulk raw text if no segments exist
                    let textToTranslate = self.rawText
                    let translated = try await DeepLManager.shared.translate(text: textToTranslate, targetLanguage: targetLang)
                    
                    DispatchQueue.main.async {
                        self.rawText += "\n\n--- Translation (\(targetLang)) ---\n\n\(translated)"
                        self.item.text = self.rawText
                        self.isTranslating = false
                        self.isCompactMode = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isTranslating = false
                    print("Translation error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Offset Helpers
    
    static func parseOffsetFromInput(_ input: String) -> TimeInterval {
        let components = input.split(separator: ":").map { String($0) }
        var totalSeconds: TimeInterval = 0
        
        if components.count == 3 {
            // HH:MM:SS
            let hours = TimeInterval(components[0]) ?? 0
            let minutes = TimeInterval(components[1]) ?? 0
            let seconds = TimeInterval(components[2]) ?? 0
            totalSeconds = (hours * 3600) + (minutes * 60) + seconds
        } else if components.count == 2 {
            // MM:SS
            let minutes = TimeInterval(components[0]) ?? 0
            let seconds = TimeInterval(components[1]) ?? 0
            totalSeconds = (minutes * 60) + seconds
        } else if components.count == 1 {
            // SS
            totalSeconds = TimeInterval(components[0]) ?? 0
        }
        
        return totalSeconds
    }
    
    static func formatOffsetForInput(_ time: TimeInterval) -> String {
        guard time > 0 else { return "" }
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
}

// MARK: - Segment Row View
struct SegmentRowView: View {
    @Binding var segment: WhisperTranscriptionSegment
    var searchText: String
    var timeOffset: TimeInterval = 0
    var isActive: Bool = false
    var onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            VStack(alignment: .leading) {
                Text(formatTimestamp(segment.startTime + timeOffset))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(isActive ? ThemeColors.accent : ThemeColors.secondaryText)
                
                Text(formatTimestamp(segment.endTime + timeOffset))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(isActive ? ThemeColors.accent.opacity(0.8) : ThemeColors.secondaryText.opacity(0.7))
            }
            .frame(width: 55, alignment: .leading)
            .padding(.top, 4)
            
            // Text Editor
            VStack(alignment: .leading, spacing: 0) {
                // Speaker Tagging
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption)
                        .foregroundColor((segment.speaker?.isEmpty == false) ? ThemeColors.accent : ThemeColors.secondaryText.opacity(0.5))
                    
                    TextField("Speaker (e.g. Interviewer)", text: Binding(
                        get: { segment.speaker ?? "" },
                        set: { newValue in segment.speaker = newValue.isEmpty ? nil : newValue }
                    ))
                    .font(.caption.weight(.medium))
                    .textFieldStyle(.plain)
                    .foregroundColor((segment.speaker?.isEmpty == false) ? ThemeColors.accent : ThemeColors.secondaryText)
                }
                .padding(.bottom, 2)
                .padding(.top, 2)
                
                if searchText.isEmpty {
                    TextEditor(text: $segment.text)
                        .font(.body)
                        .frame(minHeight: 30)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                } else {
                    HighlightedText(text: segment.text, highlighted: searchText)
                        .font(.body)
                        .padding(.top, 4)
                        .padding(.bottom, 6)
                }
                
                if let translated = segment.translatedText {
                    Text(translated)
                        .font(.body)
                        .foregroundColor(ThemeColors.accent)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 8)
                }
            }
            
            // Action Buttons
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: {
                        let current = segment.isStarred ?? false
                        segment.isStarred = !current
                    }) {
                        Image(systemName: (segment.isStarred ?? false) ? "star.fill" : "star")
                            .foregroundColor((segment.isStarred ?? false) ? .yellow : ThemeColors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            } else {
                // If starring is active but not hovering, show the yellow star anyway.
                if segment.isStarred == true {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .padding(.top, 4)
                } else {
                    Spacer().frame(width: 45) // Placeholder to prevent jumping
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isActive ? ThemeColors.accent.opacity(0.15) : 
                    ((segment.isStarred ?? false) ? Color.yellow.opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovering ? Color.blue.opacity(0.3) : (isActive ? ThemeColors.accent.opacity(0.5) : Color.clear), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    private func formatTimestamp(_ time: TimeInterval) -> String {
        let maxTime = Int(time)
        let minutes = (maxTime % 3600) / 60
        let seconds = (maxTime % 3600) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Highlighted Text Helper
struct HighlightedText: View {
    let text: String
    let highlighted: String

    var body: some View {
        guard !text.isEmpty && !highlighted.isEmpty else { return Text(text) }

        var attributedString = AttributedString(text)
        
        if let range = attributedString.range(of: highlighted, options: .caseInsensitive) {
            attributedString[range].backgroundColor = .yellow
            attributedString[range].foregroundColor = .black
        }
        
        return Text(attributedString)
    }
}
