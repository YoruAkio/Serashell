#!/usr/bin/env python3
"""keystroke listener using evdev for global keypress capture.

tracks shift and capslock state for case-sensitive character output.
outputs json lines to stdout:
  {"type":"press","key":"a","raw":"A","code":30,"modifier":false,"wide":false,"kind":"char"}
  {"type":"press","key":"Ctrl","raw":"Ctrl","code":29,"modifier":true,"wide":false,"kind":"mod"}
  {"type":"release","key":"Ctrl","raw":"Ctrl","code":29,"modifier":true,"wide":false,"kind":"mod"}
"""

import json
import sys
import os
import signal
import selectors

try:
    import evdev
    from evdev import ecodes
except ImportError:
    print(json.dumps({"type": "error", "message": "python-evdev not installed"}), flush=True)
    sys.exit(1)

# @note unshifted key mapping for alphanumeric and symbols
UNSHIFTED_MAP = {
    ecodes.KEY_1: "1", ecodes.KEY_2: "2", ecodes.KEY_3: "3",
    ecodes.KEY_4: "4", ecodes.KEY_5: "5", ecodes.KEY_6: "6",
    ecodes.KEY_7: "7", ecodes.KEY_8: "8", ecodes.KEY_9: "9",
    ecodes.KEY_0: "0",
    ecodes.KEY_MINUS: "-", ecodes.KEY_EQUAL: "=",
    ecodes.KEY_Q: "q", ecodes.KEY_W: "w", ecodes.KEY_E: "e",
    ecodes.KEY_R: "r", ecodes.KEY_T: "t", ecodes.KEY_Y: "y",
    ecodes.KEY_U: "u", ecodes.KEY_I: "i", ecodes.KEY_O: "o",
    ecodes.KEY_P: "p",
    ecodes.KEY_LEFTBRACE: "[", ecodes.KEY_RIGHTBRACE: "]",
    ecodes.KEY_A: "a", ecodes.KEY_S: "s", ecodes.KEY_D: "d",
    ecodes.KEY_F: "f", ecodes.KEY_G: "g", ecodes.KEY_H: "h",
    ecodes.KEY_J: "j", ecodes.KEY_K: "k", ecodes.KEY_L: "l",
    ecodes.KEY_SEMICOLON: ";", ecodes.KEY_APOSTROPHE: "'",
    ecodes.KEY_GRAVE: "`", ecodes.KEY_BACKSLASH: "\\",
    ecodes.KEY_Z: "z", ecodes.KEY_X: "x", ecodes.KEY_C: "c",
    ecodes.KEY_V: "v", ecodes.KEY_B: "b", ecodes.KEY_N: "n",
    ecodes.KEY_M: "m",
    ecodes.KEY_COMMA: ",", ecodes.KEY_DOT: ".", ecodes.KEY_SLASH: "/",
    ecodes.KEY_SPACE: " ",
}

# @note shifted key mapping
SHIFTED_MAP = {
    ecodes.KEY_1: "!", ecodes.KEY_2: "@", ecodes.KEY_3: "#",
    ecodes.KEY_4: "$", ecodes.KEY_5: "%", ecodes.KEY_6: "^",
    ecodes.KEY_7: "&", ecodes.KEY_8: "*", ecodes.KEY_9: "(",
    ecodes.KEY_0: ")",
    ecodes.KEY_MINUS: "_", ecodes.KEY_EQUAL: "+",
    ecodes.KEY_Q: "Q", ecodes.KEY_W: "W", ecodes.KEY_E: "E",
    ecodes.KEY_R: "R", ecodes.KEY_T: "T", ecodes.KEY_Y: "Y",
    ecodes.KEY_U: "U", ecodes.KEY_I: "I", ecodes.KEY_O: "O",
    ecodes.KEY_P: "P",
    ecodes.KEY_LEFTBRACE: "{", ecodes.KEY_RIGHTBRACE: "}",
    ecodes.KEY_A: "A", ecodes.KEY_S: "S", ecodes.KEY_D: "D",
    ecodes.KEY_F: "F", ecodes.KEY_G: "G", ecodes.KEY_H: "H",
    ecodes.KEY_J: "J", ecodes.KEY_K: "K", ecodes.KEY_L: "L",
    ecodes.KEY_SEMICOLON: ":", ecodes.KEY_APOSTROPHE: '"',
    ecodes.KEY_GRAVE: "~", ecodes.KEY_BACKSLASH: "|",
    ecodes.KEY_Z: "Z", ecodes.KEY_X: "X", ecodes.KEY_C: "C",
    ecodes.KEY_V: "V", ecodes.KEY_B: "B", ecodes.KEY_N: "N",
    ecodes.KEY_M: "M",
    ecodes.KEY_COMMA: "<", ecodes.KEY_DOT: ">", ecodes.KEY_SLASH: "?",
    ecodes.KEY_SPACE: " ",
}

# @note letter keycodes; evdev letter codes are not contiguous so a range check breaks
LETTER_CODES = {code for code, ch in UNSHIFTED_MAP.items() if ch.isalpha()}

