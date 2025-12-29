# X4 NVDA Accessibility Mod - Progress Report

**Last Updated:** December 28, 2025
**Status:** CLEANUP - Iteration 11 Applied

---

## Current Status

NVDA reads menu items, toggle states (On/Off), and dropdown values.

### What's Working
| Component | Status | Notes |
|-----------|--------|-------|
| Python NVDA Bridge | WORKING | Connects, receives messages, speaks via NVDA |
| MD Script | WORKING | Events fire correctly |
| Lua Script Loading | WORKING | Loads via Lua_Loader |
| PlaySound Hook | WORKING | Detects navigation sounds |
| MD Relay Communication | WORKING | Lua -> MD -> Python -> NVDA |
| Text Extraction | WORKING | Uses FFI `C.GetMouseOverText()` |
| FFI Access | ENABLED | Can now call native C functions |
| Slider Values | WORKING | Uses `C.GetSliderCellValues()` |
| Toggle Buttons | WORKING | Uses `GetButtonText()` for On/Off |
| Dropdown Values | WORKING | Uses `GetDropDownStartOption()` + `GetDropDownOptions2()` |
| Checkbox States | WORKING | Uses `C.IsCheckBoxChecked()` |

### Known Limitations
| Feature | Status | Notes |
|---------|--------|-------|
| Expanded Dropdown Navigation | NOT POSSIBLE | No sound plays, no FFI for highlighted option |

---

## Latest Fix - Iteration 11 (December 28, 2025)

### Problem
Iteration 10's dropdown polling fired at wrong times and didn't help with navigation.

### Root Cause
- `IsDropDownActive()` returns true when dropdown is **focused**, not just when **expanded**
- `GetDropDownStartOption()` only updates **after** Enter confirmation, not during navigation
- No sound plays during dropdown option navigation
- Without a trigger event, we cannot detect focus movement in dropdown options

### Fix Applied
Removed broken dropdown polling code:
1. Removed `IsDropDownActive()` FFI function
2. Removed state variables: `activeDropdownID`, `dropdownOptions`, etc.
3. Removed functions: `checkDropdownState()`, `announceDropdownOpen()`, `announceDropdownSelection()`
4. Simplified dropdown code back to simple value reading

### Conclusion
Dropdown value reading works (e.g., "Autosave Interval. 40-80 min").
Expanded dropdown navigation is not possible with current X4 APIs.

---

## Previous Fix - Iteration 10 (December 28, 2025)

### Attempted
Added `SetScript("onUpdate")` polling for dropdown state.

### Result
Failed - fired at wrong times, didn't detect actual navigation.

---

## Previous Fix - Iteration 9 (December 28, 2025)

### Problem
Dropdown values not being read (e.g., "5 minutes" for Autosave Interval).

### Root Cause
`GetDropDownTextDetails().textOverride` is usually **empty**. The actual text comes from:
- `GetDropDownStartOption()` returns the current option **ID**
- `GetDropDownOptions2()` returns all options with their **text**
- Must iterate options and match by ID to get text

### Fix Applied
1. Added `DropDownOption2` FFI struct definition
2. Added `GetDropDownStartOption()`, `GetNumDropDownOptions()`, `GetDropDownOptions2()` FFI functions
3. Replaced dropdown code to iterate options and match by ID

### New Code Pattern
```lua
-- For dropdowns (selected option text)
if IsType(cellWidgetID, "dropdown") then
    local startOption = ffi.string(C.GetDropDownStartOption(cellWidgetID))
    local numOptions = C.GetNumDropDownOptions(cellWidgetID)
    local buf = ffi.new("DropDownOption2[?]", numOptions)
    local n = C.GetDropDownOptions2(buf, numOptions, cellWidgetID)
    for i = 0, n - 1 do
        if ffi.string(buf[i].id) == startOption then
            return ffi.string(buf[i].text)  -- "5 minutes", "Full", etc.
        end
    end
end
```

### Expected Debug Output
- "Widget 127 IS a dropdown"
- "Dropdown startOption ID: 5min"
- "Dropdown has 4 options"
- "Dropdown selected: 5 minutes"
- NVDA speaks: "Autosave Interval. 5 minutes. Saves automatically..."

### Known Limitation
Expanded dropdown options (when pressing Enter) not yet supported - will be added in future iteration.

---

## Previous Fix - Iteration 8 (December 28, 2025)

### Problem
Toggle settings (Autosave, Auto-Roll, etc.) not reading On/Off state.

### Root Cause
X4 uses type "button" for toggle settings, NOT "checkbox".

### Fix Applied
1. Added `GetButtonText(buttonID)` call for type "button" widgets
2. Added FFI definitions: `Font`, `Color`, `DropDownTextInfo` structs

---

## Previous Fix - Iteration 7 (December 28, 2025)

### Problem
Checkbox/toggle states not being detected. `IsCheckBoxActive()` was returning false.

### Root Cause (from code exploration)
X4 uses `IsType(widgetID, "checkbox")` to verify a widget is a checkbox BEFORE calling checkbox functions. We were calling `IsCheckBoxActive()` on non-checkbox widgets.

