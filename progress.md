# X4 NVDA Accessibility Mod - Progress Report

**Last Updated:** December 29, 2025
**Status:** WORKING - Iteration 12.6

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
| Extensions menu | On/Off status via `GetButtonText()` (column 6) |
| Grid navigation | Detects grids via column-change tracking (`knownGridWidgets`), single cell for grids, full row for lists |
| Dropdown labels | `C.GetDropDownTextDetails()` for expandable menu items (Deploy, Modes) |

### Known Limitations
| Issue | Reason |
|-------|--------|
| Dropdown arrow keys | `moveDropDownSelection()` fires no callbacks; `private.activeDropDown.highlighted` is internal |

---

## Key Files and folders

| File | Purpose |
|------|---------|
| `extensions/nvda_accessibility/ui/nvda_accessibility.lua` | Main Lua script |
| `extensions/nvda_accessibility/md/nvda_accessibility.xml` | MD relay script |
| `extensions/nvda_accessibility/python/nvda_bridge.py` | Python NVDA bridge |
| `C:\Users\rhadi\Documents\Egosoft\X4\98775138\debug.txt` | Debug log |
| `_unpacked/` | Game's unpacked source files (UI scripts, MD, libraries) |
| `_unpacked/ui/` | UI Lua scripts - primary reference for widget behavior |
| `_stubs/x4_api_stubs.lua` | Lua API stubs for IDE autocomplete/type checking |

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

---

## Recent Changes (Dec 29, 2025)

### Grid navigation (LEFT/RIGHT arrows)
- Tracks column changes to detect true grids vs multi-column lists
- `knownGridWidgets[widget]` remembers confirmed grids
- Settings/Extensions menus: full row (column never changes)
- Ship Interactions: single cell (column changes on L/R)

### Dropdown labels (Deploy, Modes)
- Added `C.GetDropDownTextDetails()` for expandable menu item labels

### Extensions menu toggle states
- Extended column iteration to 1-10 (button in column 6)
