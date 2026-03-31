-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                         iSealTwist — Options Panel                             │
-- ╰────────────────────────────────────────────────────────────────────────────────╯

local addonName, iST = ...
local L = iST.L or {}
local Colors = iST.Colors or {}
local print = function(...) iST:PrintToChat(...) end

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local CHECKBOX_TEMPLATE = InterfaceOptionsCheckButtonTemplate and "InterfaceOptionsCheckButtonTemplate" or "UICheckButtonTemplate"

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                              Helper Functions                                  │
-- ╰────────────────────────────────────────────────────────────────────────────────╯

local function CreateSectionHeader(parent, text, yOffset)
    local header = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    header:SetHeight(24)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    if header.SetBackdrop then
        header:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
        header:SetBackdropColor(0.15, 0.15, 0.2, 0.6)
    end

    local accent = header:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(1)
    accent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    accent:SetColorTexture(1, 0.59, 0.09, 0.4)

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", header, "LEFT", 8, 0)
    label:SetText(text)

    return header, yOffset - 28
end

local function CreateSettingsCheckbox(parent, label, descText, yOffset, getFunc, setFunc)
    local cb = CreateFrame("CheckButton", nil, parent, CHECKBOX_TEMPLATE)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    if not cb.Text then
        cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cb.Text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    end
    cb.Text:SetText(label)
    cb.Text:SetFontObject(GameFontHighlight)
    cb:SetChecked(getFunc())
    cb:SetScript("OnClick", function(self)
        setFunc(self:GetChecked() and true or false)
    end)

    local nextY = yOffset - 22
    if descText and descText ~= "" then
        local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 48, nextY)
        desc:SetWidth(350)
        desc:SetJustifyH("LEFT")
        desc:SetText(descText)
        local height = desc:GetStringHeight()
        if height < 12 then height = 12 end
        nextY = nextY - height - 6
    end

    return cb, nextY
end

-- Custom slider bar (no OptionsSliderTemplate dependency)
local function CreateCustomSlider(parent, label, yOffset, minVal, maxVal, step, getFunc, setFunc, formatFunc)
    local ROW_HEIGHT = 36
    local TRACK_WIDTH = 250
    local TRACK_HEIGHT = 8
    local THUMB_WIDTH = 14
    local THUMB_HEIGHT = 18

    -- Label + value text
    local sliderLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sliderLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    sliderLabel:SetText(label)

    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("LEFT", sliderLabel, "RIGHT", 10, 0)

    local function UpdateValueText(val)
        if formatFunc then
            valueText:SetText(Colors.iST .. formatFunc(val))
        else
            valueText:SetText(Colors.iST .. tostring(val))
        end
    end

    -- Track frame (clickable background)
    local track = CreateFrame("Frame", nil, parent)
    track:SetSize(TRACK_WIDTH, TRACK_HEIGHT)
    track:SetPoint("TOPLEFT", parent, "TOPLEFT", 25, yOffset - 16)
    track:EnableMouse(true)

    -- Track background
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.15, 0.15, 0.2, 0.8)

    -- Track border
    local trackBorder = track:CreateTexture(nil, "ARTWORK", nil, -1)
    trackBorder:SetPoint("TOPLEFT", track, "TOPLEFT", -1, 1)
    trackBorder:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 1, -1)
    trackBorder:SetColorTexture(0.3, 0.3, 0.3, 0.6)

    -- Fill bar (shows current value proportion)
    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(1)
    fill:SetColorTexture(1, 0.59, 0.09, 0.7)

    -- Thumb (draggable knob)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetSize(THUMB_WIDTH, THUMB_HEIGHT)
    thumb:EnableMouse(true)

    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(1, 0.59, 0.09, 0.9)

    local thumbBorder = thumb:CreateTexture(nil, "OVERLAY", nil, 1)
    thumbBorder:SetPoint("TOPLEFT", thumb, "TOPLEFT", -1, 1)
    thumbBorder:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", 1, -1)
    thumbBorder:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    -- Position thumb + fill based on value
    local function SetVisualValue(val)
        val = math.max(minVal, math.min(maxVal, val))
        local fraction = (val - minVal) / (maxVal - minVal)
        local xPos = fraction * (TRACK_WIDTH - THUMB_WIDTH)
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", track, "LEFT", xPos, 0)
        fill:SetWidth(math.max(1, fraction * TRACK_WIDTH))
        UpdateValueText(val)
    end

    -- Snap value to step
    local function SnapValue(val)
        return math.floor((val - minVal) / step + 0.5) * step + minVal
    end

    -- Get value from mouse x position on track
    local function ValueFromMouse()
        local cx = select(1, GetCursorPosition()) / UIParent:GetEffectiveScale()
        local left = track:GetLeft()
        local fraction = (cx - left) / TRACK_WIDTH
        fraction = math.max(0, math.min(1, fraction))
        local raw = minVal + fraction * (maxVal - minVal)
        return SnapValue(raw)
    end

    -- Drag state
    local isDragging = false

    thumb:SetScript("OnMouseDown", function()
        isDragging = true
    end)
    thumb:SetScript("OnMouseUp", function()
        isDragging = false
    end)

    -- Track click to jump
    track:SetScript("OnMouseDown", function()
        local val = ValueFromMouse()
        setFunc(val)
        SetVisualValue(val)
        isDragging = true
    end)
    track:SetScript("OnMouseUp", function()
        isDragging = false
    end)

    -- OnUpdate for drag
    track:SetScript("OnUpdate", function()
        if not isDragging then return end
        local val = ValueFromMouse()
        setFunc(val)
        SetVisualValue(val)
    end)

    -- Mouse wheel on track
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta)
        local current = getFunc()
        local newVal = SnapValue(current + delta * step)
        newVal = math.max(minVal, math.min(maxVal, newVal))
        setFunc(newVal)
        SetVisualValue(newVal)
    end)

    -- Initialize
    SetVisualValue(getFunc())

    return track, yOffset - ROW_HEIGHT
