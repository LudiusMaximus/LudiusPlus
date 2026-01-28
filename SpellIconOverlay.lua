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
local actionBarButtonPrefixes = {
  "ActionButton",
  "MultiBarBottomLeftButton",
  "MultiBarBottomRightButton",
  "MultiBarRightButton",
  "MultiBarLeftButton",
  "MultiBar5Button",
  "MultiBar6Button",
  "MultiBar7Button",
}

local isActionSpellOnActionBar = false

local function UpdateActionBarButtonOverlay(button)
  if not button then return end

  -- No need to check for enabled state here, as the teardown unregisters all events leading to this function.

  if not button.LudiusPlusOverlayFrame then
    -- Create a frame to hold the overlay so we can control strata/level
    -- Set to MEDIUM strata, level 100 to appear above AssistedCombatHighlightFrame (MEDIUM, level 99)
    button.LudiusPlusOverlayFrame = CreateFrame("Frame", nil, button)
    button.LudiusPlusOverlayFrame:SetFrameStrata("MEDIUM")
    button.LudiusPlusOverlayFrame:SetFrameLevel(100)
    button.LudiusPlusOverlayFrame:SetSize(16, 16)
    
    -- Create the icon texture on the frame
    button.LudiusPlusOverlay = button.LudiusPlusOverlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    button.LudiusPlusOverlay:SetAtlas("UI-RefreshButton")
    
    -- Rotate 90 degrees counter-clockwise
    button.LudiusPlusOverlay:SetRotation(math.rad(90))
    
    button.LudiusPlusOverlay:SetAllPoints(button.LudiusPlusOverlayFrame)

    -- Shadow
    button.LudiusPlusShadow = button.LudiusPlusOverlayFrame:CreateTexture(nil, "OVERLAY", nil, 6)
    button.LudiusPlusShadow:SetAtlas("Garr_BuildingShadowOverlay")
    button.LudiusPlusShadow:SetAlpha(0.7)
    button.LudiusPlusShadow:SetSize(25, 25)
    button.LudiusPlusShadow:SetPoint("CENTER", button.LudiusPlusOverlay, "CENTER", 0, 0)
  end

  -- Update position (always, to handle position changes)
  local position = (LP_config and LP_config.spellIconOverlay_actionBarPosition) or "BOTTOMLEFT"
  button.LudiusPlusOverlayFrame:ClearAllPoints()
  button.LudiusPlusOverlayFrame:SetPoint(position, button, position, 0, 0)

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

    for _, prefix in ipairs(actionBarButtonPrefixes) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then
                if button.AssistedCombatRotationFrame and button.AssistedCombatRotationFrame:IsShown() then
                    isActionSpellOnActionBar = true
                    return
                end
            end
        end
    end
end

local function UpdateAllActionBarOverlays()
  CheckIfActionSpellIsOnActionBar()
  for _, prefix in ipairs(actionBarButtonPrefixes) do
    for i = 1, 12 do
      local button = _G[prefix .. i]
      if button then
        UpdateActionBarButtonOverlay(button)
      end
    end
  end
end

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
    
    button.Button.LudiusPlusOverlay:SetSize(16, 16)

    -- Shadow
    button.Button.LudiusPlusShadow = button.Button:CreateTexture(nil, "OVERLAY", nil, 6)
    button.Button.LudiusPlusShadow:SetAtlas("Garr_BuildingShadowOverlay")
    button.Button.LudiusPlusShadow:SetAlpha(0.7)
    button.Button.LudiusPlusShadow:SetSize(25, 25)
    button.Button.LudiusPlusShadow:SetPoint("CENTER", button.Button.LudiusPlusOverlay, "CENTER", 0, 0)
  end

  -- Update position (always, to handle position changes)
  local position = (LP_config and LP_config.spellIconOverlay_spellbookPosition) or "BOTTOMLEFT"
  button.Button.LudiusPlusOverlay:ClearAllPoints()
  button.Button.LudiusPlusOverlay:SetPoint(position, button.Button, position, 0, 0)
  
  local showOverlay = false
  
  if button.spellBookItemInfo then
      local spellID = button.spellBookItemInfo.spellID
      if spellID then
        -- Try API first
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

local function EventFrameScript(self, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "LudiusPlus" then
       addon.SetupOrTeardownSpellIconOverlay()
    elseif addonName == "Blizzard_PlayerSpells" then
       if SpellBookItemMixin and not isHooked then
          hooksecurefunc(SpellBookItemMixin, "UpdateSpellData", function(self)
            UpdateSpellbookOverlay(self)
          end)
          isHooked = true
       end
    end
    
    if isHooked and C_AddOns.IsAddOnLoaded("LudiusPlus") then
        self:UnregisterEvent("ADDON_LOADED")
    end
  elseif event == "SPELLS_CHANGED" then
    UpdateRotationSpellsCache()
    UpdateAllActionBarOverlays()
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

  -- Hook into SpellBookItemMixin (can only be done once)
  if not isHooked then
    if C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
       if SpellBookItemMixin then
          hooksecurefunc(SpellBookItemMixin, "UpdateSpellData", function(self)
            UpdateSpellbookOverlay(self)
          end)
          isHooked = true
       end
    else
      -- If the module is activated via options when LudiusPlus hasis already loaded, the ADDON_LOADED event is no longer registered.
      -- So we need to listen for Blizzard_PlayerSpells loading.
      eventFrame:RegisterEvent("ADDON_LOADED")
    end
  end
  
  -- Initial update
  UpdateAllActionBarOverlays()
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
  for _, prefix in ipairs(actionBarButtonPrefixes) do
    for i = 1, 12 do
      local button = _G[prefix .. i]
      if button and button.LudiusPlusOverlayFrame then
        button.LudiusPlusOverlayFrame:Hide()
      end
    end
  end
end

function addon.SetupOrTeardownSpellIconOverlay()
  if LP_config and (LP_config.spellIconOverlay_showInSpellbook or LP_config.spellIconOverlay_showOnActionBars) then
    SetupSpellIconOverlay()
  else
    TeardownSpellIconOverlay()
  end
end

function addon.RefreshSpellIconOverlayPositions()
  -- Refresh action bar overlays
  UpdateAllActionBarOverlays()
  
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
