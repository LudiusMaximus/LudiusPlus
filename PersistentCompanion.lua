local folderName, addon = ...

local C_PetJournal_DismissSummonedPet     = _G.C_PetJournal.DismissSummonedPet
local C_PetJournal_GetSummonedPetGUID     = _G.C_PetJournal.GetSummonedPetGUID
local C_PetJournal_SummonPetByGUID        = _G.C_PetJournal.SummonPetByGUID
local C_Timer_After                       = _G.C_Timer.After
local C_UnitAuras_GetPlayerAuraBySpellID  = _G.C_UnitAuras.GetPlayerAuraBySpellID
local GetActionInfo                       = _G.GetActionInfo
local IsStealthed                         = _G.IsStealthed
local MuteSoundFile                       = _G.MuteSoundFile
local UnitAffectingCombat                 = _G.UnitAffectingCombat
local UnitInVehicle                       = _G.UnitInVehicle
local UnitIsDeadOrGhost                   = _G.UnitIsDeadOrGhost
local UnitOnTaxi                          = _G.UnitOnTaxi
local UnmuteSoundFile                     = _G.UnmuteSoundFile


local stealthSpells = {
  [1784] = true,    -- Rogue: Stealth
  [1856] = true,    -- Rogue: Vanish
  [114018] = true,  -- Rogue: Shroud of Concealment
  [5215] = true,    -- Druid: Prowl
  [199483] = true,  -- Hunter: Camouflage
  [66] = true,      -- Mage: Invisibility
  [110959] = true,  -- Mage: Greater Invisibility
  [198158] = true,  -- Mage: Mass Invisibility
  [58984] = true,   -- Night Elf: Shadowmeld
}


local realmName = GetRealmName()
local playerName = UnitName("player")


-- To be mapped to saved variable. Must be a table to work!!
local desiredCompanion = nil
local tickerHandle = nil


local noResummon = false
local isHooked = false

local function ResummonPet()
  if not LP_config or not LP_config.persistentCompanion_enabled then return end
  if noResummon then return end
  if not UnitAffectingCombat("player")
    and desiredCompanion[playerName]
    and desiredCompanion[playerName] ~= C_PetJournal_GetSummonedPetGUID()
    and not UnitOnTaxi("player")
    and not UnitInVehicle("player")
    and not UnitIsDeadOrGhost("player")
    and not IsFalling("player")                              -- Not while "Parasol Fall" is happening.
    and C_UnitAuras_GetPlayerAuraBySpellID(211898) == nil    -- Not while "Eye of Kilrogg" replaces the current pet.
    and not (LP_config.persistentCompanion_dismissWhileStealthed and IsStealthed())  -- Not while stealthed (if option enabled).
    and not (HouseEditorFrame and HouseEditorFrame.LayoutModeFrame and HouseEditorFrame.LayoutModeFrame:IsShown()) -- While the house layout is shown, the pet gets dismissed and the character is "stunned".
    then
    -- print("Resummoning", desiredCompanion[playerName])

    -- Mute the pet summon sound if option is enabled
    if LP_config.persistentCompanion_muteSummonSound then
      MuteSoundFile(565429)
    end

    C_PetJournal_SummonPetByGUID(desiredCompanion[playerName], folderName)

    -- Unmute after a short delay if option is enabled
    if LP_config.persistentCompanion_muteSummonSound then
      C_Timer_After(0.5, function()
        UnmuteSoundFile(565429)
      end)
    end
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


-- Actual action buttons, per bar addon. Each button object exposes the
-- action slot it currently displays via a live ".action" field (Blizzard's
-- own bars update it as pages/stances/vehicle bars change), so buttons are
-- tracked directly by that field instead of by a slot-to-button formula.
-- A formula can't work reliably here: a single physical button (e.g.
-- ActionButton1) represents a different slot on each bar page, so the same
-- button would need to be resolved from several different slot numbers.
local actionButtonSets = {
  { prefix = "ActionButton", count = 12 },              -- Action Bar 1
  { prefix = "MultiBarBottomLeftButton", count = 12 },  -- Action Bar 2
  { prefix = "MultiBarBottomRightButton", count = 12 }, -- Action Bar 3
  { prefix = "MultiBarRightButton", count = 12 },       -- Action Bar 4
  { prefix = "MultiBarLeftButton", count = 12 },        -- Action Bar 5
  { prefix = "MultiBar5Button", count = 12 },           -- Action Bar 6
  { prefix = "MultiBar6Button", count = 12 },           -- Action Bar 7
  { prefix = "MultiBar7Button", count = 12 },           -- Action Bar 8
  { prefix = "BT4Button", count = 180, requiresAddOn = "Bartender4" }, -- Bartender4 (15 bars x 12 buttons)
}


local hookedButton = {}
local hookedButtonScript = {}  -- Store the hooked script reference for verification
local activeButton = {}

local function TrackPetActionButtonState(actionButton, actionSlot)
  local actionType, id  = GetActionInfo(actionSlot)
  if actionType and actionType == "summonpet" then
    -- print(actionSlot, id, C_PetJournal.GetPetInfoByPetID(id))

    -- Check if hook was lost (button was recreated with same name but different frame)
    local currentScript = actionButton:GetScript("OnClick")
    if hookedButton[actionButton] and hookedButtonScript[actionButton] ~= currentScript then
      hookedButton[actionButton] = nil
    end

    if not hookedButton[actionButton] then
      actionButton:HookScript("OnClick", function(self, _, down)
        if down then return end
        if not activeButton[self] then return end
        CheckPet()
      end)
      hookedButton[actionButton] = true
      hookedButtonScript[actionButton] = actionButton:GetScript("OnClick")
    end
    activeButton[actionButton] = true

  elseif activeButton[actionButton] then
    activeButton[actionButton] = nil
  end