end

local function CreateSettingsButton(parent, text, width, yOffset, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 26)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn, yOffset - 34
end

-- ╭────────────────────────────────────────────────────────────────────────────────╮
-- │                           Create Options Panel                                 │
-- ╰────────────────────────────────────────────────────────────────────────────────╯
function iST:CreateOptionsPanel()
    if self.SettingsFrame then return end

    -- Main frame
    local frame = CreateFrame("Frame", "iSTSettingsFrame", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(450, 480)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("DIALOG")

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        })
        frame:SetBackdropColor(0.07, 0.07, 0.12, 0.95)
    end

    -- Drag
    frame:SetScript("OnMouseDown", function(self) self:StartMoving() end)
    frame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText(L["SettingsTitle"])

    -- Scroll frame (invisible scrollbar, mousewheel only)
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -42)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8)

    -- Hide the scrollbar
    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName() and (scrollFrame:GetName() .. "ScrollBar")]
    if scrollBar then scrollBar:SetAlpha(0) scrollBar:SetWidth(1) end

    -- Content child (tall enough for all settings)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth())
    content:SetHeight(700) -- will be adjusted at end
    scrollFrame:SetScrollChild(content)

    -- Enable mousewheel on the main frame too
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local current = scrollFrame:GetVerticalScroll()
        local maxScroll = content:GetHeight() - scrollFrame:GetHeight()
        local newScroll = math.max(0, math.min(maxScroll, current - delta * 30))
        scrollFrame:SetVerticalScroll(newScroll)
    end)

    local yOffset = 0

    -- ═══════════════════════════════════════════════════════════
    -- Bar Appearance
    -- ═══════════════════════════════════════════════════════════
    _, yOffset = CreateSectionHeader(content, L["SectionBarAppearance"], yOffset)

    _, yOffset = CreateCustomSlider(content, L["BarWidth"], yOffset, 100, 500, 10,
        function() return iSTSettings.barWidth end,
        function(v)
            iSTSettings.barWidth = v
            if iST.BarFrame then iST.BarFrame:SetWidth(v) end
        end,
        function(v) return v .. "px" end
    )

    _, yOffset = CreateCustomSlider(content, L["BarHeight"], yOffset, 15, 50, 1,
        function() return iSTSettings.barHeight end,
        function(v)
            iSTSettings.barHeight = v
            if iST.BarFrame then
                iST.BarFrame:SetHeight(v)
                if iST.BarFrame.sealIcon then iST.BarFrame.sealIcon:SetSize(v, v) end
            end
        end,
        function(v) return v .. "px" end
    )

    -- ═══════════════════════════════════════════════════════════
    -- Twist Timing
    -- ═══════════════════════════════════════════════════════════
    _, yOffset = CreateSectionHeader(content, L["SectionTwistTiming"], yOffset)

    _, yOffset = CreateCustomSlider(content, L["TwistWindow"], yOffset, 200, 600, 10,
        function() return iSTSettings.twistWindow * 1000 end,
        function(v) iSTSettings.twistWindow = v / 1000 end,
        function(v) return v .. "ms" end
    )

    local twistDesc = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    twistDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yOffset)
    twistDesc:SetWidth(350)
    twistDesc:SetText(L["TwistWindowDesc"])
    yOffset = yOffset - 16

    _, yOffset = CreateSettingsCheckbox(content, L["ShowLatency"], L["ShowLatencyDesc"], yOffset,
        function() return iSTSettings.showLatency end,
        function(v) iSTSettings.showLatency = v end
    )

    -- ═══════════════════════════════════════════════════════════
    -- Display
    -- ═══════════════════════════════════════════════════════════
    _, yOffset = CreateSectionHeader(content, L["SectionDisplay"], yOffset)

    _, yOffset = CreateSettingsCheckbox(content, L["ShowSealIcon"], L["ShowSealIconDesc"], yOffset,
        function() return iSTSettings.showSealIcon end,
        function(v)
            iSTSettings.showSealIcon = v
            iST:UpdateSealDisplay()
        end
    )

    _, yOffset = CreateSettingsCheckbox(content, L["ShowWeaponSpeed"], L["ShowWeaponSpeedDesc"], yOffset,
        function() return iSTSettings.showWeaponSpeed end,
        function(v) iSTSettings.showWeaponSpeed = v end
    )

    _, yOffset = CreateSettingsCheckbox(content, L["OnlyInCombat"], L["OnlyInCombatDesc"], yOffset,
        function() return iSTSettings.onlyInCombat end,
        function(v) iSTSettings.onlyInCombat = v end
    )

    _, yOffset = CreateSettingsCheckbox(content, L["OnlyAsPaladin"], L["OnlyAsPaladinDesc"], yOffset,
        function() return iSTSettings.onlyAsPaladin end,
        function(v) iSTSettings.onlyAsPaladin = v end
    )

    _, yOffset = CreateSettingsCheckbox(content, L["ShowTwistSuccess"], L["ShowTwistSuccessDesc"], yOffset,
        function() return iSTSettings.showTwistSuccess end,
        function(v) iSTSettings.showTwistSuccess = v end
    )

    _, yOffset = CreateSettingsCheckbox(content, L["ShowTwistFail"], L["ShowTwistFailDesc"], yOffset,
        function() return iSTSettings.showTwistFail end,
        function(v) iSTSettings.showTwistFail = v end
    )

    -- ═══════════════════════════════════════════════════════════
    -- Position
    -- ═══════════════════════════════════════════════════════════
    _, yOffset = CreateSectionHeader(content, L["SectionPosition"], yOffset)

    _, yOffset = CreateSettingsCheckbox(content, L["LockBar"], L["LockBarDesc"], yOffset,
        function() return iSTSettings.barLocked end,
        function(v) iSTSettings.barLocked = v end
    )

    local resetBtn
    resetBtn, yOffset = CreateSettingsButton(content, L["ResetPosition"], 130, yOffset, function()
        iST:ResetBarPosition()
    end)

    local testBtn
    testBtn, yOffset = CreateSettingsButton(content, L["TestBar"], 130, yOffset, function()
        iST:StartTestMode()
    end)

    -- ═══════════════════════════════════════════════════════════
    -- About
    -- ═══════════════════════════════════════════════════════════
    _, yOffset = CreateSectionHeader(content, L["SectionAbout"], yOffset)

    local aboutText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    aboutText:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    aboutText:SetWidth(380)
    aboutText:SetWordWrap(true)
    aboutText:SetText(L["AboutText"])
    yOffset = yOffset - aboutText:GetStringHeight() - 8

    local authorText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    authorText:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    authorText:SetText(Colors.Gray .. L["CreatedBy"] .. Colors.iST .. iST.Author)
    yOffset = yOffset - 20

    -- Set content height to fit all elements
    content:SetHeight(math.abs(yOffset) + 10)

    frame:Hide()
    self.SettingsFrame = frame
end
