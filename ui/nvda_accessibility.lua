-- NVDA Accessibility Module for X4 Foundations
-- Provides screen reader support via NVDA
-- Uses SirNukes Named Pipes API for communication with Python bridge

-- FFI setup for accessing native X4 functions
local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
    typedef struct {
        double min;
        double minSelect;
        double max;
        double maxSelect;
        double start;
        double step;
        double infinitevalue;
        uint32_t maxfactor;
        bool exceedmax;
        bool hidemaxvalue;
        bool righttoleft;
        bool fromcenter;
        bool readonly;
        bool useinfinitevalue;
        bool usetimeformat;
    } SliderCellDetails;

    typedef struct {
        const char* name;
        uint32_t size;
    } Font;

    typedef struct {
        uint32_t red;
        uint32_t green;
        uint32_t blue;
        uint32_t alpha;
    } Color;

    typedef struct {
        Color color;
        Font font;
        const char* alignment;
        uint32_t x;
        uint32_t y;
        const char* textOverride;
        float glowfactor;
    } DropDownTextInfo;

    typedef struct {
        const char* id;
        const char* iconid;
        const char* text;
        const char* text2;
        const char* mouseovertext;
        const char* font;
        Color overrideColor;
        bool displayRemoveOption;
        bool active;
        bool hasOverrideColor;
    } DropDownOption2;

    const char* GetMouseOverText(const int widgetid);
    const char* GetMouseOverTextAdditional(const int widgetid);
    bool IsCheckBoxChecked(const int checkboxid);
    bool IsCheckBoxActive(const int checkboxid);
    const char* GetCheckBoxSymbol(const int checkboxid);
    bool GetSliderCellValues(const int slidercellid, SliderCellDetails* values);
    const char* GetSliderCellText(const int slidercellid);
    const char* GetSliderCellSuffix(const int slidercellid);
    bool GetDropDownTextDetails(const int dropdownid, DropDownTextInfo* textinfo);
    const char* GetDropDownStartOption(const int dropdownid);
    uint32_t GetNumDropDownOptions(const int dropdownid);
    uint32_t GetDropDownOptions2(DropDownOption2* result, uint32_t resultlen, const int dropdownid);
]]

-- Immediate debug output to confirm file is loading
print("[NVDA] ========================================")
print("[NVDA] NVDA Accessibility Lua file is loading!")
print("[NVDA] ========================================")

-- Module state
local NVDA = {
    enabled = true,
    initialized = false,
    pipeConnected = false,
    pipeName = "x4_nvda",
    accessId = "nvda_accessibility",
    lastSpoken = "",
    lastSpeakTime = 0,
    lastWidget = nil,
    lastRow = nil,
}

-- Debug logging (writes to X4 debug log)
local function debugLog(message)
    DebugError("[NVDA] " .. tostring(message))
end

debugLog("=== NVDA Accessibility Module Loading ===")

-- Send a message through MD relay to Python
-- Uses AddUITriggeredEvent to signal MD, which forwards to Python via Named_Pipes.Write
local function sendPipeMessage(message)
    if not NVDA.enabled then
        return false
    end

    -- Use AddUITriggeredEvent to signal MD cue
    -- MD will relay this to Python via the Named Pipes API
    if AddUITriggeredEvent then
        local success, err = pcall(function()
            AddUITriggeredEvent("NVDA", "Speak", message)
        end)
        if success then
            debugLog("Sent via MD relay: " .. message)
            NVDA.pipeConnected = true
            return true
        else
            debugLog("Failed to trigger event: " .. tostring(err))
        end
    else
        debugLog("ERROR: AddUITriggeredEvent not available")
    end

    debugLog("FALLBACK (no communication): " .. message)
    NVDA.pipeConnected = false
    return false
end

