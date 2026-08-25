local folderName, addon = ...

-- SpellIconOverlay module
-- Adds overlay icon to spellbook spells included in single button assist

local rotationSpellsCache = nil
local isHooked = false
local eventFrame = CreateFrame("Frame")

local function UpdateRotationSpellsCache()
  if C_AssistedCombat and C_AssistedCombat.GetRotationSpells then
    local spells = C_AssistedCombat.GetRotationSpells()
    rotationSpellsCache = {}
    if spells then
      for _, id in ipairs(spells) do
        rotationSpellsCache[id] = true
      end
    end
  else
    rotationSpellsCache = false
  end
end

local function IsSpellInRotation(spellID)
  if rotationSpellsCache == nil then
    UpdateRotationSpellsCache()
  end
  
  if rotationSpellsCache then
    return rotationSpellsCache[spellID]
  end
  return false
end

-- Action Bar Overlay Logic
local actionButtonSets = {
  { prefix = "ActionButton", count = 12 },
  { prefix = "MultiBarBottomLeftButton", count = 12 },
  { prefix = "MultiBarBottomRightButton", count = 12 },
  { prefix = "MultiBarRightButton", count = 12 },
  { prefix = "MultiBarLeftButton", count = 12 },
  { prefix = "MultiBar5Button", count = 12 },
  { prefix = "MultiBar6Button", count = 12 },
  { prefix = "MultiBar7Button", count = 12 },
  { prefix = "BT4Button", count = 180, requiresAddOn = "Bartender4" }, -- Bartender4 (15 bars x 12 buttons)
}

local isActionSpellOnActionBar = false

-- Creates the overlay holder frame (rotating icon + shadow) on a button, if not already present.
-- frameLevel controls stacking within the MEDIUM strata: action bar buttons need a high fixed
-- level (100) to sit above the AssistedCombatHighlightFrame (MEDIUM, level 99), while talent
-- buttons pass a level well above the button so the overlay clears the tree's edge arrows (see
-- the call site in UpdateTalentButtonOverlay).
local function EnsureOverlayFrame(button, frameLevel)
  if button.LudiusPlusOverlayFrame then return end

  button.LudiusPlusOverlayFrame = CreateFrame("Frame", nil, button)
  button.LudiusPlusOverlayFrame:SetFrameStrata("MEDIUM")
  button.LudiusPlusOverlayFrame:SetFrameLevel(frameLevel)

  -- Create the icon texture on the frame. Sublevel 3 leaves room above the icon for the talent rank
  -- number copies: shadow strings at OVERLAY 5, the number at OVERLAY 7 (see SetTalentSpendTextAboveOverlay).
  button.LudiusPlusOverlay = button.LudiusPlusOverlayFrame:CreateTexture(nil, "OVERLAY", nil, 3)
  button.LudiusPlusOverlay:SetAtlas("UI-RefreshButton")

  -- Rotate 90 degrees counter-clockwise
  button.LudiusPlusOverlay:SetRotation(math.rad(90))

  button.LudiusPlusOverlay:SetAllPoints(button.LudiusPlusOverlayFrame)

  -- Shadow
  button.LudiusPlusShadow = button.LudiusPlusOverlayFrame:CreateTexture(nil, "OVERLAY", nil, 2)
  button.LudiusPlusShadow:SetAtlas("Garr_BuildingShadowOverlay")
  button.LudiusPlusShadow:SetAlpha(0.7)
  button.LudiusPlusShadow:SetPoint("CENTER", button.LudiusPlusOverlay, "CENTER", 0, 0)
end

-- Fine-tuning for the action bar overlay.
local ACTIONBAR_OVERLAY_SIZE = 16
local ACTIONBAR_OVERLAY_OFFSETS = {
  TOPLEFT     = { x = 0, y = 0 },
  TOPRIGHT    = { x = 0, y = 0 },
  BOTTOMLEFT  = { x = 0, y = 0 },
  BOTTOMRIGHT = { x = 0, y = 0 },
}

