import Foundation
import AVFoundation
import Flutter

public class TtsSavePlugin: NSObject, FlutterPlugin {
    private var synthesizer: AVSpeechSynthesizer?
    private var ttsDelegate: TtsDelegate?
    private var audioFile: AVAudioFile?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.funbrushai.app/tts_save", binaryMessenger: registrar.messenger())
        let instance = TtsSavePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "saveTtsToFile" {
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String,
                  let filePath = args["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
                return
            }
            
            let language = args["language"] as? String ?? "tr-TR"
            let pitch = (args["pitch"] as? NSNumber)?.floatValue ?? 1.0
            let speechRate = (args["speechRate"] as? NSNumber)?.floatValue ?? 0.5
            
            saveTtsToFile(text: text, filePath: filePath, language: language, pitch: pitch, speechRate: speechRate, result: result)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func saveTtsToFile(text: String, filePath: String, language: String, pitch: Float, speechRate: Float, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: filePath)
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: filePath) {
            try? FileManager.default.removeItem(at: url)
        }
        
        synthesizeToFile(text: text, filePath: filePath, language: language, pitch: pitch, speechRate: speechRate) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "SYNTHESIS_FAILED", message: error ?? "Unknown error", details: nil))
                }
                self?.cleanup()
            }
        }
    }
    
    private func synthesizeToFile(text: String, filePath: String, language: String, pitch: Float, speechRate: Float, completion: @escaping (Bool, String?) -> Void) {
        let synthesizer = AVSpeechSynthesizer()
        self.synthesizer = synthesizer
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = speechRate * AVSpeechUtteranceMaximumSpeechRate
        utterance.pitchMultiplier = pitch
        utterance.volume = 1.0
        
        let outputURL = URL(fileURLWithPath: filePath)
        var hasCompleted = false
        var writeError: String?
        
        let finishOnce: (Bool, String?) -> Void = { success, error in
            guard !hasCompleted else { return }
            hasCompleted = true
            completion(success, error)
        }
        
        let delegate = TtsDelegate(filePath: filePath) { [weak self] success, error in
            self?.audioFile = nil
            if let writeError = writeError {
                finishOnce(false, writeError)
            } else {
                finishOnce(success, error)
            }
        }
        self.ttsDelegate = delegate
        synthesizer.delegate = delegate
        
        synthesizer.write(utterance) { [weak self] (buffer: AVAudioBuffer) in
            guard let self = self else { return }
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
            
            if pcmBuffer.frameLength == 0 {
                // End of speech synthesis buffer stream
                self.audioFile = nil
                self.verifyAndComplete(filePath: filePath, writeError: writeError, completion: finishOnce)
                return
            }
            
            do {
                if self.audioFile == nil {
                    let ext = outputURL.pathExtension.lowercased()
                    if ext == "wav" {
                        let wavSettings: [String: Any] = [
                            AVFormatIDKey: kAudioFormatLinearPCM,
                            AVSampleRateKey: pcmBuffer.format.sampleRate,
                            AVNumberOfChannelsKey: pcmBuffer.format.channelCount,
                            AVLinearPCMBitDepthKey: 16,
                            AVLinearPCMIsFloatKey: false,
                            AVLinearPCMIsBigEndianKey: false,
                            AVLinearPCMIsNonInterleaved: false
                        ]
                        self.audioFile = try AVAudioFile(
                            forWriting: outputURL,
                            settings: wavSettings,
                            commonFormat: pcmBuffer.format.commonFormat,
                            interleaved: pcmBuffer.format.isInterleaved
                        )
                    } else if ext == "m4a" || ext == "aac" {
                        let aacSettings: [String: Any] = [
                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                            AVSampleRateKey: pcmBuffer.format.sampleRate,
                            AVNumberOfChannelsKey: pcmBuffer.format.channelCount,
                            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                        ]
                        self.audioFile = try AVAudioFile(
                            forWriting: outputURL,
                            settings: aacSettings,
                            commonFormat: pcmBuffer.format.commonFormat,
                            interleaved: pcmBuffer.format.isInterleaved
                        )
                    } else {
                        self.audioFile = try AVAudioFile(
                            forWriting: outputURL,
                            settings: pcmBuffer.format.settings,
                            commonFormat: pcmBuffer.format.commonFormat,
                            interleaved: pcmBuffer.format.isInterleaved
                        )
                    }
                }
                try self.audioFile?.write(from: pcmBuffer)
            } catch {
                writeError = "Failed to write audio buffer: \(error.localizedDescription)"
            }
        }
    }
    
    private func verifyAndComplete(filePath: String, writeError: String?, completion: @escaping (Bool, String?) -> Void) {
        if let writeError = writeError {
            completion(false, writeError)
            return
        }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                let fileSize = attributes[.size] as? Int64 ?? 0
                if fileSize > 100 {
                    completion(true, nil)
                } else {
                    completion(false, "Generated file too small (\(fileSize) bytes)")
                }
            } catch {
                completion(false, "Error checking file: \(error.localizedDescription)")
            }
        } else {
            completion(false, "Audio file not created")
        }
    }
    
    private func cleanup() {
        audioFile = nil
        synthesizer = nil
        ttsDelegate = nil
    }
}

class TtsDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let filePath: String
    let completion: (Bool, String?) -> Void
    
    init(filePath: String, completion: @escaping (Bool, String?) -> Void) {
        self.filePath = filePath
        self.completion = completion
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: self.filePath) {
                let attributes = try? fileManager.attributesOfItem(atPath: self.filePath)
                let fileSize = attributes?[.size] as? Int64 ?? 0
                if fileSize > 100 {
                    self.completion(true, nil)
                } else {
                    self.completion(false, "Generated file too small")
                }
            } else {
                self.completion(false, "Audio file not created")
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completion(false, "Speech cancelled")
    }
}