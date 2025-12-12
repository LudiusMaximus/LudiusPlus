local folderName, addon = ...

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

-- Deferred operation flag for combat lockdown protection
local deferredSetupNeeded = false



local MountingFunction = function()
  if not IsMounted() then return end

  -- LibMountInfo now handles storing to LP_lastMount automatically
  -- Just trigger a GetCurrentMount to ensure it's tracked
  LibMountInfo:GetCurrentMount()
  
  if not UnitAffectingCombat("player") and LP_config.dismountToggle_changeActionBarTo ~= "disabled" then
    ChangeActionBarPage(LP_config.dismountToggle_changeActionBarTo)
  end
end
local mountingFrame = CreateFrame("Frame")
mountingFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")


local SpellCastSucceededFunction = function(...)
  local _, _, unit, _, spellId = ...
  if unit ~= "player" then return end
  
  -- Travel form or soar.
  if spellId == 783 or spellId == 369536 then
    -- If changeActionBarTo is disabled, this script is not set.
    if not UnitAffectingCombat("player") then
      ChangeActionBarPage(LP_config.dismountToggle_changeActionBarTo)
    end
  end
end
local spellCastSucceededFrame = CreateFrame("Frame")
spellCastSucceededFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")



-- Function to be called from options.lua.
addon.SetupDismountToggleMacro = function()
  -- Check combat lockdown - defer if in combat
  if InCombatLockdown() then
    deferredSetupNeeded = true
    return
  end
  
  local hotkey = GetBindingKey(dismountToggleBindingName)
  
  if not LP_config.dismountToggle_enabled then
    mountingFrame:SetScript("OnEvent", nil)
    spellCastSucceededFrame:SetScript("OnEvent", nil)
    -- Delete the macro when module is disabled
    DeleteMacro(macroName)
    -- Set up the disabled notification if there's a keybinding
    if hotkey then
      SetOverrideBinding(dismountToggleButton, true, hotkey, "CLICK DismountToggleButton:LeftButton")
      dismountToggleButton:SetScript("OnClick", function()
        print("|cffff0000Ludius Plus - Dismount/Mount Toggle:|r Module is currently disabled. Enable it in the addon options.")
      end)
    end
    return
  end
  
  
  mountingFrame:SetScript("OnEvent", MountingFunction)
  
  if LP_config.dismountToggle_changeActionBarTo ~= "disabled" then
    spellCastSucceededFrame:SetScript("OnEvent", SpellCastSucceededFunction)
  else
    spellCastSucceededFrame:SetScript("OnEvent", nil)
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
  
  
  if not GetMacroInfo(macroName) then
    CreateMacro(macroName, macroIcon, macroBody)
  else
    EditMacro(macroName, macroName, macroIcon, macroBody)
  end
  
  -- Module is enabled - set up the macro binding
  if hotkey then
    dismountToggleButton:SetScript("OnClick", nil)
    SetOverrideBindingMacro(dismountToggleButton, true, hotkey, macroName)
  end

end



local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UPDATE_BINDINGS")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)

  if event == "PLAYER_LOGIN" then
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
    _G.LPISK = _G.IsSpellKnown
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
    
    addon.SetupDismountToggleMacro()
  end
  
  if event == "UPDATE_BINDINGS" then
    if not LP_config then return end
    addon.SetupDismountToggleMacro()
  end
  
  if event == "PLAYER_REGEN_ENABLED" then
    if deferredSetupNeeded then
      deferredSetupNeeded = false
      addon.SetupDismountToggleMacro()
    end
  end

end)