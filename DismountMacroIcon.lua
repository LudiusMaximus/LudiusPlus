local folderName = ...

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, _, isLogin, isReload)
  if not isLogin and not isReload then return end

  local macroName = "Dismount"
  local macroIcon = GetFileIDFromPath("Interface\\AddOns\\" .. folderName .. "\\DismountMacroIcon.blp")
  local macroBody = "/dismount"

  if not GetMacroInfo(macroName) then
    CreateMacro(macroName, macroIcon, macroBody)
  else
    EditMacro(macroName, macroName, macroIcon, macroBody)
  end
end)
f:RegisterEvent("PLAYER_ENTERING_WORLD")

