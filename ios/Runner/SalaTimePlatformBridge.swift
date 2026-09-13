import Flutter
import UIKit
import WidgetKit
import UniformTypeIdentifiers
import AVFoundation
import CryptoKit

final class SalaTimePlatformBridge: NSObject, UIDocumentPickerDelegate {
    private var channels: [FlutterMethodChannel] = []
    private var importResult: FlutterResult?
    private var presenter: UIViewController? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }.first(where: { $0.isKeyWindow })?.rootViewController
    }

    init(messenger: FlutterBinaryMessenger) {
        super.init()
        let widget = FlutterMethodChannel(name: "net.salatime.app/prayer_widget", binaryMessenger: messenger)
        widget.setMethodCallHandler { [weak self] call, result in self?.widget(call, result: result) }
        let schedule = FlutterMethodChannel(name: "net.salatime.app/prayer_schedule", binaryMessenger: messenger)
        schedule.setMethodCallHandler { call, result in
            guard call.method == "updateWidget", let payload = call.arguments as? [String: Any] else { result(FlutterMethodNotImplemented); return }
            do {
                try PrayerWidgetStore.save(payload)
                WidgetCenter.shared.reloadTimelines(ofKind: PrayerWidgetStore.kind)
                result(nil)
            } catch {
                result(FlutterError(code: "widget_configuration_missing", message: "Configure the shared App Group for Runner and SalaTimeWidget.", details: nil))
            }
        }
        let sounds = FlutterMethodChannel(name: "net.salatime.app/personal_sounds", binaryMessenger: messenger)
        sounds.setMethodCallHandler { [weak self] call, result in self?.sound(call, result: result) }
        channels = [widget, schedule, sounds]
    }

    private func widget(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported": result(PrayerWidgetStore.container != nil)
        case "canPin", "pin": result(false) // iOS owns the widget gallery; there is no pinning API.
        case "get": result(PrayerWidgetStore.options.dictionary)
        case "set":
            guard let options = call.arguments as? [String: Any], PrayerWidgetStore.saveOptions(options) else {
                result(FlutterError(code: "widget_configuration_missing", message: "The shared App Group is unavailable.", details: nil)); return
            }
            WidgetCenter.shared.reloadTimelines(ofKind: PrayerWidgetStore.kind)
            result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func sound(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "resolve", let args = call.arguments as? [String: Any], let key = args["key"] as? String {
            guard key.range(of: "^custom_[a-f0-9]{64}$", options: .regularExpression) != nil,
                  let directory = try? soundsDirectory() else {
                result(FlutterError(code: "sound_invalid", message: nil, details: nil)); return
            }
            let url = directory.appendingPathComponent(key + ".caf")
            guard FileManager.default.fileExists(atPath: url.path) else {
                result(FlutterError(code: "sound_missing", message: nil, details: nil)); return
            }
            result(url.absoluteString)
            return
        }
        guard call.method == "import" else { result(FlutterMethodNotImplemented); return }
        guard importResult == nil else { result(FlutterError(code: "sound_import_busy", message: nil, details: nil)); return }
        guard let presenter = presenter, presenter.presentedViewController == nil else {
            result(FlutterError(code: "sound_import_unavailable", message: nil, details: nil)); return
        }
        importResult = result
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presenter.present(picker, animated: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finishImport(nil) }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { finishImport(nil); return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey])
                guard let size = values.fileSize, size > 0, size <= 25 * 1024 * 1024 else {
                    throw NSError(domain: "SalaTimeSound", code: 1)
                }
                let data = try Data(contentsOf: url)
                let key = "custom_" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                let directory = try self.soundsDirectory()
                let target = directory.appendingPathComponent(key + ".caf")
                if !FileManager.default.fileExists(atPath: target.path) {
                    let count = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                        .filter { $0.lastPathComponent.hasPrefix("custom_") && $0.pathExtension == "caf" }.count
                    guard count < 30 else { throw NSError(domain: "SalaTimeSound", code: 2) }
                    let source = try AVAudioFile(forReading: url)
                    let format = source.processingFormat
                    guard format.sampleRate > 0, format.sampleRate <= 192000,
                          (1...2).contains(format.channelCount), source.length > 0 else { throw NSError(domain: "SalaTimeSound", code: 3) }
                    // Notification audio must be under 30 seconds. Preserve the
                    // preview and alert as the same converted local excerpt.
                    let frames = AVAudioFrameCount(min(source.length, AVAudioFramePosition(format.sampleRate * 29)))
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { throw NSError(domain: "SalaTimeSound", code: 4) }
                    try source.read(into: buffer, frameCount: frames)
                    let temp = directory.appendingPathComponent(UUID().uuidString + ".caf")
                    defer { try? FileManager.default.removeItem(at: temp) }
                    do {
                        let output = try AVAudioFile(forWriting: temp, settings: [
                            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: format.sampleRate,
                            AVNumberOfChannelsKey: format.channelCount, AVLinearPCMBitDepthKey: 16,
                            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false
                        ], commonFormat: format.commonFormat, interleaved: format.isInterleaved)
                        try output.write(from: buffer)
                    }
                    try FileManager.default.moveItem(at: temp, to: target)
                }
                let row = ["key": key, "name": String(url.deletingPathExtension().lastPathComponent.prefix(100)), "path": key + ".caf"]
                DispatchQueue.main.async { self.finishImport(row) }
            } catch {
                DispatchQueue.main.async { self.finishImport(FlutterError(code: "sound_import_failed", message: "Choose an audio file smaller than 25 MB (maximum 30 personal sounds).", details: nil)) }
            }
        }
    }

    private func soundsDirectory() throws -> URL {
        let library = try FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = library.appendingPathComponent("Sounds", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    private func finishImport(_ value: Any?) {
        let result = importResult
        importResult = nil
        result?(value)
    }
}
