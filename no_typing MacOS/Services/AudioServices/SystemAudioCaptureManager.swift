import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

class SystemAudioCaptureManager: NSObject, ObservableObject {
    static let shared = SystemAudioCaptureManager()
    
    @Published var isRecording: Bool = false
    @Published var hasPermission: Bool = false
    
    private var stream: SCStream?
    private var audioFile: AVAudioFile?
    var currentFileURL: URL?
    
    // We use a dedicated queue to handle SCStream output buffers
    private let audioQueue = DispatchQueue(label: "com.notyping.SystemAudioCaptureQueue")
    
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    // The target format required by Whisper (16kHz, mono, PCM)
    private let targetAudioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
    
    private var audioConverter: AVAudioConverter?
    private var sourceFormat: AVAudioFormat?
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func checkPermission() {
        hasPermission = CGPreflightScreenCaptureAccess()
    }
    
    func requestPermission() {
        hasPermission = CGRequestScreenCaptureAccess()
    }
    
    func startRecording(includeMicrophone: Bool = false) async throws {
        guard hasPermission else {
            requestPermission()
            if !CGPreflightScreenCaptureAccess() {
                throw NSError(domain: "SystemAudioCaptureManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Screen Capture Permission denied."])
            }
            DispatchQueue.main.async {
                self.hasPermission = true
            }
            return
        }
        
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = availableContent.displays.first else {
            throw NSError(domain: "SystemAudioCaptureManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No displays found for audio capture."])
        }
        
        // We only want to capture system audio. SCK requires capturing a display or a window.
        // We capture the display but exclude all windows to only get the audio.
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true // Don't capture app's own sounds
        configuration.sampleRate = 16000
        configuration.channelCount = 1
        
        // Mix microphone audio into the system audio stream (macOS 14+)
        if includeMicrophone {
            if #available(macOS 15.0, *) {
                configuration.captureMicrophone = true
            } else {
                print("SystemAudioCaptureManager: captureMicrophone requires macOS 15+, mic will not be included")
            }
        }
        
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        self.stream = stream
        
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        
        let tempDir = FileManager.default.temporaryDirectory
        currentFileURL = tempDir.appendingPathComponent("sys_record_\(UUID().uuidString).wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        audioFile = try AVAudioFile(forWriting: currentFileURL!, settings: settings)
        
        try await stream.startCapture()
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    func stopRecording() async {
        guard let stream = stream, isRecording else { return }
        
        try? await stream.stopCapture()
        self.stream = nil
        self.audioFile = nil
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    // Extracted exactly like AudioRecordingService
    func startNewAudioSegment() -> URL? {
        let oldURL = currentFileURL
        
        let tempDir = FileManager.default.temporaryDirectory
        currentFileURL = tempDir.appendingPathComponent("sys_record_\(UUID().uuidString).wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        audioQueue.sync {
            self.audioFile = try? AVAudioFile(forWriting: self.currentFileURL!, settings: settings)
        }
        
        return oldURL
    }
}

extension SystemAudioCaptureManager: SCStreamDelegate, SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        // Convert CMSampleBuffer to AVAudioPCMBuffer
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return
        }
        
        let format = AVAudioFormat(streamDescription: audioStreamBasicDescription)!
        
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleBuffer.numSamples)) else {
            return
        }
        
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        
        let numChannels = Int(format.channelCount)
        let numBuffers = Int(audioBufferList.mNumberBuffers)
        let bufferListPtr = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        
        for i in 0..<min(numChannels, numBuffers) {
            let channelData = bufferListPtr[i]
            if let destData = pcmBuffer.int16ChannelData?[i] {
                memcpy(destData, channelData.mData, Int(channelData.mDataByteSize))
            } else if let destData = pcmBuffer.floatChannelData?[i] {
                memcpy(destData, channelData.mData, Int(channelData.mDataByteSize))
            }
        }
        
        Task { @MainActor in
            // Emit buffer for level monitoring
            self.onAudioBuffer?(pcmBuffer)
        }
        
        // Write to file natively within the worker queue
        do {
            try self.audioFile?.write(from: pcmBuffer)
        } catch {
            print("SystemAudioCaptureManager: Error writing to audio file: \(error)")
        }
    }
    
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            self.isRecording = false
            print("SystemAudioCaptureManager stream stopped with error: \(error)")
        }
    }
}
