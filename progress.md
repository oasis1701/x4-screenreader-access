# X4 NVDA Accessibility Mod - Progress Report

**Last Updated:** December 31, 2025
**Status:** WORKING - Iteration 12.7

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
| **Global hotkey: Target status** | "NVDA: Read Target Status" - reads target shield/hull (via SirNukes Hotkey API + MD) |

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

## Recent Changes (Dec 31, 2025)

### Global Hotkeys for Gameplay Info
- **"NVDA: Read Target Status"**: Reads current target's shield and hull percentages
- Uses **SirNukes Hotkey API** (MD-based)
  - Lua keyboard hooks (`RegisterEvent("keyboardInput", ...)`) only work in menus, not gameplay
  - Hotkey API uses external Python for keyboard capture, works everywhere
- **IMPORTANT**: Default key registration often fails. User must manually assign hotkey in X4 Options → Controls
- MD queries `player.target.hullpercentage`, `player.target.shieldpercentage`
- Announces "Shield X percent, Hull Y percent" or "No target"

### How to Add More Hotkeys (for future sessions)
1. **Register in MD** (`nvda_accessibility.xml`) inside `Register_Hotkeys` cue:
   ```xml
   <!-- Register KEY first -->
   <signal_cue_instantly cue="md.Hotkey_API.Register_Key"
       param="table[$key='ctrl r', $id='nvda_your_action_id']"/>
   <!-- Then register ACTION with $onRelease -->
   <signal_cue_instantly cue="md.Hotkey_API.Register_Action"
       param="table[
           $id = 'nvda_your_action_id',
           $onRelease = Your_Callback_Cue,
           $name = 'NVDA: Your Action Name',
           $description = 'Description for controls menu'
       ]"/>
   ```
2. **Create callback cue** that queries game state and writes to pipe:
   ```xml
   <cue name="Your_Callback_Cue" instantiate="true" namespace="this">
       <conditions><event_cue_signalled/></conditions>
       <actions>
           <!-- Query game data, e.g.: player.ship.speed, player.money -->
           <signal_cue_instantly cue="md.Named_Pipes.Write"
               param="table[$pipe='x4_nvda', $msg='SPEAK|Your message']"/>
       </actions>
   </cue>
   ```
3. **Key lessons learned**:
   - Use `$onRelease` NOT `$cue` in Register_Action
   - Call `Register_Key` BEFORE `Register_Action`
   - Property names end with "percentage" (e.g., `hullpercentage`, `shieldpercentage`)
   - Reference `kuertee_accessibility_features` for working examples

4. **Useful MD properties for future hotkeys**:
   - `player.target` - current target (check `not player.target` for none)
   - `player.target.hullpercentage`, `player.target.shieldpercentage`
   - `player.target.name`, `player.target.knownname`
   - `player.ship.hullpercentage`, `player.ship.shieldpercentage` - player's own ship
   - `player.ship.speed` - current speed
   - `player.money` - player credits
   - `player.sector.knownname` - current sector name
   - See `_unpacked/md/` for more examples (search for property usage)

---

## Previous Changes (Dec 29, 2025)

### Grid navigation (LEFT/RIGHT arrows)
- Tracks column changes to detect true grids vs multi-column lists
- `knownGridWidgets[widget]` remembers confirmed grids
- Settings/Extensions menus: full row (column never changes)
- Ship Interactions: single cell (column changes on L/R)

### Dropdown labels (Deploy, Modes)
- Added `C.GetDropDownTextDetails()` for expandable menu item labels

### Extensions menu toggle states
- Extended column iteration to 1-10 (button in column 6)
