local folderName = ...

local math_floor                          = _G.math.floor
local C_PetJournal_GetSummonedPetGUID     = _G.C_PetJournal.GetSummonedPetGUID
local C_PetJournal_SummonPetByGUID        = _G.C_PetJournal.SummonPetByGUID
local C_Timer_After                       = _G.C_Timer.After
local C_UnitAuras_GetPlayerAuraBySpellID  = _G.C_UnitAuras.GetPlayerAuraBySpellID
local GetActionInfo                       = _G.GetActionInfo
local UnitAffectingCombat                 = _G.UnitAffectingCombat
local UnitIsDeadOrGhost                   = _G.UnitIsDeadOrGhost
local UnitInVehicle                       = _G.UnitInVehicle
local UnitOnTaxi                          = _G.UnitOnTaxi


local realmName = GetRealmName()
local playerName = UnitName("player")


-- To be mapped to saved variable. Must be a table to work!!
local desiredCompanion = nil


local noResummon = false
local function ResummonPet()
  if noResummon then return end
  if not UnitAffectingCombat("player")
    and desiredCompanion[playerName]
    and desiredCompanion[playerName] ~= C_PetJournal_GetSummonedPetGUID()
    and not UnitOnTaxi("player")
    and not UnitInVehicle("player")
    and not UnitIsDeadOrGhost("player")
    and not IsFalling("player")                              -- Not while "Parasol Fall" is happening.
    and C_UnitAuras_GetPlayerAuraBySpellID(211898) == nil    -- Not while "Eye of Kilrogg" replaces the current pet.
    then
    -- print("Resummoning", desiredCompanion[playerName])
    C_PetJournal_SummonPetByGUID(desiredCompanion[playerName], folderName)
  end
end

local function CheckPet()
  -- Value is only reliable after some time.
  -- While checking we want no restoring.
  noResummon = true
  C_Timer_After(0.6, function()
    desiredCompanion[playerName] = C_PetJournal_GetSummonedPetGUID()
    -- print("Current pet:", C_PetJournal_GetSummonedPetGUID())
    noResummon = false
  end)
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

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BATTLE_PET_CURSOR_CLEAR")
eventFrame:SetScript("OnEvent", function(_, event, ...)
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

  if event == "PLAYER_LOGIN" then

    LP_desiredCompanion = LP_desiredCompanion or {}
    LP_desiredCompanion[realmName] = LP_desiredCompanion[realmName] or {}
    desiredCompanion = LP_desiredCompanion[realmName]

    C_Timer.NewTicker(1, ResummonPet)

  end
end)



-- If anybody else (e.g. the Pet Journal "Summon/Dismiss" button) calls SummonPetByGUID(), we check the result.
hooksecurefunc(C_PetJournal, "SummonPetByGUID", function(_, caller)
  if caller ~= folderName then
    CheckPet()
  end
end)