-- Speak text through NVDA
local function speakText(text)
    if not NVDA.enabled or not text or text == "" then
        return
    end

    -- Clean up the text
    text = tostring(text)
    text = text:gsub("^%s+", ""):gsub("%s+$", "") -- trim whitespace

    if text == "" then
        return
    end

    -- Avoid repeating same text rapidly
    local currentTime = GetCurRealTime and GetCurRealTime() or 0
    if text == NVDA.lastSpoken and (currentTime - NVDA.lastSpeakTime) < 0.3 then
        return
    end

    NVDA.lastSpoken = text
    NVDA.lastSpeakTime = currentTime

    debugLog("Speaking: " .. text)
    sendPipeMessage("SPEAK|" .. text)
end

-- Try to extract text from a cell widget - collect ALL available info
-- Returns: label + value + tooltip combined
local function getTextFromCell(cellWidgetID)
    if not cellWidgetID then
        return nil
    end

    debugLog("getTextFromCell called with: " .. tostring(cellWidgetID))

    local label = nil
    local value = nil
    local tooltip = nil

    -- 1. Try GetText for label
    if GetText then
        local success, result = pcall(function()
            return GetText(cellWidgetID)
        end)
        if success and result and result ~= "" then
            label = result
            debugLog("GetText returned: " .. result)
        end
    end

    -- 2. Try slider value
    local success2, result2 = pcall(function()
        local values = ffi.new("SliderCellDetails")
        if C.GetSliderCellValues(cellWidgetID, values) then
            return tostring(math.floor(values.start))
        end
        return nil
    end)
    if success2 and result2 and result2 ~= "" then
        value = result2
        debugLog("GetSliderCellValues returned: " .. result2)
    end

    -- 3. Try button text (for toggle On/Off buttons in settings)
    if not value then
        local success3, result3 = pcall(function()
            if IsType and IsType(cellWidgetID, "button") then
                debugLog("Widget " .. cellWidgetID .. " IS a button")
                -- GetButtonText is a global Lua function (not FFI)
                if GetButtonText then
                    local buttonText = GetButtonText(cellWidgetID)
                    if buttonText and buttonText ~= "" then
                        debugLog("GetButtonText returned: " .. buttonText)
                        return buttonText
                    end
                end
            end
            return nil
        end)
        if success3 and result3 then
            value = result3
        end
    end

    -- 4. Try dropdown selected text (iterate options to find current selection)
    if not value then
        local success4, result4 = pcall(function()
            if IsType and IsType(cellWidgetID, "dropdown") then
                debugLog("Widget " .. cellWidgetID .. " IS a dropdown")
                -- Get the current selected option ID
                local startOption = ffi.string(C.GetDropDownStartOption(cellWidgetID))
                debugLog("Dropdown startOption ID: " .. tostring(startOption))
                if startOption and startOption ~= "" then
                    -- Get all options and find the matching one
                    local numOptions = C.GetNumDropDownOptions(cellWidgetID)
                    debugLog("Dropdown has " .. tostring(numOptions) .. " options")
                    if numOptions > 0 then
                        local buf = ffi.new("DropDownOption2[?]", numOptions)
                        local n = C.GetDropDownOptions2(buf, numOptions, cellWidgetID)
                        for i = 0, n - 1 do
                            local optionId = ffi.string(buf[i].id)
                            if optionId == startOption then
                                local text = ffi.string(buf[i].text)
                                if text and text ~= "" then
                                    debugLog("Dropdown selected: " .. text)
                                    return text
                                end
                                break
                            end
                        end
                    end
                end
            end
            return nil
        end)
        if success4 and result4 then
            value = result4
        end
    end

    -- 5. Try checkbox state - USE IsType() to verify it's a checkbox first
    if not value then
        local success5, result5 = pcall(function()
            -- First check if this widget is actually a checkbox using IsType
            if IsType and IsType(cellWidgetID, "checkbox") then
                debugLog("Widget " .. cellWidgetID .. " IS a checkbox")
                -- Use IsCheckBoxChecked directly (IsCheckBoxActive checks if enabled, not if exists)
                if C.IsCheckBoxChecked(cellWidgetID) then
                    return "On"
                else
                    return "Off"
                end
            else
                -- Log what type it is for debugging (helps identify the correct column)
                if IsType then
                    local widgetType = "unknown"
                    for _, t in ipairs({"checkbox", "button", "text", "icon", "slidercell", "dropdown"}) do
                        if IsType(cellWidgetID, t) then
                            widgetType = t
                            break
                        end
                    end
                    if widgetType ~= "unknown" then
                        debugLog("Widget " .. cellWidgetID .. " is type: " .. widgetType)
                    end
                end
            end
            return nil
        end)
        if success5 and result5 then
            value = result5
            debugLog("Checkbox state: " .. result5)
        end
    end

    -- 6. ALWAYS try GetMouseOverText for tooltip (even if we have label)
    local success6, result6 = pcall(function()
        return ffi.string(C.GetMouseOverText(cellWidgetID))
    end)
    if success6 and result6 and result6 ~= "" then
        tooltip = result6
        debugLog("GetMouseOverText returned: " .. result6)
    end

    -- Combine: label + value + tooltip
    local parts = {}
    if label then table.insert(parts, label) end
    if value then table.insert(parts, value) end
    if tooltip and tooltip ~= label then  -- Don't repeat if tooltip == label
        table.insert(parts, tooltip)
    end

    if #parts > 0 then
        return table.concat(parts, ". ")  -- Use period for natural speech separation
    end

    debugLog("All methods failed, returning widget ID: " .. tostring(cellWidgetID))
    return "Item " .. tostring(cellWidgetID)
