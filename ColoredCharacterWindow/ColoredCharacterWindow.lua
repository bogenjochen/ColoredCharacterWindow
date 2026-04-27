local addonName = ...

ColoredCharacterWindowDB = ColoredCharacterWindowDB or {}

local CCW = CreateFrame("Frame")

local QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor
    [1] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common
    [2] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon
    [3] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare
    [4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic
    [5] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary
    [6] = { r = 0.90, g = 0.80, b = 0.50 }, -- Artifact / special
    [7] = { r = 0.00, g = 0.80, b = 1.00 }, -- Heirloom
}

local SLOT_TOKENS = {
    "HeadSlot",
    "NeckSlot",
    "ShoulderSlot",
    "BackSlot",
    "ChestSlot",
    "ShirtSlot",
    "TabardSlot",
    "WristSlot",

    "HandsSlot",
    "WaistSlot",
    "LegsSlot",
    "FeetSlot",
    "Finger0Slot",
    "Finger1Slot",
    "Trinket0Slot",
    "Trinket1Slot",

    "MainHandSlot",
    "SecondaryHandSlot",
    "RangedSlot",
    "AmmoSlot",
}

local borders = {}
local inspectHooksDone = false
local retryFrame = CreateFrame("Frame")
retryFrame:Hide()

local retryElapsed = 0
local retryDuration = 0

local function CreateBorderForSlot(slotButton)
    if not slotButton or borders[slotButton] then
        return
    end

    local border = CreateFrame("Frame", nil, slotButton)
    border:SetPoint("TOPLEFT", slotButton, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", slotButton, "BOTTOMRIGHT", 3, -3)

    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = {
            left = 3,
            right = 3,
            top = 3,
            bottom = 3,
        },
    })

    border:SetBackdropBorderColor(1, 1, 1, 0.6)
    border:Hide()

    borders[slotButton] = border
end

local function GetQualityFromItemLink(link)
    if not link then
        return nil
    end

    -- First try the normal item info cache.
    local _, _, quality = GetItemInfo(link)
    if quality then
        return quality
    end

    -- Fallback: parse item link color.
    -- Example: |cffa335ee|Hitem:...
    local color = string.match(link, "|c(%x%x%x%x%x%x%x%x)|Hitem:")
    if not color then
        return nil
    end

    color = string.lower(color)

    if color == "ff9d9d9d" then
        return 0 -- poor
    elseif color == "ffffffff" then
        return 1 -- common
    elseif color == "ff1eff00" then
        return 2 -- uncommon
    elseif color == "ff0070dd" then
        return 3 -- rare
    elseif color == "ffa335ee" then
        return 4 -- epic
    elseif color == "ffff8000" then
        return 5 -- legendary
    elseif color == "ffe6cc80" then
        return 6 -- artifact
    elseif color == "ff00ccff" then
        return 7 -- heirloom
    end

    return nil
end

local function GetItemQualityForUnit(unit, slotId)
    if not unit or not slotId then
        return nil
    end

    local quality = GetInventoryItemQuality(unit, slotId)
    if quality then
        return quality
    end

    local link = GetInventoryItemLink(unit, slotId)
    if link then
        return GetQualityFromItemLink(link)
    end

    return nil
end

local function UpdateSlotBorder(buttonName, unit, slotToken)
    local slotButton = _G[buttonName]
    if not slotButton then
        return
    end

    CreateBorderForSlot(slotButton)

    local border = borders[slotButton]
    if not border then
        return
    end

    local slotId = GetInventorySlotInfo(slotToken)
    if not slotId then
        border:Hide()
        return
    end

    local quality = GetItemQualityForUnit(unit, slotId)

    if quality and QUALITY_COLORS[quality] then
        local color = QUALITY_COLORS[quality]
        border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        border:Show()
    else
        border:Hide()
    end
end

local function UpdateCharacterBorders()
    for _, slotToken in ipairs(SLOT_TOKENS) do
        UpdateSlotBorder("Character" .. slotToken, "player", slotToken)
    end
end

local function GetInspectUnit()
    if InspectFrame and InspectFrame.unit then
        return InspectFrame.unit
    end

    if UnitExists("target") and UnitIsPlayer("target") then
        return "target"
    end

    return nil
end

local function UpdateInspectBorders()
    local unit = GetInspectUnit()
    if not unit then
        return
    end

    for _, slotToken in ipairs(SLOT_TOKENS) do
        UpdateSlotBorder("Inspect" .. slotToken, unit, slotToken)
    end
end

local function UpdateAllBorders()
    UpdateCharacterBorders()
    UpdateInspectBorders()
end

local function StartInspectRetry()
    retryElapsed = 0
    retryDuration = 2.5
    retryFrame:Show()
end

retryFrame:SetScript("OnUpdate", function(self, elapsed)
    retryElapsed = retryElapsed + elapsed

    UpdateInspectBorders()

    if retryElapsed >= retryDuration then
        self:Hide()
    end
end)

local function HookInspectFrames()
    if inspectHooksDone then
        return
    end

    if not InspectFrame then
        return
    end

    inspectHooksDone = true

    InspectFrame:HookScript("OnShow", function()
        UpdateInspectBorders()
        StartInspectRetry()
    end)

    if InspectPaperDollFrame then
        InspectPaperDollFrame:HookScript("OnShow", function()
            UpdateInspectBorders()
            StartInspectRetry()
        end)
    end
end

local function HookCharacterFrames()
    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", function()
            UpdateCharacterBorders()
        end)
    end

    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", function()
            UpdateCharacterBorders()
        end)
    end
end

CCW:RegisterEvent("PLAYER_LOGIN")
CCW:RegisterEvent("ADDON_LOADED")
CCW:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
CCW:RegisterEvent("UNIT_INVENTORY_CHANGED")
CCW:RegisterEvent("ITEM_LOCK_CHANGED")
CCW:RegisterEvent("BAG_UPDATE")
CCW:RegisterEvent("INSPECT_READY")
CCW:RegisterEvent("PLAYER_TARGET_CHANGED")

CCW:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        HookCharacterFrames()
        HookInspectFrames()
        UpdateAllBorders()

    elseif event == "ADDON_LOADED" then
        if arg1 == "Blizzard_InspectUI" then
            HookInspectFrames()
            UpdateInspectBorders()
            StartInspectRetry()
        end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        UpdateCharacterBorders()

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            UpdateCharacterBorders()
        else
            UpdateAllBorders()
        end

    elseif event == "INSPECT_READY" then
        HookInspectFrames()
        UpdateInspectBorders()
        StartInspectRetry()

    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateInspectBorders()
        StartInspectRetry()

    else
        UpdateAllBorders()
    end
end)

SLASH_COLOREDCHARACTERWINDOW1 = "/ccw"

SlashCmdList["COLOREDCHARACTERWINDOW"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "update" then
        UpdateAllBorders()
        DEFAULT_CHAT_FRAME:AddMessage("|cffaa33ffColoredCharacterWindow:|r Borders updated.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffaa33ffColoredCharacterWindow:|r This addon updates character and inspect borders automatically.")
        DEFAULT_CHAT_FRAME:AddMessage("|cffaa33ffColoredCharacterWindow:|r /ccw update - manual refresh")
    end
end