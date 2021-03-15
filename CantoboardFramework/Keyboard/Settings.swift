//
//  Settings.swift
//  CantoboardFramework
//
//  Created by Alex Man on 2/23/21.
//

import Foundation

public enum CharForm: String, Codable {
    case traditionalHK = "zh-HK"
    case traditionalTW = "zh-TW"
    case simplified = "zh-CN"
}

public enum SymbolShape: String, Codable {
    case half = "half"
    case full = "full"
    case smart = "smart"
}

public enum SpaceOutputMode: String, Codable {
    case input = "input"
    case bestCandidate = "bestCandidate"
}

public enum ToneInputMode: String, Codable {
    case longPress = "longPress"
    case vxq = "vxq"
}

// If any of these settings is changed, we have to redeploy Rime.
public struct RimeSettings: Codable, Equatable {
    public var toneInputMode: ToneInputMode
    
    public init() {
        toneInputMode = .longPress
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.toneInputMode = try container.decodeIfPresent(ToneInputMode.self, forKey: .toneInputMode) ?? .longPress
    }
}

public struct Settings: Codable, Equatable {
    private static let settingsKeyName = "Settings"
    private static let DefaultCharForm: CharForm = .traditionalTW
    private static let DefaultEnglishInputEnabled: Bool = true
    private static let DefaultAutoCapEnabled: Bool = true
    private static let DefaultSmartFullStopEnabled: Bool = true
    private static let DefaultSymbolShape: SymbolShape = .smart
    private static let DefaultSpaceOutputMode: SpaceOutputMode = .input
    private static let DefaultRimeSettings: RimeSettings = RimeSettings()

    public var charForm: CharForm
    public var isEnglishEnabled: Bool
    public var isAutoCapEnabled: Bool
    public var isSmartFullStopEnabled: Bool
    public var symbolShape: SymbolShape
    public var spaceOutputMode: SpaceOutputMode
    public var rimeSettings: RimeSettings
    
    public init() {
        charForm = Settings.DefaultCharForm
        isEnglishEnabled = Settings.DefaultEnglishInputEnabled
        isAutoCapEnabled = Settings.DefaultAutoCapEnabled
        isSmartFullStopEnabled = Settings.DefaultSmartFullStopEnabled
        symbolShape = Settings.DefaultSymbolShape
        spaceOutputMode = Settings.DefaultSpaceOutputMode
        rimeSettings = Settings.DefaultRimeSettings
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.charForm = try container.decodeIfPresent(CharForm.self, forKey: .charForm) ?? Settings.DefaultCharForm
        self.isEnglishEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnglishEnabled) ?? Settings.DefaultEnglishInputEnabled
        self.isAutoCapEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutoCapEnabled) ?? Settings.DefaultAutoCapEnabled
        self.isSmartFullStopEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSmartFullStopEnabled) ?? Settings.DefaultSmartFullStopEnabled
        self.symbolShape = try container.decodeIfPresent(SymbolShape.self, forKey: .symbolShape) ?? Settings.DefaultSymbolShape
        self.spaceOutputMode = try container.decodeIfPresent(SpaceOutputMode.self, forKey: .spaceOutputMode) ?? Settings.DefaultSpaceOutputMode
        self.rimeSettings = try container.decodeIfPresent(RimeSettings.self, forKey: .rimeSettings) ?? Settings.DefaultRimeSettings
    }
    
    private static var _cached: Settings?
    
    public static var cached: Settings {
        get {
            if _cached == nil {
                return reload()
            }
            return _cached!
        }
    }
    
    public static func reload() -> Settings {
        if let saved = userDefaults.object(forKey: settingsKeyName) as? Data {
            let decoder = JSONDecoder()
            do {
                let setting = try decoder.decode(Settings.self, from: saved)
                _cached = setting
                return setting
            } catch {
                NSLog("Failed to load \(saved). Falling back to default settings. Error: \(error)")
            }
        }
        
        _cached = Settings()
        return _cached!
    }
    
    public static func save(_ settings: Settings) {
        _cached = settings
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(settings) {
            userDefaults.set(encoded, forKey: settingsKeyName)
        } else {
            NSLog("Failed to save \(settings)")
        }
    }
    
    private static var userDefaults: UserDefaults = initUserDefaults()
    
    private static func initUserDefaults() -> UserDefaults {
        let suiteName = "group.org.cantoboard"
        let appGroupDefaults = UserDefaults(suiteName: suiteName)
        if let appGroupDefaults = appGroupDefaults {
            NSLog("Using UserDefaults \(suiteName).")
            return appGroupDefaults
        } else {
            NSLog("Cannot open app group UserDefaults. Falling back to UserDefaults.standard.")
            return UserDefaults.standard
        }
    }
}
