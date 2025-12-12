local folderName, addon = ...

local C_UnitAuras_GetPlayerAuraBySpellID = _G.C_UnitAuras.GetPlayerAuraBySpellID
local SetOverrideBindingMacro = _G.SetOverrideBindingMacro
local UnitAffectingCombat = _G.UnitAffectingCombat
local InCombatLockdown = _G.InCombatLockdown

-- Cave Spelunker's Torch
-- https://www.wowhead.com/spell=453163/cave-spelunkers-torch
-- https://www.wowhead.com/item=224552/cave-spelunkers-torch
-- https://www.wowhead.com/object=437211/illuminated-footlocker
-- https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetPlayerAuraBySpellID
-- https://warcraft.wiki.gg/wiki/FileDataID
-- https://github.com/wowdev/wow-listfile

local itemID = 224552
local spellID = 453163

-- Check if player owns the Cave Spelunker's Torch toy
addon.HasFlashlightToy = function()
  return PlayerHasToy(itemID)
end
local macroTorchOnName = "Torch On"
local macroTorchOnIcon = 135433
local macroTorchOffName = "Torch Off"
local macroTorchOffIcon = 136122
local flashlightBindingName = "MACRO Torch Toggle"

local torchToggleButton = CreateFrame("button", "TorchToggleButton", nil, "SecureActionButtonTemplate")
local torchBuffInstanceId = nil
local deferredSetupNeeded = false  -- Deferred operation flag for combat lockdown protection

-- Setup function to be called from options.lua
addon.SetupFlashlightMacros = function()
  -- Check combat lockdown - defer if in combat
  if InCombatLockdown() then
    deferredSetupNeeded = true
    return
  end
  
  if not LP_config.flashlight_enabled then
    -- Delete macros when module is disabled
    if GetMacroInfo(macroTorchOnName) then
      DeleteMacro(macroTorchOnName)
    end
    if GetMacroInfo(macroTorchOffName) then
      DeleteMacro(macroTorchOffName)
    end
    return
  end

  -- Check if player has the toy
  if not addon.HasFlashlightToy() then
    return
  end
  -- Ensure macros are created
  local item = Item:CreateFromItemID(itemID)
  item:ContinueOnItemLoad(function()
    local itemName = C_Item.GetItemInfo(itemID)
    local spellName = C_Spell.GetSpellInfo(spellID).name

    local macroTorchOnBody = "/usetoy " .. itemName
    local macroTorchOffBody = "/cancelaura " .. spellName

    if not GetMacroInfo(macroTorchOnName) then
      CreateMacro(macroTorchOnName, macroTorchOnIcon, macroTorchOnBody)
    else
      EditMacro(macroTorchOnName, macroTorchOnName, macroTorchOnIcon, macroTorchOnBody)
    end

    if not GetMacroInfo(macroTorchOffName) then
      CreateMacro(macroTorchOffName, macroTorchOffIcon, macroTorchOffBody)
    else
      EditMacro(macroTorchOffName, macroTorchOffName, macroTorchOffIcon, macroTorchOffBody)
    end
    
    -- After macros are created, set up bindings
    local hotkey = GetBindingKey(flashlightBindingName)
    if hotkey then
      local aura = C_UnitAuras_GetPlayerAuraBySpellID(spellID)
      if UnitAffectingCombat("player") or not aura then
        SetOverrideBindingMacro(torchToggleButton, true, hotkey, macroTorchOnName)
      else
        SetOverrideBindingMacro(torchToggleButton, true, hotkey, macroTorchOffName)
        torchBuffInstanceId = aura.auraInstanceID
      end
    end
  end)
end

local torchTrackingFrame = CreateFrame("Frame")
torchTrackingFrame:RegisterEvent("PLAYER_LOGIN")
torchTrackingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
torchTrackingFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
torchTrackingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
torchTrackingFrame:RegisterEvent("UNIT_AURA")
torchTrackingFrame:RegisterEvent("UPDATE_BINDINGS")

-- Only register toy tracking events if player doesn't already have the toy
if not PlayerHasToy(itemID) then
  torchTrackingFrame:RegisterEvent("NEW_TOY_ADDED")
  torchTrackingFrame:RegisterEvent("TOYS_UPDATED")
end

torchTrackingFrame:SetScript("OnEvent", function(_, event, ...)

  -- Handle toy acquisition events
  if event == "NEW_TOY_ADDED" or event == "TOYS_UPDATED" then
    local eventItemID = ...
    if eventItemID == itemID and addon.HasFlashlightToy() then
      -- Toy was just obtained! Set up macros and refresh options UI
      if LP_config and LP_config.flashlight_enabled then
        addon.SetupFlashlightMacros()
      end
      -- Refresh the options panel to update the warning message and enable button
      if LibStub then
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
        if AceConfigRegistry then
          AceConfigRegistry:NotifyChange("Ludius Plus")
        end
      end
      -- Unregister these events now that we have the toy
      torchTrackingFrame:UnregisterEvent("NEW_TOY_ADDED")
      torchTrackingFrame:UnregisterEvent("TOYS_UPDATED")
    end
    return
  end
  
  if not LP_config then return end
  
  if event == "PLAYER_LOGIN" then
    addon.SetupFlashlightMacros()
    return
  end

  if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_DISABLED" then
    -- print(event, "Checking torch, combat:", UnitAffectingCombat("player"))
    addon.SetupFlashlightMacros()

  elseif event == "UNIT_AURA" then
    local unitTarget, updateInfo = ...
    if unitTarget ~= "player" then return end
    -- Cannot override bindings during combat.
    if InCombatLockdown() then return end

    if updateInfo.addedAuras or updateInfo.removedAuraInstanceIDs then
      -- Check if torch aura was added or removed
      local torchChanged = false
      if updateInfo.addedAuras then
        for _, k in pairs(updateInfo.addedAuras) do
          if k.spellId == spellID then
            torchChanged = true
            break
          end
        end
      end
      if not torchChanged and updateInfo.removedAuraInstanceIDs then
        for _, k in pairs(updateInfo.removedAuraInstanceIDs) do
          if k == torchBuffInstanceId then
            torchChanged = true
            break
          end
        end
      end
      
      if torchChanged then
        addon.SetupFlashlightMacros()
      end
    end

  elseif event == "UPDATE_BINDINGS" then
    addon.SetupFlashlightMacros()

  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Execute deferred setup after combat ends
    if deferredSetupNeeded then
      deferredSetupNeeded = false
      addon.SetupFlashlightMacros()
    end

  end
end)

