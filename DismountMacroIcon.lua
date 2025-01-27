local folderName = ...

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, isLogin, isReload)
  EditMacro("Dismount", "Dismount", GetFileIDFromPath("Interface\\AddOns\\" .. folderName .. "\\DismountMacroIcon.blp"))
end)
f:RegisterEvent("PLAYER_ENTERING_WORLD")

