import AVFoundation
import Foundation

@Observable
final class IOSAudioMonitor {
    var audioLevels: [Double] = Array(repeating: 0, count: 24)
    var isSpeaking = false
    var isRunning = false
    var errorMessage: String?
    var permissionDenied = false
    var averageLevel: Double = 0

    private let audioEngine = AVAudioEngine()
    private let speechStartThreshold: Double = 0.07
    private let speechContinueThreshold: Double = 0.045
    private let minSpeakingWindows = 2
    private let minSilentWindows = 4
    private var speakingWindows = 0
    private var silentWindows = 0

    func start() {
        errorMessage = nil
        permissionDenied = false

        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            configureAndStartAudioEngine()
        case .denied:
            permissionDenied = true
            errorMessage = "Microphone permission is denied. Enable it in iOS Settings to use speech-aware modes."
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
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
        averageLevel = 0
        speakingWindows = 0
        silentWindows = 0
        audioLevels = Array(repeating: 0, count: audioLevels.count)
    }

    private func configureAndStartAudioEngine() {
        stop()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
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
                self.averageLevel = average

                let threshold = self.isSpeaking ? self.speechContinueThreshold : self.speechStartThreshold
                if average >= threshold {
                    self.speakingWindows += 1
                    self.silentWindows = 0
                } else {
                    self.silentWindows += 1
                    self.speakingWindows = 0
                }

                if !self.isSpeaking, self.speakingWindows >= self.minSpeakingWindows {
                    self.isSpeaking = true
                } else if self.isSpeaking, self.silentWindows >= self.minSilentWindows {
                    self.isSpeaking = false
                }
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
