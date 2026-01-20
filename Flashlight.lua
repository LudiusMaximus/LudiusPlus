local folderName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("LudiusPlus")

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
local deferredSetupNeeded = false    -- Deferred operation flag for combat lockdown protection
local deferredTeardownNeeded = false -- Deferred macro deletion when disabled during combat


local eventFrame = CreateFrame("Frame")

-- Track if we've reached PLAYER_LOGIN yet (when macro API becomes effective)
local playerLoginFired = false

local function RegisterMainEvents()
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
  eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  eventFrame:RegisterEvent("UNIT_AURA")
end


local function UpdateMacros()
  -- Macro API is only effective from PLAYER_LOGIN onwards
  if not playerLoginFired then
    return
  end

  -- Check combat lockdown - defer if in combat
  if InCombatLockdown() then
    deferredSetupNeeded = true
    return
  end

  -- Check if player has the toy
  if not addon.HasFlashlightToy() then
    if LP_config and LP_config.flashlight_enabled then
      LP_config.flashlight_enabled = false
      print("|cffff0000Ludius Plus:|r " .. L["Flashlight module disabled because you don't own the toy."])

      -- Refresh the options panel to update the warning message and enable button
      if LibStub then
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
        if AceConfigRegistry then
          AceConfigRegistry:NotifyChange("Ludius Plus")
        end
      end
    end
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
      ClearOverrideBindings(torchToggleButton)
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


local function SetupDisabledNotification()
  local hotkey = GetBindingKey(flashlightBindingName)
  if hotkey then
    ClearOverrideBindings(torchToggleButton)
    SetOverrideBinding(torchToggleButton, true, hotkey, "CLICK TorchToggleButton:LeftButton")
    torchToggleButton:SetScript("OnClick", function()
      print("|cffff0000Ludius Plus:|r " .. L["Flashlight module is disabled. Enable it in the addon options."])
    end)
  end
end


local function EventFrameScript(self, event, ...)

  -- Handle toy acquisition events
  if event == "NEW_TOY_ADDED" or event == "TOYS_UPDATED" then
    local eventItemID = ...
    if eventItemID == itemID and addon.HasFlashlightToy() then
      -- Toy was just obtained! Transition to operational mode
      if LP_config and LP_config.flashlight_enabled then
        -- Unregister toy tracking events first
        self:UnregisterEvent("NEW_TOY_ADDED")
        self:UnregisterEvent("TOYS_UPDATED")

        -- Now register main operational events
        RegisterMainEvents()
        UpdateMacros()
      end

      -- Refresh the options panel to update the warning message and enable button
      if LibStub then
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
        if AceConfigRegistry then
          AceConfigRegistry:NotifyChange("Ludius Plus")
        end
      end
    end
    return
  end

  if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_DISABLED" then
    if LP_config and LP_config.flashlight_enabled then
      UpdateMacros()
    end

  elseif event == "UPDATE_BINDINGS" then
    ClearOverrideBindings(torchToggleButton)
    if LP_config and LP_config.flashlight_enabled then
      UpdateMacros()
    else
      SetupDisabledNotification()
    end

  elseif event == "UNIT_AURA" then
    local unitTarget, updateInfo = ...
    if unitTarget ~= "player" then return end

    -- Note: In WoW Midnight, addons will no longer be able to access aura information
    -- during combat. Checking combat lockdown early and deferring anticipates this change.
    if InCombatLockdown() then
      deferredSetupNeeded = true
      return
    end

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
        UpdateMacros()
      end
    end

  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Execute deferred macro deletion after combat ends
    if deferredTeardownNeeded then
      deferredTeardownNeeded = false
      if GetMacroInfo(macroTorchOnName) then
        DeleteMacro(macroTorchOnName)
      end
      if GetMacroInfo(macroTorchOffName) then
        DeleteMacro(macroTorchOffName)
      end
      -- Now fully tear down since macros are deleted
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      self:SetScript("OnEvent", nil)
      return
    end

    -- Execute deferred setup after combat ends
    if deferredSetupNeeded then
      deferredSetupNeeded = false
      UpdateMacros()
    end

  elseif event == "PLAYER_LOGIN" then
    playerLoginFired = true
    if LP_config and LP_config.flashlight_enabled then
      UpdateMacros()
    else
      SetupDisabledNotification()
    end

  elseif event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == folderName then
      self:UnregisterEvent("ADDON_LOADED")
      
      -- Check if module requires dangerous scripts on startup
      addon.CheckDangerousScriptsOnStartup()
      
      addon.SetupOrTeardownFlashlight()
    end

  end
end


local function SetupFlashlight()
  -- print("SetupFlashlight")

  eventFrame:SetScript("OnEvent", EventFrameScript)

  -- Only register main events if player has the toy
  if addon.HasFlashlightToy() then
    RegisterMainEvents()
    -- Only update macros if PLAYER_LOGIN has fired
    if playerLoginFired then
      UpdateMacros()
    end
  else
    -- Register toy tracking events if player doesn't have the toy yet
    eventFrame:RegisterEvent("NEW_TOY_ADDED")
    eventFrame:RegisterEvent("TOYS_UPDATED")
  end
end


local function TeardownFlashlight()
  -- print("TeardownFlashlight")

  eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
  eventFrame:UnregisterEvent("UNIT_AURA")
  eventFrame:UnregisterEvent("NEW_TOY_ADDED")
  eventFrame:UnregisterEvent("TOYS_UPDATED")

  -- Delete macros when module is disabled
  if not InCombatLockdown() then
    if GetMacroInfo(macroTorchOnName) then
      DeleteMacro(macroTorchOnName)
    end
    if GetMacroInfo(macroTorchOffName) then
      DeleteMacro(macroTorchOffName)
    end
    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    -- Don't remove OnEvent handler - we need it for UPDATE_BINDINGS and PLAYER_LOGIN
  else
    -- Defer macro deletion until combat ends
    deferredTeardownNeeded = true
    -- Keep PLAYER_REGEN_ENABLED registered to handle deferred deletion
  end

  -- Disabled notification is set up via UPDATE_BINDINGS/PLAYER_LOGIN handlers
  SetupDisabledNotification()
end


function addon.SetupOrTeardownFlashlight()
  if LP_config and LP_config.flashlight_enabled then
    SetupFlashlight()
  else
    TeardownFlashlight()
  end
end


-- Initialize when addon loads
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", EventFrameScript)