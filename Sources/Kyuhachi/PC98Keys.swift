import Carbon.HIToolbox

/// Maps Mac virtual key codes to PC-98 keyboard codes, by position on a
/// Japanese (JIS) keyboard, which is laid out much like the PC-98's.
enum KeyMap {
    /// PC-98 codes of keys that the Mac reports as modifier changes.
    static let shift: UInt8 = 0x70
    static let caps: UInt8 = 0x71
    static let grph: UInt8 = 0x73
    static let ctrl: UInt8 = 0x74

    /// A PC-98 key and the state its SHIFT must be in while it is pressed.
    struct Stroke {
        let code: UInt8
        let shift: Bool
    }

    /// Whether the Mac's keyboard is a US (ANSI) one. Its symbol keys are
    /// translated by legend rather than position, since the PC-98's differ.
    static var isANSI: Bool {
        KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardANSI
    }

    static func pc98Code(for keyCode: UInt16) -> UInt8? {
        table[Int(keyCode)]
    }

    /// The PC-98 stroke that types the character on a US key's legend, for
    /// keys whose character differs from the PC-98 key in the same place.
    static func usStroke(for keyCode: UInt16, shifted: Bool) -> Stroke? {
        (shifted ? usShifted : usUnshifted)[Int(keyCode)]
    }

    /// The PC-98 keypad key typed by a letter key in numpad mode, laid out
    /// as on a 98NOTE: 7 8 9 / U I O / J K L / M.
    static func numpadCode(for keyCode: UInt16) -> UInt8? {
        numpad[Int(keyCode)]
    }

    private static let numpad: [Int: UInt8] = [
        kVK_ANSI_7: 0x42, kVK_ANSI_8: 0x43, kVK_ANSI_9: 0x44,
        kVK_ANSI_U: 0x46, kVK_ANSI_I: 0x47, kVK_ANSI_O: 0x48,
        kVK_ANSI_J: 0x4a, kVK_ANSI_K: 0x4b, kVK_ANSI_L: 0x4c,
        kVK_ANSI_M: 0x4e,
    ]

    private static let usUnshifted: [Int: Stroke] = [
        kVK_ANSI_Grave: Stroke(code: 0x0c, shift: true),         // ` = SHIFT ^
        kVK_ANSI_Equal: Stroke(code: 0x0b, shift: true),         // = = SHIFT -
        kVK_ANSI_LeftBracket: Stroke(code: 0x1b, shift: false),  // [
        kVK_ANSI_RightBracket: Stroke(code: 0x28, shift: false), // ]
        kVK_ANSI_Backslash: Stroke(code: 0x0d, shift: false),    // \ = ¥
        kVK_ANSI_Quote: Stroke(code: 0x07, shift: true),         // ' = SHIFT 7
    ]

    private static let usShifted: [Int: Stroke] = [
        kVK_ANSI_Grave: Stroke(code: 0x1a, shift: true),         // ~ = SHIFT @
        kVK_ANSI_2: Stroke(code: 0x1a, shift: false),            // @
        kVK_ANSI_6: Stroke(code: 0x0c, shift: false),            // ^
        kVK_ANSI_7: Stroke(code: 0x06, shift: true),             // & = SHIFT 6
        kVK_ANSI_8: Stroke(code: 0x27, shift: true),             // * = SHIFT :
        kVK_ANSI_9: Stroke(code: 0x08, shift: true),             // ( = SHIFT 8
        kVK_ANSI_0: Stroke(code: 0x09, shift: true),             // ) = SHIFT 9
        kVK_ANSI_Minus: Stroke(code: 0x33, shift: true),         // _ = SHIFT ろ
        kVK_ANSI_Equal: Stroke(code: 0x26, shift: true),         // + = SHIFT ;
        kVK_ANSI_LeftBracket: Stroke(code: 0x1b, shift: true),   // {
        kVK_ANSI_RightBracket: Stroke(code: 0x28, shift: true),  // }
        kVK_ANSI_Backslash: Stroke(code: 0x0d, shift: true),     // |
        kVK_ANSI_Semicolon: Stroke(code: 0x27, shift: false),    // :
        kVK_ANSI_Quote: Stroke(code: 0x02, shift: true),         // " = SHIFT 2
    ]

