import Flutter
import UIKit
import WidgetKit
import UniformTypeIdentifiers
import AVFoundation
import CryptoKit
import StoreKit

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
        let updates = FlutterMethodChannel(name: "net.salatime.app/store_updates", binaryMessenger: messenger)
        updates.setMethodCallHandler { call, result in
            guard call.method == "getContext" else { result(FlutterMethodNotImplemented); return }
            // The account's storefront can differ from the device's region.
            // Unknown stores leave the optional update notice unavailable.
            Task { @MainActor in
                guard let storefront = await Storefront.current,
                      let country = Self.updateStoreCountry(storefront.countryCode) else { result(nil); return }
                result(["storeCountry": country, "systemVersion": UIDevice.current.systemVersion])
            }
        }
        channels = [widget, schedule, sounds, updates]
    }


    /// StoreKit uses ISO 3166-1 alpha-3; Apple's lookup API requires alpha-2.
    /// Keep unknown country codes unavailable instead of querying another store.
    static func updateStoreCountry(_ alpha3: String) -> String? {
        updateStoreCountries[alpha3.uppercased()]
    }

    private static let updateStoreCountries: [String: String] = {
        let codes = """
            ABW:AW AFG:AF AGO:AO AIA:AI ALA:AX ALB:AL AND:AD ARE:AE ARG:AR ARM:AM
            ASM:AS ATA:AQ ATF:TF ATG:AG AUS:AU AUT:AT AZE:AZ BDI:BI BEL:BE BEN:BJ
            BES:BQ BFA:BF BGD:BD BGR:BG BHR:BH BHS:BS BIH:BA BLM:BL BLR:BY BLZ:BZ
            BMU:BM BOL:BO BRA:BR BRB:BB BRN:BN BTN:BT BVT:BV BWA:BW CAF:CF CAN:CA
            CCK:CC CHE:CH CHL:CL CHN:CN CIV:CI CMR:CM COD:CD COG:CG COK:CK COL:CO
            COM:KM CPV:CV CRI:CR CUB:CU CUW:CW CXR:CX CYM:KY CYP:CY CZE:CZ DEU:DE
            DJI:DJ DMA:DM DNK:DK DOM:DO DZA:DZ ECU:EC EGY:EG ERI:ER ESH:EH ESP:ES
            EST:EE ETH:ET FIN:FI FJI:FJ FLK:FK FRA:FR FRO:FO FSM:FM GAB:GA GBR:GB
            GEO:GE GGY:GG GHA:GH GIB:GI GIN:GN GLP:GP GMB:GM GNB:GW GNQ:GQ GRC:GR
            GRD:GD GRL:GL GTM:GT GUF:GF GUM:GU GUY:GY HKG:HK HMD:HM HND:HN HRV:HR
            HTI:HT HUN:HU IDN:ID IMN:IM IND:IN IOT:IO IRL:IE IRN:IR IRQ:IQ ISL:IS
            ISR:IL ITA:IT JAM:JM JEY:JE JOR:JO JPN:JP KAZ:KZ KEN:KE KGZ:KG KHM:KH
            KIR:KI KNA:KN KOR:KR KWT:KW LAO:LA LBN:LB LBR:LR LBY:LY LCA:LC LIE:LI
            LKA:LK LSO:LS LTU:LT LUX:LU LVA:LV MAC:MO MAF:MF MAR:MA MCO:MC MDA:MD
            MDG:MG MDV:MV MEX:MX MHL:MH MKD:MK MLI:ML MLT:MT MMR:MM MNE:ME MNG:MN
            MNP:MP MOZ:MZ MRT:MR MSR:MS MTQ:MQ MUS:MU MWI:MW MYS:MY MYT:YT NAM:NA
            NCL:NC NER:NE NFK:NF NGA:NG NIC:NI NIU:NU NLD:NL NOR:NO NPL:NP NRU:NR
            NZL:NZ OMN:OM PAK:PK PAN:PA PCN:PN PER:PE PHL:PH PLW:PW PNG:PG POL:PL
            PRI:PR PRK:KP PRT:PT PRY:PY PSE:PS PYF:PF QAT:QA REU:RE ROU:RO RUS:RU
            RWA:RW SAU:SA SDN:SD SEN:SN SGP:SG SGS:GS SHN:SH SJM:SJ SLB:SB SLE:SL
            SLV:SV SMR:SM SOM:SO SPM:PM SRB:RS SSD:SS STP:ST SUR:SR SVK:SK SVN:SI
            SWE:SE SWZ:SZ SXM:SX SYC:SC SYR:SY TCA:TC TCD:TD TGO:TG THA:TH TJK:TJ
            TKL:TK TKM:TM TLS:TL TON:TO TTO:TT TUN:TN TUR:TR TUV:TV TWN:TW TZA:TZ
            UGA:UG UKR:UA UMI:UM URY:UY USA:US UZB:UZ VAT:VA VCT:VC VEN:VE VGB:VG
            VIR:VI VNM:VN VUT:VU WLF:WF WSM:WS YEM:YE ZAF:ZA ZMB:ZM ZWE:ZW
            """
        return Dictionary(uniqueKeysWithValues: codes.split(whereSeparator: { $0.isWhitespace }).map { row in
            let pair = row.split(separator: ":")
            return (String(pair[0]), String(pair[1]))
        })
    }()

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