end

-- Try to get the text of the current selection
local function getCurrentSelectionText()
    -- Get active frame (current menu)
    local frame = GetActiveFrame and GetActiveFrame()
    if not frame then
        return nil
    end

    -- Get the currently focused widget (usually a table)
    local widget = GetInteractiveObject and GetInteractiveObject(frame)
    if not widget then
        return nil
    end

    -- Get the current row from Helper's tracking
    local row = nil
    if Helper and Helper.currentTableRow then
        row = Helper.currentTableRow[widget]
    end

    if not row then
        return nil
    end

    -- Check if this is a new selection
    if widget == NVDA.lastWidget and row == NVDA.lastRow then
        return nil -- Same selection, don't repeat
    end

    NVDA.lastWidget = widget
    NVDA.lastRow = row

    -- Try to get text from cells in this row
    local text = nil
    local fallbackText = nil

    -- Try columns 1-5 to find ALL text (name AND value)
    for col = 1, 5 do
        pcall(function()
            local cell = GetCellContent(widget, row, col)
            if cell then
                local cellText = getTextFromCell(cell)
                if cellText and cellText ~= "" then
                    -- Check if this is the "Item X" fallback (widget ID)
                    if cellText:match("^Item %d+$") then
                        -- Save as fallback only - don't include in main text
                        if not fallbackText then
                            fallbackText = cellText
                        end
                    else
                        -- Real text found - include it
                        if text then
                            text = text .. ", " .. cellText
                        else
                            text = cellText
                        end
                    end
                end
            end
        end)
        -- DON'T break early - continue to read ALL columns for values!
    end

    -- Only use fallback if no real text was found
    return text or fallbackText
end

-- Called when we detect navigation happened
local function onNavigationDetected()
    local text = getCurrentSelectionText()
    if text then
        speakText(text)
    end
end

-- Wrap PlaySound to detect UI navigation
local function setupPlaySoundHook()
    if not PlaySound then
        debugLog("WARNING: PlaySound not available")
        return false
    end

    local originalPlaySound = PlaySound

    -- Replace PlaySound with our wrapper
    PlaySound = function(soundname, ...)
        -- Detect navigation sounds
        if soundname == "ui_positive_hover_normal" then
            -- User navigated to a new item
            onNavigationDetected()
        elseif soundname == "ui_positive_select" then
            -- User selected an item
            debugLog("Item selected")
        end

        -- Call original function
        return originalPlaySound(soundname, ...)
    end

    debugLog("PlaySound hook installed")
    return true
