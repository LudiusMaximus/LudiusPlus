local folderName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("LudiusPlus")
local LibMountInfo = LibStub("LibMountInfo-1.0")

local ChangeActionBarPage = _G.ChangeActionBarPage
local IsMounted = _G.IsMounted
local UnitAffectingCombat = _G.UnitAffectingCombat
local InCombatLockdown = _G.InCombatLockdown

local realmName = GetRealmName()
local playerName = UnitName("player")

local macroName = "Dismount/Mount Toggle"
local travelFormSpellName = C_Spell.GetSpellInfo(783).name
local soarSpellName = C_Spell.GetSpellInfo(369536).name
local macroIcon = GetFileIDFromPath("Interface\\AddOns\\" .. folderName .. "\\DismountMacroIcon.blp")
local dismountToggleBindingName = "MACRO Dismount/Mount Toggle"

local dismountToggleButton = CreateFrame("button", "DismountToggleButton", nil, "SecureActionButtonTemplate")

-- Deferred operation flags for combat lockdown protection
local deferredSetupNeeded = false
local deferredTeardownNeeded = false



local eventFrame = CreateFrame("Frame")

-- Track if we've reached PLAYER_LOGIN yet (when macro API becomes available)
local playerLoginFired = false


local function UpdateMacro()
  -- print("UpdateMacro")

  -- Macro API is only effective from PLAYER_LOGIN onwards.
  if not playerLoginFired then
    return
  end

  -- Check combat lockdown - defer if in combat
  if InCombatLockdown() then
    deferredSetupNeeded = true
    return
  end



  local macroBody = ""

  -- Dismount when mounted.
  macroBody = macroBody .. "/dismount\n"

  -- If enabled cast travel form or soar. (As long as Dracthyr cannot be Druids, we are fine!)
  if LP_config.dismountToggle_travelFormEnabled then
    macroBody = macroBody .. "/cast [nomounted] " .. travelFormSpellName .. "\n"
  end
  if LP_config.dismountToggle_soarEnabled then
    macroBody = macroBody .. "/cast [nomounted] " .. soarSpellName .. "\n"
  end

  -- Summon mount (with logic to respect remount setting for ignored mounts).
  macroBody = macroBody .. "/run local lm=LPLMR[\"" .. playerName .. "\"] if lm then local m=LPGM(lm) if m"
  if LP_config.dismountToggle_travelFormEnabled then
    macroBody = macroBody .. " and not LPISK(783)"
  end
  if LP_config.dismountToggle_soarEnabled then
    macroBody = macroBody .. " and not LPISK(369536)"
  end
  -- If auto-mount is disabled, check if current mount was ignored before remounting
  if not LP_config.dismountToggle_ignoredMountAutoMount then
    macroBody = macroBody .. " and not LPCMI()"
  end
  macroBody = macroBody ..  " then LPMJS(m)end end"

  -- print(macroName, macroIcon, macroBody)

  if not GetMacroInfo(macroName) then
    CreateMacro(macroName, macroIcon, macroBody)
  else
    EditMacro(macroName, macroName, macroIcon, macroBody)
  end

  -- Module is enabled - set up the macro binding
  local hotkey = GetBindingKey(dismountToggleBindingName)
  if hotkey then
    ClearOverrideBindings(dismountToggleButton)
    dismountToggleButton:SetScript("OnClick", nil)
    SetOverrideBindingMacro(dismountToggleButton, true, hotkey, macroName)
  end
end


local function SetupDisabledNotification()
  local hotkey = GetBindingKey(dismountToggleBindingName)
  if hotkey then
    ClearOverrideBindings(dismountToggleButton)
    SetOverrideBinding(dismountToggleButton, true, hotkey, "CLICK DismountToggleButton:LeftButton")
    dismountToggleButton:SetScript("OnClick", function()
      print("|cffff0000Ludius Plus:|r " .. L["Dismount/Mount Toggle module is disabled. Enable it in the addon options."])
    end)
  end
end