### Fix Applied
1. Use `IsType(cellWidgetID, "checkbox")` to verify widget type first
2. Only then call `IsCheckBoxChecked()` to get state
3. Skip `IsCheckBoxActive()` (it checks if enabled, not if exists)
4. Added debug logging to identify widget types

### Debug Output
The debug log will now show:
- "Widget 170 IS a checkbox" → if it's a checkbox, will return On/Off
- "Widget 170 is type: button" → helps identify what column contains the checkbox

---

## Previous Fix - Iteration 6 (December 28, 2025)

Collect ALL info (label + value + tooltip) instead of returning on first match.

---

## Previous Fix - Iteration 5 (December 28, 2025)

Reordered methods so labels come first, tooltips last. But this caused tooltips to never be read.

---

## Previous Fix - Iteration 4 (December 27, 2025)

### Root Cause Found
Debug showed `C.GetMouseOverText not available` - the addon never set up FFI access!

### Fix Applied
1. Added FFI setup at top of file with `ffi.cdef[[ ... ]]`
2. Enabled access to native C functions for sliders and checkboxes

---

## For Next Claude Session

**READ THIS FIRST** - Start by reading the debug.txt file the user provides.

### Important: Pipe Communication
- **Protected UI mode is OFF** (required for SirNukes APIs to work)
- Lua CANNOT access named pipes directly (sandboxed)
- Communication works via MD relay: Lua → `AddUITriggeredEvent` → MD cue → `md.Named_Pipes.Write` → Python
- This is working as designed. Do not try to add direct Lua pipe access.

### Key Files
- `extensions/nvda_accessibility/ui/nvda_accessibility.lua` - Main Lua script (edit this)
- `_unpacked/ui/widget/lua/widget_fullscreen.lua` - X4's FFI function definitions (reference)
- `_unpacked/ui/addons/ego_gameoptions/gameoptions.lua` - Game options menu patterns (reference)

### Debug File
`C:\Users\rhadi\Documents\Egosoft\X4\98775138\debug.txt`

### What's Working
1. Menu item labels (via `GetText()`)
2. Slider values (via `C.GetSliderCellValues()`)
3. Toggle button states (via `GetButtonText()` - returns "On"/"Off")
4. Dropdown selections (via `GetDropDownStartOption()` + `GetDropDownOptions2()`)
5. Checkbox states (via `C.IsCheckBoxChecked()`)
6. Tooltips (via `C.GetMouseOverText()`)
7. All columns in tables (extensions show name, ID, version, date)

### Known Limitations (Cannot Fix)
1. **Expanded dropdown navigation** - No sound plays when scrolling options, no FFI to get highlighted index
2. Detection requires PlaySound hook - if no sound, no detection

### What's Still Being Tested
1. Different UI screens beyond settings menus
2. Map/encyclopedia navigation
3. In-game HUD elements

### Key Code Pattern (getTextFromCell function)
```lua
-- Collects: label + value + tooltip
1. GetText() → label
2. GetSliderCellValues() → slider value
3. IsType("button") → GetButtonText() → "On"/"Off"
4. IsType("dropdown") → GetDropDownStartOption + GetDropDownOptions2 → selected option text
5. IsType("checkbox") → IsCheckBoxChecked() → On/Off
6. GetMouseOverText() → tooltip
7. Combine with periods: "Label. Value. Tooltip"
```

---

## Architecture

### Communication Flow
```
X4 plays "ui_positive_hover_normal" sound
    |
    v
Lua PlaySound hook intercepts
    |
    v
Lua calls getCurrentSelectionText() -> getTextFromCell()
    |
    v
Lua calls AddUITriggeredEvent("NVDA", "Speak", message)
    |
    v
MD cue NVDA_Speech_Relay catches event
    |
    v
MD calls md.Named_Pipes.Write to x4_nvda pipe
    |
    v
Python nvda_bridge.py receives message
    |
    v
NVDA speaks the text
```

### File Structure
```
extensions/nvda_accessibility/
├── content.xml              # Extension manifest
├── progress.md              # This file
├── index/
│   └── mdscripts.xml        # MD script index
├── md/
│   └── nvda_accessibility.xml   # MD script with relay cue
├── ui/
│   ├── ui.xml               # Lua addon registration
│   └── nvda_accessibility.lua   # Main Lua script
└── python/
    ├── nvda_bridge.py       # NVDA communication bridge
    ├── nvdaControllerClient64.dll
    └── sn_x4_python_pipe_server_py/  # Pipe server
```

---

## Testing Instructions

1. Start NVDA screen reader

2. Start Python server:
   ```
   cd extensions\nvda_accessibility\python\sn_x4_python_pipe_server_py
   python Main.py
   ```

3. Start X4, load a save

4. Open Settings menu, navigate with arrow keys

5. Expected: NVDA speaks menu items with values (e.g., "Total Volume, 50")

6. Check debug.txt for `[NVDA]` messages
