local folderName = ...

local math_floor = _G.math.floor
local C_PetJournal_GetSummonedPetGUID = C_PetJournal.GetSummonedPetGUID
local C_PetJournal_SummonPetByGUID = C_PetJournal.SummonPetByGUID
local C_Timer_After = C_Timer.After
local GetActionInfo = GetActionInfo

local GetRealmName = GetRealmName
local UnitName = UnitName

-- To be mapped to saved variable.
local desired = nil

local function CheckPet()
  C_Timer_After(0.3, function()
    desired.pet = C_PetJournal_GetSummonedPetGUID()
  end)
end


local function ResummonPet()
  local currentPet = C_PetJournal_GetSummonedPetGUID()
  if desired.pet and desired.pet ~= currentPet then
    
    if not UnitAffectingCombat("player") then
      C_PetJournal_SummonPetByGUID(desired.pet, folderName)
    end
    
  end
  C_Timer_After(1, ResummonPet)
end


-- slot / 12 is the button prefix.
-- https://warcraft.wiki.gg/wiki/Action_slot
local buttonPrefix = {
   [0] = "ActionButton",               -- Action Bar 1 (page 1)
  [10] = "ActionButton",               -- Action Bar 1 (page 1, skyriding)
   [1] = "ActionButton",               -- Action Bar 1 (page 2)
   [5] = "MultiBarBottomLeftButton",   -- Action Bar 2
   [4] = "MultiBarBottomRightButton",  -- Action Bar 3
   [2] = "MultiBarRightButton",        -- Action Bar 4
   [3] = "MultiBarLeftButton",         -- Action Bar 5
  [12] = "MultiBar5Button",            -- Action Bar 6
  [13] = "MultiBar6Button",            -- Action Bar 7
  [13] = "MultiBar6Button",            -- Action Bar 7
  [14] = "MultiBar7Button",            -- Action Bar 8
}

local function SlotToActionButton(actionSlot)
  local buttonPrefixIndex = math_floor(actionSlot/12)
  local buttonIndex = actionSlot % 12
  if buttonIndex == 0 then
    buttonPrefixIndex = buttonPrefixIndex - 1
    buttonIndex = 12
  end
  if not buttonPrefix[buttonPrefixIndex] then return nil end
  return buttonPrefix[buttonPrefixIndex] .. buttonIndex
end


local hookedButton = {}
local activeButton = {}
local function TrackPetActionButton(actionSlot)
  
  local actionButtonName = SlotToActionButton(actionSlot)
  local actionButton = _G[actionButtonName]
  if not actionButton then
    print(folderName, "error:", actionSlot, "has no action button. Should never happen!")
    return
  end
  
  local actionType, id  = GetActionInfo(actionSlot)
  if actionType and actionType == "summonpet" then
    -- print(actionSlot, id, C_PetJournal.GetPetInfoByPetID(id))
    
    if not hookedButton[actionButton] then
      actionButton:HookScript("OnClick", function(self, _, down)
        if down then return end
        if not activeButton[self] then return end       
        CheckPet()
      end)
      hookedButton[actionButton] = true
    end
    activeButton[actionButton] = true
    
  elseif activeButton[actionButton] then
    activeButton[actionButton] = nil
  end
end

local actionBarTrackingFrame = CreateFrame("Frame")
actionBarTrackingFrame:SetScript("OnEvent", function(_, event)
  -- New slot is not ready after BATTLE_PET_CURSOR_CLEAR.
  C_Timer_After(0.1, function()
    for actionSlot = 1, 72 do
      TrackPetActionButton(actionSlot)
    end
    -- 73 to 120 are class specific.
    for actionSlot = 121, 132 do
      TrackPetActionButton(actionSlot)
    end
    -- 133 to 144 are unknown.
    for actionSlot = 145, 180 do
      TrackPetActionButton(actionSlot)
    end
  end)
  
  if event == "PLAYER_ENTERING_WORLD" then
    
    local realmName = GetRealmName()
    local playerName = UnitName("player")
    
    PC_desiredPet = PC_desiredPet or {}
    PC_desiredPet[realmName] = PC_desiredPet[realmName] or {}
    PC_desiredPet[realmName][playerName] = PC_desiredPet[realmName][playerName] or {}
    desired = PC_desiredPet[realmName][playerName]
    
    ResummonPet()
  end
end)
actionBarTrackingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
actionBarTrackingFrame:RegisterEvent("BATTLE_PET_CURSOR_CLEAR")


-- If anybody else (e.g. the Pet Journal "Summon/Dismiss" button) calls SummonPetByGUID(), we check the result.
hooksecurefunc(C_PetJournal, "SummonPetByGUID", function(_, caller)
  if caller ~= folderName then
    CheckPet()
  end  
end)
