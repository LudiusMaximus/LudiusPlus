local folderName, addon = ...

local LibMountInfo = LibStub("LibMountInfo-1.0")

local ChangeActionBarPage = _G.ChangeActionBarPage
local IsMounted = _G.IsMounted
local UnitAffectingCombat = _G.UnitAffectingCombat

local realmName = GetRealmName()
local playerName = UnitName("player")

local macroName = "Dismount/Mount Toggle"
local travelFormSpellName = C_Spell.GetSpellInfo(783).name
local soarSpellName = C_Spell.GetSpellInfo(369536).name
local macroIcon = GetFileIDFromPath("Interface\\AddOns\\" .. folderName .. "\\DismountMacroIcon.blp")



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
  
  if not LP_config.dismountToggle_enabled then
    mountingFrame:SetScript("OnEvent", nil)
    spellCastSucceededFrame:SetScript("OnEvent", nil)
    DeleteMacro(macroName)
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
  
  -- Summon mount.
  macroBody = macroBody .. "/run local lm=LPLMR[\"" .. playerName .. "\"] if lm then local m=LPGM(lm) if m"
  if LP_config.dismountToggle_travelFormEnabled then
    macroBody = macroBody .. " and not LPISK(783)"
  end
  if LP_config.dismountToggle_soarEnabled then
    macroBody = macroBody .. " and not LPISK(369536)"
  end
  macroBody = macroBody ..  " then LPMJS(m)end end"
  
  
  if not GetMacroInfo(macroName) then
    CreateMacro(macroName, macroIcon, macroBody)
  else
    EditMacro(macroName, macroName, macroIcon, macroBody)
  end

end




local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()

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
  
  -- Helper to get the right mount ID from the table
  -- Returns the most recently used mount (flying or non-flying)
  _G.LPGM = function(lm)
    if type(lm) == "number" then return lm end -- Old format support
    if type(lm) ~= "table" then return nil end
    -- Return most recently used mount
    return lm.last
  end
  
  addon.SetupDismountToggleMacro()

end)