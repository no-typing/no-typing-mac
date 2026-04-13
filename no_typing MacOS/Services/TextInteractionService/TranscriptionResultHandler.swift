import Foundation

class TranscriptionResultHandler {
    static let shared = TranscriptionResultHandler()
    
    
    // Block mode text accumulation
    private var accumulatedText: String = ""
    private var isBlockMode: Bool = false
    private let textFormatter = TextFormatter()
    
    private init() {}
    
    private let queue = DispatchQueue(label: "com.no-typing.transcriptionHandler")
    
    
    /// Set block mode state
    func setBlockMode(_ blockMode: Bool) {
        isBlockMode = blockMode
        print("📝 TranscriptionResultHandler: Block mode set to \(blockMode)")
        
        // Clear accumulated text when switching modes
        if !blockMode && !accumulatedText.isEmpty {
            // If switching from block to streaming mode, insert accumulated text
            insertAccumulatedText(accumulatedText)
            accumulatedText = ""
        }
    }
    
    /// Get current accumulated text (for block mode)
    func getAccumulatedText() -> String {
        return accumulatedText
    }
    
    /// Clear accumulated text
    func clearAccumulatedText() {
        accumulatedText = ""
        print("📝 TranscriptionResultHandler: Cleared accumulated text")
    }
    
    /// Insert accumulated text and clear buffer
    func flushAccumulatedText() {
        if !accumulatedText.isEmpty {
            // Clean the accumulated text before inserting
            Task {
                await cleanAndInsertAccumulatedText()
            }
        }
    }
    
    /// Clean text using Foundation Models and insert it (for streaming mode)
    private func cleanAndInsertText(_ text: String, isTemporary: Bool, duration: TimeInterval? = nil) async {
        // Check if cleaning is enabled in settings
        let cleaningEnabled = UserDefaults.standard.bool(forKey: "enableTranscriptionCleaning")
        let translationEnabled = UserDefaults.standard.bool(forKey: "enableAITranslation")
        
        if cleaningEnabled && TranscriptionCleaner.shared.isAvailable() && !text.isEmpty {
            do {
                let provider = UserDefaults.standard.string(forKey: "aiRewriteProvider") ?? "Apple Intelligence"
                print("🪄 [Handler] Requesting AI Rewrite for streaming text (Provider: \(provider))...")
                let cleanedText = try await TranscriptionCleaner.shared.cleanTranscription(text)
                
                // Now translate if needed
                var finalResult = cleanedText
                if translationEnabled {
                    print("🌐 TranscriptionResultHandler: Translating cleaned streaming text...")
                    if let translated = try? await TranscriptionTranslator.shared.translate(text: cleanedText) {
                        finalResult = translated
                    }
                }
                
                await MainActor.run {
                    let processedText = TextReplacementService.shared.applyReplacements(to: finalResult)
                    self.handleTranscriptionInsertion(processedText, isTemporary: isTemporary, duration: duration)
                }
            } catch {
                print("⚠️ TranscriptionResultHandler: Cleaning failed, fallback to original text (+ translation if enabled)")
                var finalResult = text
                if translationEnabled {
                    if let translated = try? await TranscriptionTranslator.shared.translate(text: text) {
                        finalResult = translated
                    }
                }
                await MainActor.run {
                    let processedText = TextReplacementService.shared.applyReplacements(to: finalResult)
                    self.handleTranscriptionInsertion(processedText, isTemporary: isTemporary, duration: duration)
                }
            }
        } else {
            // No cleaning, but maybe translation
            var finalResult = text
            if translationEnabled && !text.isEmpty {
                if let translated = try? await TranscriptionTranslator.shared.translate(text: text) {
                    finalResult = translated
                }
            }
            
            await MainActor.run {
                let processedText = TextReplacementService.shared.applyReplacements(to: finalResult)
                self.handleTranscriptionInsertion(processedText, isTemporary: isTemporary, duration: duration)
            }
        }
    }
    
