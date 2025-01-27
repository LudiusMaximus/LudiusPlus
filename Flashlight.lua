



-- Cave Spelunker's Torch
-- https://www.wowhead.com/spell=453163/cave-spelunkers-torch
-- https://www.wowhead.com/item=224552/cave-spelunkers-torch
-- https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetPlayerAuraBySpellID
-- https://warcraft.wiki.gg/wiki/FileDataID
-- https://github.com/wowdev/wow-listfile
local itemID = 224552
local spellID = 453163
local macroTorchOnName = "Torch On"
local macroTorchOnIcon = 135433
local macroTorchOffName = "Torch Off"
local macroTorchOffIcon = 136122

local torchToggleButton = CreateFrame("button", "TorchToggleButton", nil, "SecureActionButtonTemplate")
local torchBuffInstanceId = nil

local torchTrackingFrame = CreateFrame("Frame")
torchTrackingFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_DISABLED" then
  
  
    if UnitAffectingCombat("player") then return end
    
    -- Make sure Macro is set up.
    -- Got to wait for item name to be cached.
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
      
      local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
      if aura then
        -- print("Torch already on", aura.auraInstanceID)
        SetOverrideBindingMacro(torchToggleButton, true, "F", macroTorchOffName)
        torchBuffInstanceId = aura.auraInstanceID
      else
        -- print("Torch already off")
        SetOverrideBindingMacro(torchToggleButton, true, "F", macroTorchOnName)
      end
    end)
    

  elseif event == "UNIT_AURA" then
    
    local unitTarget, updateInfo = ...
    if unitTarget ~= "player" then return end
    if UnitAffectingCombat("player") then return end
        
    if updateInfo.addedAuras or updateInfo.removedAuraInstanceIDs then
      if updateInfo.addedAuras then
        for _, k in pairs(updateInfo.addedAuras) do
          -- print(event, "added", k.name, k.spellId, k.auraInstanceID)
          if k.spellId == spellID then
            SetOverrideBindingMacro(torchToggleButton, true, "F", macroTorchOffName)
            torchBuffInstanceId = k.auraInstanceID
          end
        end
      end
      if updateInfo.removedAuraInstanceIDs then
        for _, k in pairs(updateInfo.removedAuraInstanceIDs) do
          -- print(event, "removed", k)
          if k == torchBuffInstanceId then
            SetOverrideBindingMacro(torchToggleButton, true, "F", macroTorchOnName)
          end
        end
      end
    end

  end
end)
torchTrackingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
torchTrackingFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
torchTrackingFrame:RegisterEvent("UNIT_AURA")

