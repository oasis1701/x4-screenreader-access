# X4 NVDA Accessibility Mod - Progress Report

**Last Updated:** December 28, 2025
**Status:** WORKING - Iteration 12.2

---

## Current Status

NVDA reads menu items, toggle states, slider values, dropdown options, and tooltips.

### What's Working
| Feature | Method |
|---------|--------|
| Menu labels | `GetText()` |
| Slider values | `C.GetSliderCellValues()` |
| Toggle buttons | `GetButtonText()` → "On"/"Off" |
| Dropdown values | `GetDropDownStartOption()` + `GetDropDownOptions2()` |
| Checkbox states | `C.IsCheckBoxChecked()` |
| Tooltips | `C.GetMouseOverText()` |
| Dropdown open | Lists all options with selection marked |
| Silent UI nav | `onUpdate` polling fallback |

### Known Limitations
| Issue | Reason |
|-------|--------|
| Dropdown arrow keys | `moveDropDownSelection()` fires no callbacks; `private.activeDropDown.highlighted` is internal |

---

## Key Files

| File | Purpose |
|------|---------|
| `extensions/nvda_accessibility/ui/nvda_accessibility.lua` | Main Lua script |
| `extensions/nvda_accessibility/md/nvda_accessibility.xml` | MD relay script |
| `extensions/nvda_accessibility/python/nvda_bridge.py` | Python NVDA bridge |
| `C:\Users\rhadi\Documents\Egosoft\X4\98775138\debug.txt` | Debug log |

---

## Architecture

```
PlaySound hook / onUpdate polling / Dropdown handlers
                    ↓
         getCurrentSelectionText()
                    ↓
         AddUITriggeredEvent("NVDA", "Speak", msg)
                    ↓
         MD cue → md.Named_Pipes.Write("x4_nvda", msg)
                    ↓
         Python nvda_bridge.py → NVDA speaks
```

**Important:** Lua cannot access pipes directly. Communication uses MD relay.

---

## Testing

1. Start NVDA
2. Run: `cd extensions\nvda_accessibility\python\X4_Python_Pipe_Server && python Main.py`
3. Start X4, load save
4. Open Settings, navigate with arrow keys
5. Check debug.txt for `[NVDA]` messages

---

## For Next Session

- Read debug.txt first if user reports issues
- `widget_fullscreen.lua` has FFI definitions (reference only)
- Protected UI mode must be OFF
