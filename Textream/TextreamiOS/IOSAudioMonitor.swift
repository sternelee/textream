import AVFoundation
import Foundation

@Observable
final class IOSAudioMonitor {
    var audioLevels: [Double] = Array(repeating: 0, count: 24)
    var isSpeaking = false
    var isRunning = false
    var errorMessage: String?
    var permissionDenied = false

    private let audioEngine = AVAudioEngine()
    private let speakingThreshold: Double = 0.05

    func start() {
        errorMessage = nil
        permissionDenied = false

        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            configureAndStartAudioEngine()
        case .denied:
            permissionDenied = true
            errorMessage = "Microphone permission is denied. Enable it in iOS Settings to use speech-aware modes."
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureAndStartAudioEngine()
                    } else {
                        self.permissionDenied = true
                        self.errorMessage = "Microphone permission is required for Voice-Activated mode."
                    }
                }
            }
        @unknown default:
            errorMessage = "Microphone permission is unavailable."
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        isRunning = false
        isSpeaking = false
        audioLevels = Array(repeating: 0, count: audioLevels.count)
    }

    private func configureAndStartAudioEngine() {
        stop()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: [])
        } catch {
            errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            errorMessage = "Audio input is unavailable."
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let level = Self.normalizedLevel(from: buffer)
            DispatchQueue.main.async {
                self.audioLevels.append(level)
                if self.audioLevels.count > 24 {
                    self.audioLevels.removeFirst(self.audioLevels.count - 24)
                }
                let recent = self.audioLevels.suffix(6)
                let average = recent.reduce(0, +) / Double(max(recent.count, 1))
                self.isSpeaking = average > self.speakingThreshold
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRunning = true
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            isRunning = false
        }
    }

    private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<frameLength {
            sum += channelData[index] * channelData[index]
        }
        let rms = sqrt(sum / Float(frameLength))
        return Double(min(rms * 6.0, 1.0))
    }
}