    /// Clean accumulated text using Foundation Models and insert it
    private func cleanAndInsertAccumulatedText() async {
        let textToClean = accumulatedText
        accumulatedText = ""
        
        if textToClean.isEmpty { return }
        
        let cleaningEnabled = UserDefaults.standard.bool(forKey: "enableTranscriptionCleaning")
        let translationEnabled = UserDefaults.standard.bool(forKey: "enableAITranslation")
        
        if cleaningEnabled && TranscriptionCleaner.shared.isAvailable() {
            do {
                let provider = UserDefaults.standard.string(forKey: "aiRewriteProvider") ?? "Apple Intelligence"
                print("🪄 [Handler] Requesting AI Rewrite for accumulated text (Provider: \(provider))...")
                let cleanedText = try await TranscriptionCleaner.shared.cleanTranscription(textToClean)
                
                var finalResult = cleanedText
                if translationEnabled {
                    print("🌐 TranscriptionResultHandler: Translating cleaned accumulated text...")
                    if let translated = try? await TranscriptionTranslator.shared.translate(text: cleanedText) {
                        finalResult = translated
                    }
                }
                
                await MainActor.run {
                    let processedText = TextReplacementService.shared.applyReplacements(to: finalResult)
                    self.insertAccumulatedText(processedText)
                }
            } catch {
                print("⚠️ TranscriptionResultHandler: Cleaning failed for accumulated text")
                var finalResult = textToClean
                if translationEnabled {
                    if let translated = try? await TranscriptionTranslator.shared.translate(text: textToClean) {
                        finalResult = translated
                    }
                }
                await MainActor.run {
                    let processedText = TextReplacementService.shared.applyReplacements(to: finalResult)
                    self.insertAccumulatedText(processedText)
                }
            }
        } else {
            var finalResult = textToClean
            if translationEnabled {
                if let translated = try? await TranscriptionTranslator.shared.translate(text: textToClean) {
                    finalResult = translated
                }
            }
            
            await MainActor.run {
                let processedText = TextReplacementService.shared.applyReplacements(to: finalResult)
                self.insertAccumulatedText(processedText)
            }
        }
        
        print("📝 TranscriptionResultHandler: Flushed accumulated text")
    }
    
    /// Handles transcription for streaming mode
    /// - Parameters:
    ///   - transcription: The transcription text
    ///   - duration: The duration in seconds of the audio processed
    ///   - isTemporary: Whether this is a temporary transcription that might be replaced
    func handleTranscriptionResult(_ transcription: String, duration: TimeInterval?, isTemporary: Bool = false) {
        print("🔤 TranscriptionResultHandler: Processing \(isTemporary ? "temporary" : "final") text: \"\(transcription)\"")
        
        // Evaluate for Voice Commands before processing as standard text
        if !isTemporary, let action = VoiceCommandService.shared.evaluate(text: transcription) {
            print("🎙️ Voice Command Detected: \(action)")
            DispatchQueue.main.async {
                TextInsertionService.shared.clearTemporaryText()
                KeystrokeSimulator.shared.execute(action)
            }
            self.resetSession()
            return
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Handle text insertion based on mode
            if self.isBlockMode && !isTemporary {
                    // In block mode, accumulate final text instead of inserting immediately
                    let textToAdd = transcription
                    if self.accumulatedText.isEmpty {
                        self.accumulatedText = textToAdd
                    } else {
                        self.accumulatedText += " " + textToAdd
                    }
                    print("📝 TranscriptionResultHandler: Accumulated text in block mode: \"\(self.accumulatedText)\"")
                } else if !self.isBlockMode {
                    // In streaming mode, clean and insert text
                    if !isTemporary {
                        // For final text in streaming mode, apply cleaning
                        Task {
                            await self.cleanAndInsertText(transcription, isTemporary: false, duration: duration)
                        }
                    } else {
                        // For temporary text, insert without cleaning to maintain responsiveness
                        DispatchQueue.main.async {
                            print("📲 TranscriptionResultHandler: Inserting temporary text: \"\(transcription)\"")
                            // Apply text replacements to temporary text for immediate feedback
                            let processedText = TextReplacementService.shared.applyReplacements(to: transcription)
                            self.handleTranscriptionInsertion(processedText, isTemporary: true, duration: duration)
                        }
                    }
                }
                // In block mode, ignore temporary transcriptions (don't show them)
        }
    }
    
    /// Handles final text insertion without counting words - needed for backward compatibility
    func insertAccumulatedText(_ text: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.handleTranscriptionInsertion(text, isTemporary: false)
            }
            
            self.resetSession()
        }
    }
    
    
    /// Helper method to handle text insertion
    private func handleTranscriptionInsertion(_ text: String, isTemporary: Bool = false, duration: TimeInterval? = nil) {
        print("📝 Inserting \(isTemporary ? "temporary" : "final") text: \"\(text)\"")
        
        // Get the current language from UserDefaults
        let language = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "auto"

        // Use the TextInsertionService to insert the text
        print("🔤 Calling TextInsertionService to insert \(isTemporary ? "temporary" : "final") text with language: \(language)")
        TextInsertionService.shared.insertText(text, language: language, isTemporary: isTemporary)
        
        // Add to history if it's final text (not temporary)
        if !isTemporary && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let bundleID = TextInsertionService.shared.currentCapturedBundleID
            TranscriptionHistoryManager.shared.addTranscription(text, duration: duration, sourceAppBundleID: bundleID)
        }

        // Word counting removed - no longer tracking usage
    }
    
    /// Reset the current speech session
    func resetSession() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Reset the text tracking state in TextInsertionService
            DispatchQueue.main.async {
                TextInsertionService.shared.resetTextTrackingState()
            }
        }
    }
    
    /// Called when silence is detected
    func handleSilenceDetected() {
        resetSession()
    }
} 