local function EventFrameScript(self, event, ...)

  if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
    if not IsMounted() then return end

    -- LibMountInfo now handles storing to LP_lastMount automatically
    -- Just trigger a GetCurrentMount to ensure it's tracked
    LibMountInfo:GetCurrentMount()

    if not UnitAffectingCombat("player") and LP_config.dismountToggle_changeActionBarTo ~= "disabled" then
      ChangeActionBarPage(LP_config.dismountToggle_changeActionBarTo)
    end

  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local _, unit, _, spellId = ...
    if unit ~= "player" then return end

    -- Travel form or soar.
    if spellId == 783 or spellId == 369536 then
      if not UnitAffectingCombat("player") and LP_config.dismountToggle_changeActionBarTo ~= "disabled" then
        ChangeActionBarPage(LP_config.dismountToggle_changeActionBarTo)
      end
    end

  elseif event == "UPDATE_BINDINGS" then
    ClearOverrideBindings(dismountToggleButton)
    if LP_config and LP_config.dismountToggle_enabled then
      UpdateMacro()
    else
      SetupDisabledNotification()
    end

  elseif event == "PLAYER_LOGIN" then
    playerLoginFired = true
    if LP_config and LP_config.dismountToggle_enabled then
      UpdateMacro()
    else
      SetupDisabledNotification()
    end

  elseif event == "PLAYER_REGEN_ENABLED" then

    -- Execute deferred macro deletion after combat ends
    if deferredTeardownNeeded then
      deferredTeardownNeeded = false
      DeleteMacro(macroName)
      -- Now fully tear down since macro is deleted
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      self:SetScript("OnEvent", nil)
      return
    end

    if deferredSetupNeeded then
      deferredSetupNeeded = false
      UpdateMacro()
    end

  elseif event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == folderName then
      LP_lastMount = LP_lastMount or {}
      LP_lastMount[realmName] = LP_lastMount[realmName] or {}

      -- Integrate LibMountInfo with our persistent storage
      LibMountInfo:SetPersistentStorage(LP_lastMount)

      -- Set up ignored mounts list
      if LP_config.dismountToggle_ignoredMounts then
        LibMountInfo:SetIgnoredMounts(LP_config.dismountToggle_ignoredMounts)
      end

      -- Abbreviations to use in macro.
      _G.LPMJS = _G.C_MountJournal.SummonByID
      _G.LPISK = _G.C_SpellBook.IsSpellKnown
      _G.LPLMR = LP_lastMount[realmName]

      -- Helper to check if current mount is ignored
      _G.LPCMI = function()
        local mountID, _ = LibMountInfo:GetCurrentMount()
        return LibMountInfo.ignoredMounts[mountID] == true
      end

      -- Helper to get the right mount ID from the table
      -- Returns the most recently used mount (flying or non-flying)
      _G.LPGM = function(lm)
        if type(lm) == "number" then return lm end -- Old format support
        if type(lm) ~= "table" then return nil end
        -- Return most recently used mount
        return lm.last
      end

      self:UnregisterEvent("ADDON_LOADED")
      addon.SetupOrTeardownDismountToggle()
    end

  end
end


local function SetupDismountToggle()
  -- print("SetupDismountToggle")

  eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
  eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

  -- Only register UNIT_SPELLCAST_SUCCEEDED if changeActionBarTo is not disabled
  if LP_config.dismountToggle_changeActionBarTo ~= "disabled" then
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  end

  eventFrame:SetScript("OnEvent", EventFrameScript)

  -- Update macro immediately if not in combat and PLAYER_LOGIN has fired
  if playerLoginFired then
    UpdateMacro()
  end
end


local function TeardownDismountToggle()
  -- print("TeardownDismountToggle")

  eventFrame:UnregisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
  eventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")

  -- Delete the macro when module is disabled
  if not InCombatLockdown() then
    DeleteMacro(macroName)
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


function addon.SetupOrTeardownDismountToggle()
  if LP_config and LP_config.dismountToggle_enabled then
    SetupDismountToggle()
  else
    TeardownDismountToggle()
  end
end


-- Initialize when addon loads
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", EventFrameScript)