import UIKit
import Flutter
import AVFoundation
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate {
    var synthesizer: AVSpeechSynthesizer?
    var currentUtterance: AVSpeechUtterance?
    var ttsChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .mixWithOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("❌ AVAudioSession 配置失败: \(error)")
        }

        guard let controller = window?.rootViewController as? FlutterViewController else {
            GeneratedPluginRegistrant.register(with: self)
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        let ttsChannel = FlutterMethodChannel(
            name: "myreader/tts",
            binaryMessenger: controller.binaryMessenger
        )
        self.ttsChannel = ttsChannel

        synthesizer = AVSpeechSynthesizer()
        synthesizer?.delegate = self

        ttsChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "App not available", details: nil))
                return
            }

            switch call.method {
            case "speak":
                if let args = call.arguments as? [String: Any],
                   let text = args["text"] as? String {
                    let rate = (args["rate"] as? NSNumber)?.floatValue ?? 1.0
                    let pitch = (args["pitch"] as? NSNumber)?.floatValue ?? 1.0
                    let volume = (args["volume"] as? NSNumber)?.floatValue ?? 1.0
                    self.speak(text: text, rate: rate, pitch: pitch, volume: volume)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Text not provided", details: nil))
                }

            case "stop":
                self.stop()
                result(nil)

            case "pause":
                self.pause()
                result(nil)

            case "resume":
                self.resume()
                result(nil)

            case "setSpeechRate":
                if let args = call.arguments as? [String: Any],
                   let rate = (args["rate"] as? NSNumber)?.floatValue {
                    self.setSpeechRate(rate: rate)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Rate not provided", details: nil))
                }

            case "setPitch":
                if let args = call.arguments as? [String: Any],
                   let pitch = (args["pitch"] as? NSNumber)?.floatValue {
                    self.setPitch(pitch: pitch)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Pitch not provided", details: nil))
                }

            case "setVolume":
                if let args = call.arguments as? [String: Any],
                   let volume = (args["volume"] as? NSNumber)?.floatValue {
                    self.setVolume(volume: volume)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Volume not provided", details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func speak(text: String, rate: Float, pitch: Float, volume: Float) {
        synthesizer?.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)

        // 使用系统默认语速为基准做倍速映射，保证 0.8x/1.0x/1.25x/1.5x 都有明显差异
        let mappedRate = max(
            AVSpeechUtteranceMinimumSpeechRate,
            min(
                AVSpeechUtteranceMaximumSpeechRate,
                AVSpeechUtteranceDefaultSpeechRate * rate
            )
        )

        utterance.rate = mappedRate
        utterance.pitchMultiplier = max(0.5, min(2.0, pitch))
        utterance.volume = max(0.0, min(1.0, volume))

        // Try to find a Chinese voice
        let zhVoice = AVSpeechSynthesisVoice(language: "zh-CN")
        if zhVoice != nil {
            utterance.voice = zhVoice
        }

        currentUtterance = utterance

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Audio session 激活失败: \(error)")
        }

        if let synthesizer = synthesizer {
            synthesizer.speak(utterance)
            notifyState("playing")
        } else {
            print("❌ 朗读失败: synthesizer 未初始化")
        }
    }

    func stop() {
        synthesizer?.stopSpeaking(at: .immediate)
        notifyState("stopped")
    }

    func pause() {
        let paused = synthesizer?.pauseSpeaking(at: .immediate) ?? false
        if paused {
            notifyState("paused")
        }
    }

    func resume() {
        let continued = synthesizer?.continueSpeaking() ?? false
        if continued {
            notifyState("playing")
        }
    }

    func setSpeechRate(rate: Float) {
    }

    func setPitch(pitch: Float) {
    }

    func setVolume(volume: Float) {
    }

    func notifyState(_ state: String) {
        DispatchQueue.main.async {
            self.ttsChannel?.invokeMethod("onStateChange", arguments: state)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension AppDelegate: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        notifyState("playing")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        notifyState("stopped")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        notifyState("paused")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        notifyState("playing")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        notifyState("stopped")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let text = String(utterance.speechString)
        DispatchQueue.main.async {
            self.ttsChannel?.invokeMethod("onProgress", arguments: [
                "position": characterRange.location,
                "total": text.count
            ])
        }
    }
}