end

-- Initialize the module
local function init()
    debugLog("Initializing NVDA Accessibility...")
    debugLog("Current initialized state: " .. tostring(NVDA.initialized))

    if NVDA.initialized then
        debugLog("Already initialized - skipping")
        return
    end

    -- Check available globals
    debugLog("Checking available globals...")
    debugLog("PlaySound available: " .. tostring(PlaySound ~= nil))
    debugLog("Helper available: " .. tostring(Helper ~= nil))
    debugLog("GetActiveFrame available: " .. tostring(GetActiveFrame ~= nil))
    debugLog("GetInteractiveObject available: " .. tostring(GetInteractiveObject ~= nil))
    debugLog("GetCellContent available: " .. tostring(GetCellContent ~= nil))
    debugLog("GetCurRealTime available: " .. tostring(GetCurRealTime ~= nil))

    -- Setup PlaySound hook to detect navigation
    debugLog("Setting up PlaySound hook...")
    local hookResult = setupPlaySoundHook()
    debugLog("PlaySound hook result: " .. tostring(hookResult))

    -- Communication uses MD relay (Lua cannot access pipes directly)
    debugLog("Using MD relay for NVDA communication (via SirNukes Named_Pipes API)")

    NVDA.initialized = true
    debugLog("=== NVDA Accessibility Initialized ===")

    -- Announce ready
    debugLog("Announcing ready...")
    speakText("X4 Accessibility ready")
end

-- Handle enable/disable from options
local function setEnabled(enabled)
    NVDA.enabled = (enabled == 1 or enabled == true)
    debugLog("Enabled: " .. tostring(NVDA.enabled))
    if NVDA.enabled then
        speakText("NVDA enabled")
    end
end

-- Register for events from MD script
debugLog("Checking event registration options...")
debugLog("RegisterEvent available: " .. tostring(RegisterEvent ~= nil))
debugLog("Register_OnLoad_Init available: " .. tostring(Register_OnLoad_Init ~= nil))

if RegisterEvent then
    debugLog("Registering for MD events via RegisterEvent...")

    RegisterEvent("NVDA.Init", function(_, param)
        debugLog("NVDA.Init event received with param: " .. tostring(param))
        init()
    end)

    RegisterEvent("NVDA.SetEnabled", function(_, param)
        debugLog("NVDA.SetEnabled event received with param: " .. tostring(param))
        setEnabled(param)
    end)

    RegisterEvent("NVDA.SetVerbosity", function(_, param)
        debugLog("NVDA.SetVerbosity event received with param: " .. tostring(param))
    end)

    debugLog("MD event registration complete")
else
    debugLog("WARNING: RegisterEvent not available - trying alternative methods")
end

-- Use SirNukes delayed init if available (primary initialization method)
if Register_OnLoad_Init then
    debugLog("Using Register_OnLoad_Init for delayed initialization...")
    Register_OnLoad_Init(init, "NVDA_Accessibility")
    debugLog("Register_OnLoad_Init callback registered")
else
    debugLog("Register_OnLoad_Init not available")
    -- Fallback: try to initialize immediately if in a loaded game
    debugLog("Attempting immediate initialization as fallback...")
    -- Delay slightly to ensure other systems are ready
    local success, err = pcall(function()
        init()
    end)
    if not success then
        debugLog("Immediate init failed: " .. tostring(err))
    end
end

-- Export for debugging
_G.NVDA_Accessibility = NVDA
_G.NVDA_Speak = speakText

debugLog("=== NVDA Accessibility Module Loaded ===")
print("[NVDA] ========================================")
print("[NVDA] NVDA Accessibility Module fully loaded!")
print("[NVDA] Check debug.txt for [NVDA] messages")
print("[NVDA] ========================================")
