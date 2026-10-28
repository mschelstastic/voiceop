import Carbon
import XCTest
@testable import VoiceOperator

final class TriggerKeyTests: XCTestCase {
    func testKeycodesMatchCarbon() {
        let expected: [TriggerKey: Int] = [
            .fn: kVK_Function, .rightOption: kVK_RightOption,
            .f13: kVK_F13, .f14: kVK_F14, .f15: kVK_F15, .f16: kVK_F16,
            .f17: kVK_F17, .f18: kVK_F18, .f19: kVK_F19,
        ]
        XCTAssertEqual(Set(expected.keys), Set(TriggerKey.allCases))
        for (key, code) in expected { XCTAssertEqual(key.keycode, Int64(code), key.rawValue) }
    }

    func testOnlyModifierTriggersHaveAFlagBit() {
        XCTAssertEqual(TriggerKey.fn.modifierBit, CGEventFlags.maskSecondaryFn.rawValue)
        XCTAssertEqual(TriggerKey.rightOption.modifierBit, UInt64(NX_DEVICERALTKEYMASK))
        for key in TriggerKey.allCases where key != .fn && key != .rightOption {
            XCTAssertNil(key.modifierBit, key.rawValue)
        }
    }

    func testFunctionKeyTitles() {
        XCTAssertEqual(TriggerKey.f13.title, "F13")
    }

    func testKeycodeLookup() {
        for key in TriggerKey.allCases { XCTAssertEqual(TriggerKey(keycode: key.keycode), key) }
        XCTAssertNil(TriggerKey(keycode: Int64(kVK_ANSI_A)))
    }

    func testTriggerKeysPersistAndFallBack() {
        let defaults = UserDefaults.standard
        let saved = (defaults.object(forKey: "vo.triggerKeys"), defaults.object(forKey: "vo.triggerKey"))
        defer {
            defaults.set(saved.0, forKey: "vo.triggerKeys")
            defaults.set(saved.1, forKey: "vo.triggerKey")
        }
        defaults.removeObject(forKey: "vo.triggerKeys")
        defaults.removeObject(forKey: "vo.triggerKey")
        XCTAssertEqual(HotkeyPreferences.triggerKeys, [.fn])

        defaults.set("f13", forKey: "vo.triggerKey")   // the single key chosen before
        XCTAssertEqual(HotkeyPreferences.triggerKeys, [.f13])

        HotkeyPreferences.triggerKeys = [.fn, .f13]
        XCTAssertEqual(HotkeyPreferences.triggerKeys, [.fn, .f13])
        XCTAssertNil(defaults.object(forKey: "vo.triggerKey"))
        XCTAssertEqual(HotkeyPreferences.describe([.f13, .fn]), "Fn (🌐), F13")

        HotkeyPreferences.triggerKeys = []
        XCTAssertEqual(HotkeyPreferences.triggerKeys, [.fn])
    }
}
