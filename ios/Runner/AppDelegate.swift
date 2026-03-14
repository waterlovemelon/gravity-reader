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
            print("✅ AVAudioSession 配置成功")
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
        print("✅ AVSpeechSynthesizer 初始化完成")

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
        print("🎤 开始朗读文本: '\(text.prefix(50))...' (长度: \(text.count))")
        print("📊 参数 - rate: \(rate), pitch: \(pitch), volume: \(volume)")

        // Stop any current speech
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
        print("📊 映射后的语速: \(mappedRate)")

        utterance.rate = mappedRate
        utterance.pitchMultiplier = max(0.5, min(2.0, pitch))
        utterance.volume = max(0.0, min(1.0, volume))

        // Try to find a Chinese voice
        let zhVoice = AVSpeechSynthesisVoice(language: "zh-CN")
        if zhVoice != nil {
            utterance.voice = zhVoice
            print("✅ 使用中文语音")
        } else {
            print("⚠️ 未找到中文语音，使用默认语音")
        }

        // Store current utterance
        currentUtterance = utterance

        // Activate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session 已激活")
        } catch {
            print("❌ Audio session 激活失败: \(error)")
        }

        // Speak
        if let synthesizer = synthesizer {
            synthesizer.speak(utterance)
            notifyState("playing")
            print("✅ 开始朗读")
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
        // AVSpeech 的 rate 调整在下次 speak 时生效
        // 当前实现中 speak 方法直接使用传入的 rate，所以这里不需要额外操作
    }

    func setPitch(pitch: Float) {
        // AVSpeech 的 pitch 调整在下次 speak 时生效
        // pitch 范围是 0.5 - 2.0
    }

    func setVolume(volume: Float) {
        // AVSpeech 的 volume 调整在下次 speak 时生效
        // volume 范围是 0.0 - 1.0
        print("🔊 音量设置为: \(volume)")
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
        print("🎤 [DELEGATE] 开始朗读")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        notifyState("stopped")
        print("✅ [DELEGATE] 朗读完成")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        notifyState("paused")
        print("⏸️ [DELEGATE] 暂停朗读")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        notifyState("playing")
        print("▶️ [DELEGATE] 继续朗读")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        notifyState("stopped")
        print("🛑 [DELEGATE] 取消朗读")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let text = String(utterance.speechString)
        let currentText = (text as NSString).substring(with: characterRange)
        print("📖 朗读进度: \(characterRange.location) - \(characterRange.location + characterRange.length) / \(text.count)")
        print("当前语音: '\(currentText)'")
        DispatchQueue.main.async {
            self.ttsChannel?.invokeMethod("onProgress", arguments: [
                "position": characterRange.location,
                "total": text.count
            ])
        }
    }
}