    private static let table: [Int: UInt8] = [
        kVK_Escape: 0x00,
        kVK_ANSI_1: 0x01, kVK_ANSI_2: 0x02, kVK_ANSI_3: 0x03, kVK_ANSI_4: 0x04, kVK_ANSI_5: 0x05,
        kVK_ANSI_6: 0x06, kVK_ANSI_7: 0x07, kVK_ANSI_8: 0x08, kVK_ANSI_9: 0x09, kVK_ANSI_0: 0x0a,
        kVK_ANSI_Minus: 0x0b,         // - =
        kVK_ANSI_Equal: 0x0c,         // ^ (JIS)
        kVK_JIS_Yen: 0x0d,            // ¥ |
        kVK_Delete: 0x0e,             // BS
        kVK_Tab: 0x0f,
        kVK_ANSI_Q: 0x10, kVK_ANSI_W: 0x11, kVK_ANSI_E: 0x12, kVK_ANSI_R: 0x13, kVK_ANSI_T: 0x14,
        kVK_ANSI_Y: 0x15, kVK_ANSI_U: 0x16, kVK_ANSI_I: 0x17, kVK_ANSI_O: 0x18, kVK_ANSI_P: 0x19,
        kVK_ANSI_LeftBracket: 0x1a,   // @ (JIS)
        kVK_ANSI_RightBracket: 0x1b,  // [ (JIS)
        kVK_Return: 0x1c,
        kVK_ANSI_A: 0x1d, kVK_ANSI_S: 0x1e, kVK_ANSI_D: 0x1f, kVK_ANSI_F: 0x20, kVK_ANSI_G: 0x21,
        kVK_ANSI_H: 0x22, kVK_ANSI_J: 0x23, kVK_ANSI_K: 0x24, kVK_ANSI_L: 0x25,
        kVK_ANSI_Semicolon: 0x26,     // ; +
        kVK_ANSI_Quote: 0x27,         // : (JIS)
        kVK_ANSI_Backslash: 0x28,     // ] (JIS)
        kVK_ANSI_Z: 0x29, kVK_ANSI_X: 0x2a, kVK_ANSI_C: 0x2b, kVK_ANSI_V: 0x2c, kVK_ANSI_B: 0x2d,
        kVK_ANSI_N: 0x2e, kVK_ANSI_M: 0x2f,
        kVK_ANSI_Comma: 0x30, kVK_ANSI_Period: 0x31, kVK_ANSI_Slash: 0x32,
        kVK_JIS_Underscore: 0x33,     // _ (ろ)
        kVK_Space: 0x34,
        kVK_JIS_Kana: 0x35,           // XFER: right of the space bar, as on the PC-98
        kVK_JIS_Eisu: 0x51,           // NFER: left of the space bar
        kVK_PageUp: 0x36,             // ROLL UP
        kVK_PageDown: 0x37,           // ROLL DOWN
        kVK_Help: 0x38,               // INS
        kVK_ForwardDelete: 0x39,      // DEL
        kVK_UpArrow: 0x3a, kVK_LeftArrow: 0x3b, kVK_RightArrow: 0x3c, kVK_DownArrow: 0x3d,
        kVK_Home: 0x3e,               // HOME CLR
        kVK_End: 0x3f,                // HELP
        kVK_ANSI_KeypadMinus: 0x40, kVK_ANSI_KeypadDivide: 0x41,
        kVK_ANSI_Keypad7: 0x42, kVK_ANSI_Keypad8: 0x43, kVK_ANSI_Keypad9: 0x44,
        kVK_ANSI_KeypadMultiply: 0x45,
        kVK_ANSI_Keypad4: 0x46, kVK_ANSI_Keypad5: 0x47, kVK_ANSI_Keypad6: 0x48,
        kVK_ANSI_KeypadPlus: 0x49,
        kVK_ANSI_Keypad1: 0x4a, kVK_ANSI_Keypad2: 0x4b, kVK_ANSI_Keypad3: 0x4c,
        kVK_ANSI_KeypadEquals: 0x4d, kVK_ANSI_Keypad0: 0x4e,
        kVK_ANSI_KeypadDecimal: 0x50,
        kVK_ANSI_KeypadEnter: 0x1c,
        kVK_ANSI_KeypadClear: 0x3e,
        kVK_F1: 0x62, kVK_F2: 0x63, kVK_F3: 0x64, kVK_F4: 0x65, kVK_F5: 0x66,
        kVK_F6: 0x67, kVK_F7: 0x68, kVK_F8: 0x69, kVK_F9: 0x6a, kVK_F10: 0x6b,
        kVK_F11: 0x52, kVK_F12: 0x53,  // vf.1, vf.2
        kVK_F13: 0x60,                 // STOP
        kVK_F14: 0x61,                 // COPY
        kVK_F15: 0x72,                 // カナ
    ]
}
