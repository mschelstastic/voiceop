import Foundation

/// The key that starts a dictation. Fn is the default; the others exist for
/// keyboards whose Fn never reaches macOS (Keychron and most other third-party
/// boards handle Fn in firmware, as a layer switch), where a spare key can be
/// remapped to F13–F19 in the keyboard's own software.
///
/// Right Command and Right Control are deliberately absent: Command locks a
/// held dictation and Control picks command mode, so either as the trigger would
/// collide with its own gesture.
///
/// More than one can be on at once — Fn on a laptop's own keyboard, F13 on an
/// external one — and any of them starts a dictation.
enum TriggerKey: String, CaseIterable {
    case fn, rightOption, f13, f14, f15, f16, f17, f18, f19

    /// The trigger with this keycode, whether or not it is switched on.
    init?(keycode: Int64) {
        guard let key = Self.allCases.first(where: { $0.keycode == keycode }) else { return nil }
        self = key
    }

    var title: String {
        switch self {
        case .fn:          return "Fn (🌐)"
        case .rightOption: return "Right Option"
        default:           return rawValue.uppercased()
        }
    }

    /// The `kVK_*` virtual keycode.
    var keycode: Int64 {
        switch self {
        case .fn:          return 63   // kVK_Function
        case .rightOption: return 61   // kVK_RightOption
        case .f13:         return 105
        case .f14:         return 107
        case .f15:         return 113
        case .f16:         return 106
        case .f17:         return 64
        case .f18:         return 79
        case .f19:         return 80
        }
    }

    /// For a modifier trigger, the `flagsChanged` bit that says it is down: Fn's
    /// `kCGEventFlagMaskSecondaryFn`, or Right Option's device-dependent
    /// `NX_DEVICERALTKEYMASK` (the generic Option bit cannot tell it from Left
    /// Option). Nil for a function key, which arrives as keyDown/keyUp instead.
    var modifierBit: UInt64? {
        switch self {
        case .fn:          return 0x800000
        case .rightOption: return 0x40
        default:           return nil
        }
    }
}

/// User-facing choices about how the trigger key behaves. Persisted in
/// `UserDefaults` (the same lightweight store `LaunchAtLogin` uses) so the
/// choice survives relaunches.
enum HotkeyPreferences {
    private static let tapToToggleKey = "vo.tapToToggleDictation"
    private static let triggerKeysKey = "vo.triggerKeys"
    /// The single key chosen before several could be; read once as the fallback.
    private static let legacyTriggerKeyKey = "vo.triggerKey"

    /// When true, the trigger uses the single-tap toggle model instead of the
    /// default hold / double-tap-lock / ⌘-lock model: one press starts, the next
    /// press stops, and holding is just a press. See `HotkeyMonitor.tapToToggle`.
    static var tapToToggle: Bool {
        get { UserDefaults.standard.bool(forKey: tapToToggleKey) }
        set { UserDefaults.standard.set(newValue, forKey: tapToToggleKey) }
    }

    /// Which keys start a dictation; never empty. Defaults to Fn.
    static var triggerKeys: Set<TriggerKey> {
        get {
            let defaults = UserDefaults.standard
            let raw = defaults.stringArray(forKey: triggerKeysKey)
                ?? defaults.string(forKey: legacyTriggerKeyKey).map { [$0] } ?? []
            let keys = Set(raw.compactMap(TriggerKey.init(rawValue:)))
            return keys.isEmpty ? [.fn] : keys
        }
        set {
            let keys = newValue.isEmpty ? [.fn] : newValue
            UserDefaults.standard.set(TriggerKey.allCases.filter(keys.contains).map(\.rawValue), forKey: triggerKeysKey)
            UserDefaults.standard.removeObject(forKey: legacyTriggerKeyKey)
        }
    }

    /// The keys' titles in menu order, for the log.
    static func describe(_ keys: Set<TriggerKey>) -> String {
        TriggerKey.allCases.filter(keys.contains).map(\.title).joined(separator: ", ")
    }
}