end


local eventFrame = CreateFrame("Frame")


local function TrackAllPetActionButtons()
  for _, entry in ipairs(actionButtonSets) do
    if not entry.requiresAddOn or C_AddOns.IsAddOnLoaded(entry.requiresAddOn) then
      for i = 1, entry.count do
        local actionButton = _G[entry.prefix .. i]
        if actionButton and actionButton.action then
          TrackPetActionButtonState(actionButton, actionButton.action)
        end
      end
    end
  end
end


-- Some spells summon a pet, after which the addon should not resummon the previous pet.
local dismissCompanionSpells = {
    [23012] = true, -- Orc Orphan Grunth (BC, Orgrimmar)
    [23013] = true, -- Human Orphan Randis (BC, Stormwind)
    [39478] = true, -- Blood Elf Orphan Salandria (BC, Shattrath)
    [39479] = true, -- Draenei Orphan Dornaa (BC, Shattrath)
    [65352] = true, -- Oracle Orphan Roo (Wrath, Dalaran)
    [65353] = true, -- Wolvar Orphan Kekek (Wrath, Dalaran)
   [282839] = true, -- Kul Tiran Orphan Liam (BfA, Boralus)
   [283612] = true, -- Zandalari Orphan Azala (BfA, Dazar'alor)
  [1228496] = true, -- Kobold Orphan Skibbles (TWW, Dornogal)
  [1230149] = true, -- Arathi Orphan Destien (TWW, quest line)
  [1230182] = true, -- Nerubian Orphan Theadis (TWW, quest line)
  [1230184] = true, -- Goblin Orphan Kitzy (TWW, quest line)
}


local function EventFrameScript(self, event, ...)

  if event == "BATTLE_PET_CURSOR_CLEAR"
      or event == "PLAYER_ENTERING_WORLD"
      or event == "EDIT_MODE_LAYOUTS_UPDATED"
      or event == "ACTIONBAR_SLOT_CHANGED"
      or event == "UPDATE_BONUS_ACTIONBAR" then
    -- New slot is not ready immediately after the event.
    C_Timer_After(0.1, TrackAllPetActionButtons)

  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellId = ...
    if unit == "player" then

      if dismissCompanionSpells[spellId] then
        if desiredCompanion then
          desiredCompanion[playerName] = nil
        end
        return
      end

      if LP_config and LP_config.persistentCompanion_dismissWhileStealthed then
        if stealthSpells[spellId] then
          local petGUID = C_PetJournal_GetSummonedPetGUID()
          if petGUID then
            -- print("Entering stealth, dismissing pet:", petGUID)
            C_PetJournal_DismissSummonedPet(petGUID, folderName)
          end
        end
      end

    end

  elseif event == "PLAYER_REGEN_DISABLED" then
    if LP_config and LP_config.persistentCompanion_dismissInCombat then
      local petGUID = C_PetJournal_GetSummonedPetGUID()
      -- print("Entering combat, dismissing pet.", petGUID)
      if petGUID then
        C_PetJournal_DismissSummonedPet(petGUID, folderName)
      end
    end

  elseif event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "LudiusPlus" then
      LP_desiredCompanion = LP_desiredCompanion or {}
      LP_desiredCompanion[realmName] = LP_desiredCompanion[realmName] or {}
      desiredCompanion = LP_desiredCompanion[realmName]

      self:UnregisterEvent("ADDON_LOADED")
      addon.SetupOrTeardownPersistentCompanion()
    end

  end
end


local function SetupPersistentCompanion()
  -- print("SetupPersistentCompanion")

  eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
  eventFrame:RegisterEvent("BATTLE_PET_CURSOR_CLEAR")
  eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  if LP_config and LP_config.persistentCompanion_dismissInCombat then eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") end
  if LP_config and LP_config.persistentCompanion_dismissWhileStealthed then eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") end
  eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")

  eventFrame:SetScript("OnEvent", EventFrameScript)

  -- Track all pet action buttons
  TrackAllPetActionButtons()

  -- Start ticker
  if tickerHandle then
    tickerHandle:Cancel()
  end
  tickerHandle = C_Timer.NewTicker(1, ResummonPet)

  -- Hook only once.
  if not isHooked then
    hooksecurefunc(C_PetJournal, "SummonPetByGUID", function(_, caller)
      if caller ~= folderName then
        CheckPet()
      end
    end)
    hooksecurefunc(C_PetJournal, "DismissSummonedPet", function(_, caller)
      if caller ~= folderName then
        CheckPet()
      end
    end)
    isHooked = true
  end
end


local function TeardownPersistentCompanion()
  -- print("TeardownPersistentCompanion")

  eventFrame:UnregisterEvent("ACTIONBAR_SLOT_CHANGED")
  eventFrame:UnregisterEvent("BATTLE_PET_CURSOR_CLEAR")
  eventFrame:UnregisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
  eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
  eventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  eventFrame:UnregisterEvent("UPDATE_BONUS_ACTIONBAR")
  eventFrame:SetScript("OnEvent", nil)

  -- Stop ticker
  if tickerHandle then
    tickerHandle:Cancel()
    tickerHandle = nil
  end
end


function addon.SetupOrTeardownPersistentCompanion()
  if LP_config and LP_config.persistentCompanion_enabled then
    SetupPersistentCompanion()
  else
    TeardownPersistentCompanion()
  end
end


-- Initialize when addon loads
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", EventFrameScript)
