local folderName = ...

local realmName = GetRealmName()
local playerName = UnitName("player")

local function GetCurrentMount()
  if not IsMounted() then return nil end

  local lastMount = LP_lastMount[realmName][playerName]

  -- Check last active mount first to save time.
  if lastMount then
    local _, _, _, active = C_MountJournal.GetMountInfoByID(lastMount)
    if active then
      return lastMount
    end
  end

  -- Must be a new new mount, so go through all to find active one.
  for _, v in pairs(C_MountJournal.GetMountIDs()) do
    local _, _, _, active = C_MountJournal.GetMountInfoByID(v)
    if active then
      lastMount = v
      return v
    end
  end

  -- Should never happen, as we have checked IsMounted() above.
  return nil
end


local mountingFrame = CreateFrame("Frame")
mountingFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mountingFrame:SetScript("OnEvent", function(_, event, ...)
  local currentMount = GetCurrentMount()
  if currentMount then
    LP_lastMount[realmName][playerName] = currentMount
  end
end)








local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()

  LP_lastMount = LP_lastMount or {}
  LP_lastMount[realmName] = LP_lastMount[realmName] or {}
  
  local macroName = "Mount Toggle"
  local spellName = C_Spell.GetSpellInfo(783).name
  
  local macroIcon = GetFileIDFromPath("Interface\\AddOns\\" .. folderName .. "\\DismountMacroIcon.blp")
  local macroBody = "#showtooltip\n/dismount [mounted]\n/cast [nomounted] " .. spellName .. "\n/run local lastMount = LP_lastMount[\"" .. realmName .. "\"][\"" .. playerName .. "\"] if not IsSpellKnown(783) and lastMount then C_MountJournal.SummonByID(lastMount) end"

  if not GetMacroInfo(macroName) then
    CreateMacro(macroName, macroIcon, macroBody)
  else
    EditMacro(macroName, macroName, macroIcon, macroBody)
  end
  
  
end)

