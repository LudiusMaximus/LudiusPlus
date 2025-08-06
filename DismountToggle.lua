local folderName, addon = ...

local C_MountJournal_GetMountIDs = _G.C_MountJournal.GetMountIDs
local C_MountJournal_GetMountInfoByID = _G.C_MountJournal.GetMountInfoByID
local ChangeActionBarPage = _G.ChangeActionBarPage
local IsMounted = _G.IsMounted
local UnitAffectingCombat = _G.UnitAffectingCombat

local realmName = GetRealmName()
local playerName = UnitName("player")

local macroName = "Dismount/Mount Toggle"
local travelFormSpellName = C_Spell.GetSpellInfo(783).name
local soarSpellName = C_Spell.GetSpellInfo(369536).name
local macroIcon = GetFileIDFromPath("Interface\\AddOns\\" .. folderName .. "\\DismountMacroIcon.blp")



-- To track the last used mount.
local function GetCurrentMount()
  if not IsMounted() then return nil end

  local lastMount = LP_lastMount[realmName][playerName]

  -- Check last active mount first to save time.
  if lastMount then
    local _, _, _, active = C_MountJournal_GetMountInfoByID(lastMount)
    if active then
      return lastMount
    end
  end

  -- Must be a new new mount, so go through all to find active one.
  for _, v in pairs(C_MountJournal_GetMountIDs()) do
    local _, _, _, active = C_MountJournal_GetMountInfoByID(v)
    if active then
      lastMount = v
      return v
    end
  end

  -- Should never happen, as we have checked IsMounted() above.
  return nil
end


local MountingFunction = function()
  if not IsMounted() then return end

  local currentMount = GetCurrentMount()
  if currentMount then
    LP_lastMount[realmName][playerName] = currentMount
  end
  
  if LP_config.dismountToggle_changeActionBarTo ~= "disabled" then
    ChangeActionBarPage(LP_config.dismountToggle_changeActionBarTo)
  end
end
local mountingFrame = CreateFrame("Frame")
mountingFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")


local SpellCastSucceededFunction = function(...)
  local _, _, unit, _, spellId = ...
  if unit ~= "player" then return end
  
  -- Cannot change action bar during combat.
  if UnitAffectingCombat("player") then return end

  if spellId == 783 or spellId == 369536 then
    -- If changeActionBarTo is disabled, this script is not set.
    ChangeActionBarPage(LP_config.dismountToggle_changeActionBarTo)
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
  macroBody = macroBody .. "/run local lm = LPLMR[\"" .. playerName .. "\"] if lm "
  if LP_config.dismountToggle_travelFormEnabled then
    macroBody = macroBody .. "and not LPISK(783) "
  end
  if LP_config.dismountToggle_soarEnabled then
    macroBody = macroBody .. "and not LPISK(369536) "
  end
  macroBody = macroBody ..  "then LPMJS(lm) end"
  
  
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
  
  -- Abbreviations to use in macro.
  _G.LPMJS = _G.C_MountJournal.SummonByID
  _G.LPISK = _G.IsSpellKnown
  _G.LPLMR = LP_lastMount[realmName]
  
  addon.SetupDismountToggleMacro()

end)