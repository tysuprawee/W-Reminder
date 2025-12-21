import Foundation
import AudioToolbox
import AVFoundation

@Observable
class MuteDetector {
    static let shared = MuteDetector()
    var isMuted: Bool = false
    
    private var soundId: SystemSoundID = 0
    private var isChecking = false
    
    init() {
        createSilentSound()
    }
    
    deinit {
        if soundId != 0 {
            AudioServicesDisposeSystemSoundID(soundId)
        }
    }
    
    private func createSilentSound() {
        let fileName = "mute-check.wav"
        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent(fileName)
        
        // cleanup
        try? FileManager.default.removeItem(at: fileURL)
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            // Write 0.5 second of silence
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(format.sampleRate * 0.5)
            if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) {
                buffer.frameLength = frameCount // Zeroed by default
                try audioFile.write(from: buffer)
            }
            
            // Register System Sound
            let status = AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundId)
            if status != kAudioServicesNoError {
                print("Error creating sound ID: \(status)")
                soundId = 0
            } else {
                print("Silent sound created successfully. ID: \(soundId)")
            }
        } catch {
            print("Failed to create silent sound for detection: \(error)")
            soundId = 0
        }
    }
    
    func check() {
        if soundId == 0 {
            print("Sound ID is 0, attempting recreation...")
            createSilentSound()
            if soundId == 0 {
                print("Still failed to create sound ID. Aborting check.")
                return
            }
        }
        
        guard !isChecking else { return }
        isChecking = true
        
        let startTime = Date()
        
        AudioServicesPlaySystemSoundWithCompletion(soundId) { [weak self] in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            
            // 0.5s file.
            // If muted, it returns almost instantly (< 0.1s).
            // If unmuted, it plays for ~0.5s.
            let isMutedDetection = elapsed < 0.1
            
            Task { @MainActor in
                self.isMuted = isMutedDetection
                self.isChecking = false
                print("Mute Check: Elapsed \(elapsed)s -> Muted: \(isMutedDetection)")
            }
        }
    }
}