# @note special non-char keys
SPECIAL_KEYS = {
    ecodes.KEY_ESC: "Esc",
    ecodes.KEY_BACKSPACE: "Backspace",
    ecodes.KEY_TAB: "Tab",
    ecodes.KEY_ENTER: "Enter",
    ecodes.KEY_LEFTCTRL: "Ctrl", ecodes.KEY_RIGHTCTRL: "Ctrl",
    ecodes.KEY_LEFTSHIFT: "Shift", ecodes.KEY_RIGHTSHIFT: "Shift",
    ecodes.KEY_LEFTALT: "Alt", ecodes.KEY_RIGHTALT: "Alt",
    ecodes.KEY_LEFTMETA: "Super", ecodes.KEY_RIGHTMETA: "Super",
    ecodes.KEY_CAPSLOCK: "Caps",
    ecodes.KEY_DELETE: "Del",
    ecodes.KEY_HOME: "Home", ecodes.KEY_END: "End",
    ecodes.KEY_PAGEUP: "PgUp", ecodes.KEY_PAGEDOWN: "PgDn",
    ecodes.KEY_UP: "↑", ecodes.KEY_DOWN: "↓",
    ecodes.KEY_LEFT: "←", ecodes.KEY_RIGHT: "→",
    ecodes.KEY_INSERT: "Ins",
    ecodes.KEY_PRINT: "PrtSc",
    ecodes.KEY_F1: "F1", ecodes.KEY_F2: "F2", ecodes.KEY_F3: "F3",
    ecodes.KEY_F4: "F4", ecodes.KEY_F5: "F5", ecodes.KEY_F6: "F6",
    ecodes.KEY_F7: "F7", ecodes.KEY_F8: "F8", ecodes.KEY_F9: "F9",
    ecodes.KEY_F10: "F10", ecodes.KEY_F11: "F11", ecodes.KEY_F12: "F12",
    ecodes.KEY_FN: "Fn",
}

MODIFIER_CODES = {
    ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
    ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
    ecodes.KEY_LEFTALT, ecodes.KEY_RIGHTALT,
    ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA,
    ecodes.KEY_FN,
}

WIDE_KEYS = {"Shift", "Tab", "Enter", "Backspace", "Caps"}


def find_keyboards():
    """find all keyboard input devices."""
    keyboards = []
    for path in sorted(evdev.list_devices()):
        try:
            dev = evdev.InputDevice(path)
            caps = dev.capabilities(verbose=False)
            if ecodes.EV_KEY in caps:
                key_codes = caps[ecodes.EV_KEY]
                if ecodes.KEY_A in key_codes and ecodes.KEY_Z in key_codes:
                    keyboards.append(dev)
        except (PermissionError, OSError):
            continue
    return keyboards


def main():
    signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    keyboards = find_keyboards()
    if not keyboards:
        print(json.dumps({"type": "error", "message": "no keyboard devices found"}), flush=True)
        sys.exit(1)

    sel = selectors.DefaultSelector()
    for kb in keyboards:
        sel.register(kb, selectors.EVENT_READ)

    shift_held = False
    # @note seed from the real led so state is correct from the first keypress
    caps_lock = any(ecodes.LED_CAPSL in kb.leds() for kb in keyboards)

    try:
        while True:
            events = sel.select()
            for key, _ in events:
                dev = key.fileobj
                try:
                    for event in dev.read():
                        if event.type != ecodes.EV_KEY:
                            continue

                        code = event.code
                        val = event.value  # 0: release, 1: press, 2: repeat

                        if code in (ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT):
                            shift_held = (val != 0)
                        elif code == ecodes.KEY_CAPSLOCK and val == 1:
                            caps_lock = not caps_lock

                        is_modifier = code in MODIFIER_CODES
                        
                        # Determine key representation
                        is_char = False
                        if code in UNSHIFTED_MAP:
                            is_char = True
                            # Character sensitivity
                            if shift_held:
                                label = SHIFTED_MAP.get(code, UNSHIFTED_MAP[code])
                                if caps_lock and code in LETTER_CODES:
                                    label = label.lower()
                            else:
                                label = UNSHIFTED_MAP[code]
                                if caps_lock and code in LETTER_CODES:
                                    label = label.upper()
                        elif code in SPECIAL_KEYS:
                            label = SPECIAL_KEYS[code]
                        else:
                            label = ecodes.KEY.get(code, f"KEY_{code}")
                            if isinstance(label, list):
                                label = label[0]
                            label = label.replace("KEY_", "")

                        is_wide = label in WIDE_KEYS

                        if val == 1 or val == 2:  # Press or repeat
                            msg = {
                                "type": "press",
                                "key": label,
                                "raw": label,
                                "code": code,
                                "modifier": is_modifier,
                                "wide": is_wide,
                                "is_char": is_char,
                                "is_repeat": (val == 2),
                                "shift": shift_held,
                            }
                            print(json.dumps(msg), flush=True)
                        elif val == 0:  # Release
                            msg = {
                                "type": "release",
                                "key": label,
                                "code": code,
                                "modifier": is_modifier,
                            }
                            print(json.dumps(msg), flush=True)
                except OSError:
                    pass
    except KeyboardInterrupt:
        pass
    finally:
        sel.close()
        for kb in keyboards:
            try:
                kb.close()
            except Exception:
                pass


if __name__ == "__main__":
    main()