local function UpdateActionBarButtonOverlay(button)
  if not button then return end

  -- No need to check for enabled state here, as the teardown unregisters all events leading to this function.

  EnsureOverlayFrame(button, 100)

  -- Apply size (icon fills the frame; the shadow keeps the icon's original 25/16 proportion).
  local size = ACTIONBAR_OVERLAY_SIZE
  button.LudiusPlusOverlayFrame:SetSize(size, size)
  if button.LudiusPlusShadow then
    button.LudiusPlusShadow:SetSize(size * 25 / 16, size * 25 / 16)
  end

  -- Update position (always, to handle position/offset changes). Each anchor corner has its own offset.
  local position = (LP_config and LP_config.spellIconOverlay_actionBarPosition) or "BOTTOMLEFT"
  local offset = ACTIONBAR_OVERLAY_OFFSETS[position]
  local offsetX = offset and offset.x or 0
  local offsetY = offset and offset.y or 0
  button.LudiusPlusOverlayFrame:ClearAllPoints()
  button.LudiusPlusOverlayFrame:SetPoint(position, button, position, offsetX, offsetY)

  local showOverlay = false
  if LP_config and LP_config.spellIconOverlay_showOnActionBars then
    if not LP_config.spellIconOverlay_onlyWhenAssistUsed or isActionSpellOnActionBar then
      local action = button.action
      if action then
        local type, id = GetActionInfo(action)
        if type == "spell" and id then
          -- Check if it is the single button assist spell itself, because we don't want the overlay for that one.
          if not (button.AssistedCombatRotationFrame and button.AssistedCombatRotationFrame:IsShown()) then
            if IsSpellInRotation(id) then
              showOverlay = true
            end
          end
        end
      end
    end
  end

  button.LudiusPlusOverlayFrame:SetShown(showOverlay)
end

local function CheckIfActionSpellIsOnActionBar()
  isActionSpellOnActionBar = false

  -- Only Blizzard's own buttons ever get an AssistedCombatRotationFrame, so
  -- addon-provided sets (which set requiresAddOn) can be skipped here.
  for _, entry in ipairs(actionButtonSets) do
    if not entry.requiresAddOn then
      for i = 1, entry.count do
        local button = _G[entry.prefix .. i]
        if button then
          if button.AssistedCombatRotationFrame and button.AssistedCombatRotationFrame:IsShown() then
            isActionSpellOnActionBar = true
            return
          end
        end
      end
    end
  end
end

local function UpdateAllActionBarOverlays()
  CheckIfActionSpellIsOnActionBar()
  for _, entry in ipairs(actionButtonSets) do
    if not entry.requiresAddOn or C_AddOns.IsAddOnLoaded(entry.requiresAddOn) then
      for i = 1, entry.count do
        local button = _G[entry.prefix .. i]
        if button then
          UpdateActionBarButtonOverlay(button)
        end
      end
    end
  end
end

-- Fine-tuning for the spellbook overlay.
local SPELLBOOK_OVERLAY_SIZE = 20
local SPELLBOOK_OVERLAY_OFFSETS = {
  TOPLEFT     = { x = -3, y = 2 },
  TOPRIGHT    = { x = 2, y = 2 },
  BOTTOMLEFT  = { x = -3, y = -2 },
  BOTTOMRIGHT = { x = 2, y = -2 },
}

local function UpdateSpellbookOverlay(button)
  if not button.Button then return end

  -- If disabled but already hooked due to previous enablement, ensure hidden and return early to avoid creating textures
  if not (LP_config and LP_config.spellIconOverlay_showInSpellbook) then
    if button.Button.LudiusPlusOverlay then
      button.Button.LudiusPlusOverlay:Hide()
      if button.Button.LudiusPlusShadow then
        button.Button.LudiusPlusShadow:Hide()
      end
    end
    return
  end

  if not button.Button.LudiusPlusOverlay then
    button.Button.LudiusPlusOverlay = button.Button:CreateTexture(nil, "OVERLAY", nil, 7)
    button.Button.LudiusPlusOverlay:SetAtlas("UI-RefreshButton")
    
    -- Rotate 90 degrees counter-clockwise
    button.Button.LudiusPlusOverlay:SetRotation(math.rad(90))

    -- Shadow
    button.Button.LudiusPlusShadow = button.Button:CreateTexture(nil, "OVERLAY", nil, 6)
    button.Button.LudiusPlusShadow:SetAtlas("Garr_BuildingShadowOverlay")
    button.Button.LudiusPlusShadow:SetAlpha(0.7)
    button.Button.LudiusPlusShadow:SetPoint("CENTER", button.Button.LudiusPlusOverlay, "CENTER", 0, 0)
  end

  -- Apply size (the shadow keeps the icon's original 25/16 proportion).
  local size = SPELLBOOK_OVERLAY_SIZE
  button.Button.LudiusPlusOverlay:SetSize(size, size)
  if button.Button.LudiusPlusShadow then
    button.Button.LudiusPlusShadow:SetSize(size * 25 / 16, size * 25 / 16)
  end

  -- Update position (always, to handle position/offset changes). Each anchor corner has its own offset.
  local position = (LP_config and LP_config.spellIconOverlay_spellbookPosition) or "BOTTOMLEFT"
  local offset = SPELLBOOK_OVERLAY_OFFSETS[position]
  local offsetX = offset and offset.x or 0
  local offsetY = offset and offset.y or 0
  button.Button.LudiusPlusOverlay:ClearAllPoints()
  button.Button.LudiusPlusOverlay:SetPoint(position, button.Button, position, offsetX, offsetY)
  
  local showOverlay = false
  
  if button.spellBookItemInfo then
    local spellID = button.spellBookItemInfo.spellID
    if spellID then
      if IsSpellInRotation(spellID) then
        showOverlay = true
      end
    end
  end
  
  button.Button.LudiusPlusOverlay:SetShown(showOverlay)
  if button.Button.LudiusPlusShadow then
    button.Button.LudiusPlusShadow:SetShown(showOverlay)
  end
end

local function HookSpellBookItemMixin()
  if isHooked then return end
  if not SpellBookItemMixin then return end
  hooksecurefunc(SpellBookItemMixin, "UpdateSpellData", function(self)
    UpdateSpellbookOverlay(self)
  end)
  isHooked = true
end

-- Talent Tree Overlay Logic

-- Fine-tuning for the talent overlay.
local TALENT_OVERLAY_SIZE = 23
local TALENT_OVERLAY_OFFSETS = {
  TOPLEFT     = { x = -5, y = 3 },
  TOPRIGHT    = { x = 5, y = 3 },
  BOTTOMLEFT  = { x = -5, y = -4 },
  BOTTOMRIGHT = { x = 5, y = -4 },
}

local isTalentFrameHooked = false

local function GetTalentsFrame()
  return PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame or nil
end

-- The talent's rank number is Blizzard's SpendText (white glyph, OVERLAY on the button) plus four
-- black drop-shadow FontStrings (button.spendTextShadows, ARTWORK, offset +-1px). Our overlay frame
-- is raised to button frame level + 100 to clear the tree's edge arrows (see UpdateTalentButtonOverlay);
-- because a child frame draws above its whole parent, that same raise puts the icon above the number
-- AND its shadows. Moving Blizzard's own strings proved unreliable, so we draw our own copy of the
-- whole unit - four black shadow strings, then the number - inside the overlay frame above the icon,
-- mirroring Blizzard's font, text, color and shadow offsets. Blizzard's originals are blanked (alpha 0)
-- while ours show, so their semi-transparent shadow fringes don't stack with ours where the number
-- peeks past the icon edge; alpha is restored when our copies aren't active.
--
-- Note for future work: this took far too long because it was debugged by assumption. The turning
-- point was dumping real GetRect() + GetDrawLayer() for every region in-game, which showed at once
-- that the number sits inside the icon and its shadow is a separate, lower draw layer. For any
-- occlusion/layering puzzle, gather that geometry FIRST. See memory: layering-bugs-measure-first.
local SPEND_SHADOW_OFFSETS = { {-1, 1}, {1, 1}, {-1, -1}, {1, -1} }  -- matches SpendTextShadow1..4

local function EnsureTalentSpendClones(button)
  if button.LudiusPlusSpendText then return end
  local overlayFrame = button.LudiusPlusOverlayFrame

  -- Shadows below (OVERLAY 5), number above them (OVERLAY 7); both clear the icon (OVERLAY 3).
  button.LudiusPlusSpendShadows = {}
  for i = 1, 4 do
    local shadow = overlayFrame:CreateFontString(nil, "OVERLAY", "SystemFont16_Shadow_ThickOutline")
    shadow:SetDrawLayer("OVERLAY", 5)
    shadow:SetJustifyH("CENTER")
    button.LudiusPlusSpendShadows[i] = shadow
  end

  local num = overlayFrame:CreateFontString(nil, "OVERLAY", "SystemFont16_Shadow_ThickOutline")
  num:SetDrawLayer("OVERLAY", 7)
  num:SetJustifyH("CENTER")
  button.LudiusPlusSpendText = num
end

local function SetTalentSpendTextAboveOverlay(button, aboveOverlay)
  local overlayFrame = button.LudiusPlusOverlayFrame
  if not overlayFrame then return end

  local orig = button.SpendText
  local text = orig and orig:IsShown() and orig:GetText()
  if aboveOverlay and text and text ~= "" then
    EnsureTalentSpendClones(button)
    local num = button.LudiusPlusSpendText
    local fontObj = orig:GetFontObject()

    -- Read the number's colour while the original is still opaque: GetTextColor() reflects the region's
    -- alpha, so reading it after we blank the original (below) would hand our copy a transparent colour -
    -- which is exactly why the clone number was invisible while the hard-coded-black shadows were fine.
    orig:SetAlpha(1)
    local r, g, b = orig:GetTextColor()

    -- The number, anchored exactly where the template puts SpendText (BOTTOM of the button, +11,+4).
    if fontObj then num:SetFontObject(fontObj) end
    num:SetText(text)
    num:SetTextColor(r, g, b)
    num:ClearAllPoints()
    num:SetPoint("BOTTOM", button, "BOTTOM", 11, 4)
    num:Show()

    -- Four black drop shadows around the number, mirroring SpendTextShadow1..4.
    for i, shadow in ipairs(button.LudiusPlusSpendShadows) do
      if fontObj then shadow:SetFontObject(fontObj) end
      shadow:SetTextColor(0, 0, 0)
      shadow:SetText(text)
      shadow:ClearAllPoints()
      shadow:SetPoint("CENTER", num, "CENTER", SPEND_SHADOW_OFFSETS[i][1], SPEND_SHADOW_OFFSETS[i][2])
      shadow:Show()
    end

    -- Blank Blizzard's originals so their semi-transparent shadow fringes don't stack with our copies
    -- where the number peeks past the icon. Alpha (not Hide) keeps IsShown()/GetText() intact for the
    -- read above, and Blizzard never touches region alpha, so there is no flicker. Restored in else.
    orig:SetAlpha(0)
    if button.spendTextShadows then
      for _, shadow in ipairs(button.spendTextShadows) do shadow:SetAlpha(0) end
    end
  else
    if button.LudiusPlusSpendText then button.LudiusPlusSpendText:Hide() end
    if button.LudiusPlusSpendShadows then
      for _, shadow in ipairs(button.LudiusPlusSpendShadows) do shadow:Hide() end
    end
    if orig then
      orig:SetAlpha(1)
      if button.spendTextShadows then
        for _, shadow in ipairs(button.spendTextShadows) do shadow:SetAlpha(1) end
      end
    end
  end
end

local function UpdateTalentButtonOverlay(button)
  if not button or not button.GetSpellID then return end

  local showOverlay = false
  if LP_config and LP_config.spellIconOverlay_showInTalents then
    local spellID = button:GetSpellID()
    if spellID and IsSpellInRotation(spellID) then
      showOverlay = true
    end
  end

  -- Avoid creating a frame on every talent node; only the ones that actually get an overlay need one.
  if not showOverlay and not button.LudiusPlusOverlayFrame then
    return
  end

  -- The tree's edge arrows are drawn at "start button frame level - 1", and a parent node one row
  -- up sits FrameLevelPerRow (10) levels above this node, so an incoming arrow lands ~9 levels above
  -- our button. Node levels across the whole tree only span a few tens, so +100 clears every arrow.
  EnsureOverlayFrame(button, button:GetFrameLevel() + 100)

  -- The talent node border is busy, so talents get their own size and per-corner offset to keep the
  -- overlay readable. The icon fills the frame; the shadow keeps the icon's original proportions (25/16).
  local size = TALENT_OVERLAY_SIZE
  button.LudiusPlusOverlayFrame:SetSize(size, size)
  if button.LudiusPlusShadow then
    button.LudiusPlusShadow:SetSize(size * 25 / 16, size * 25 / 16)
  end

  -- Update position (always, to handle position changes). Each anchor corner has its own pixel
  -- offset in TALENT_OVERLAY_OFFSETS.
  local position = (LP_config and LP_config.spellIconOverlay_talentPosition) or "BOTTOMLEFT"
  local offset = TALENT_OVERLAY_OFFSETS[position]
  local offsetX = offset and offset.x or 0
  local offsetY = offset and offset.y or 0
  button.LudiusPlusOverlayFrame:ClearAllPoints()
  button.LudiusPlusOverlayFrame:SetPoint(position, button, position, offsetX, offsetY)

  button.LudiusPlusOverlayFrame:SetShown(showOverlay)

  -- When the icon shows in the bottom-right corner, lift the rank number on top of it.
  SetTalentSpendTextAboveOverlay(button, showOverlay and position == "BOTTOMRIGHT")
end

local function UpdateAllTalentOverlays()
  local talentsFrame = GetTalentsFrame()
  if not talentsFrame or not talentsFrame.EnumerateAllTalentButtons then return end
  for button in talentsFrame:EnumerateAllTalentButtons() do
    UpdateTalentButtonOverlay(button)
  end
end

local function HookTalentButton(button)
  if button.LudiusPlusTalentHooked then return end
  button.LudiusPlusTalentHooked = true
  -- FullUpdate runs whenever a talent button (re)renders its node, including when a pooled
  -- button is reused for a different node, so this keeps the overlay in sync with the button.
  hooksecurefunc(button, "FullUpdate", UpdateTalentButtonOverlay)
end

local function HookTalentsFrame()
  if isTalentFrameHooked then return end
  local talentsFrame = GetTalentsFrame()
  if not talentsFrame then return end
  isTalentFrameHooked = true

  -- Hook every button created from now on, then apply the overlay to it right away.
  talentsFrame:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, function(_, button)
    HookTalentButton(button)
    UpdateTalentButtonOverlay(button)
  end, eventFrame)

  -- Hook buttons that already exist (e.g. the module is enabled while the frame is open).
  for button in talentsFrame:EnumerateAllTalentButtons() do
    HookTalentButton(button)
    UpdateTalentButtonOverlay(button)
  end
end

local function EventFrameScript(self, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "LudiusPlus" then
      addon.SetupOrTeardownSpellIconOverlay()
    elseif addonName == "Blizzard_PlayerSpells" then
      HookSpellBookItemMixin()
      HookTalentsFrame()
    end

    if isHooked and C_AddOns.IsAddOnLoaded("LudiusPlus") then
      self:UnregisterEvent("ADDON_LOADED")
    end
  elseif event == "SPELLS_CHANGED" then
    UpdateRotationSpellsCache()
    UpdateAllActionBarOverlays()
    UpdateAllTalentOverlays()
  elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" or event == "PLAYER_ENTERING_WORLD" then
    UpdateAllActionBarOverlays()
  end
end

local function SetupSpellIconOverlay()
  -- Register event handlers.
  eventFrame:RegisterEvent("SPELLS_CHANGED")
  eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
  eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
  eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:SetScript("OnEvent", EventFrameScript)

  -- Hook into SpellBookItemMixin and the talents frame (each can only be done once)
  if C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
    HookSpellBookItemMixin()
    HookTalentsFrame()
  else
    -- If the module is activated via options when LudiusPlus has already loaded, the ADDON_LOADED event is no longer registered.
    -- So we need to listen for Blizzard_PlayerSpells loading.
    eventFrame:RegisterEvent("ADDON_LOADED")
  end

  -- Initial update
  UpdateAllActionBarOverlays()
  UpdateAllTalentOverlays()
end

local function TeardownSpellIconOverlay()
  -- Unregister events
  eventFrame:UnregisterEvent("SPELLS_CHANGED")
  eventFrame:UnregisterEvent("ACTIONBAR_SLOT_CHANGED")
  eventFrame:UnregisterEvent("ACTIONBAR_PAGE_CHANGED")
  eventFrame:UnregisterEvent("UPDATE_BONUS_ACTIONBAR")
  eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:UnregisterEvent("ADDON_LOADED")
  eventFrame:SetScript("OnEvent", nil)
  
  -- Hide overlays on action bars
  for _, entry in ipairs(actionButtonSets) do
    for i = 1, entry.count do
      local button = _G[entry.prefix .. i]
      if button and button.LudiusPlusOverlayFrame then
        button.LudiusPlusOverlayFrame:Hide()
      end
    end
  end

  -- Hide overlays on talent buttons
  local talentsFrame = GetTalentsFrame()
  if talentsFrame and talentsFrame.EnumerateAllTalentButtons then
    for button in talentsFrame:EnumerateAllTalentButtons() do
      if button.LudiusPlusOverlayFrame then
        -- Restore Blizzard's original number/shadows (blanked while our copies show) and hide our copies.
        SetTalentSpendTextAboveOverlay(button, false)
        button.LudiusPlusOverlayFrame:Hide()
      end
    end
  end
end

function addon.SetupOrTeardownSpellIconOverlay()
  if LP_config and (LP_config.spellIconOverlay_showInSpellbook or LP_config.spellIconOverlay_showOnActionBars or LP_config.spellIconOverlay_showInTalents) then
    SetupSpellIconOverlay()
  else
    TeardownSpellIconOverlay()
  end
end

function addon.RefreshSpellIconOverlayPositions()
  -- Refresh action bar overlays
  UpdateAllActionBarOverlays()

  -- Refresh talent overlays
  UpdateAllTalentOverlays()

  -- Refresh spellbook overlays by triggering SpellBookFrame update if it's open
  if SpellBookFrame and SpellBookFrame:IsShown() then
    -- Force spellbook buttons to update
    if SpellBookFrame.UpdateSpells then
      SpellBookFrame:UpdateSpells()
    end
  end
end

-- Initialize when addon loads
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", EventFrameScript)
