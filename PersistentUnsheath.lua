local folderName, addon = ...

-- Make functions local for performance!
local C_Timer_After = _G.C_Timer.After
local C_Timer_NewTimer = _G.C_Timer.NewTimer
local C_UnitAuras_GetPlayerAuraBySpellID = _G.C_UnitAuras.GetPlayerAuraBySpellID
local GetSheathState = _G.GetSheathState
local GetTime = _G.GetTime
local IsMounted = _G.IsMounted
local IsSwimming = _G.IsSwimming
local MapUtil_GetDisplayableMapForPlayer = _G.MapUtil.GetDisplayableMapForPlayer
local MuteSoundFile = _G.MuteSoundFile
local ToggleSheath = _G.ToggleSheath
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitCastingInfo = _G.UnitCastingInfo
local UnitInVehicle = _G.UnitInVehicle
local UnitOnTaxi = _G.UnitOnTaxi
local UnitPosition = _G.UnitPosition
local UnmuteSoundFile = _G.UnmuteSoundFile


local realmName = GetRealmName()
local playerName = UnitName("player")


-- To be mapped to saved variable. Must be a table to work!!
local desiredUnsheath = nil


local function MuteUnsheathSounds(mute)
  -- https://wago.tools/files?search=sheath
  -- https://wago.tools/files?search=unsheath
  -- Muting sheath sounds as well. Because sometimes after closing the world map, ToggleSheath() leads to an unsheath.
  local unsheathSounds = {567430, 567473, 567506, 567395, 567456, 567498}
  if mute then
    -- print("Muting")
    for _, k in pairs(unsheathSounds) do
      MuteSoundFile(k)
    end
  else
    -- print("Unmuting")
    for _, k in pairs(unsheathSounds) do
      UnmuteSoundFile(k)
    end
  end
end


local unmuteTimer = nil
local restoreUnsheathTicker = nil
local noRestoreBefore = GetTime()
local currentPosition = UnitPosition("player")
local function RestoreUnsheath()
  -- Return early if module is disabled
  if not LP_config or (not LP_config.persistentUnsheath_autoSheath and not LP_config.persistentUnsheath_autoUnsheath) then return end

  local currentTime = GetTime()
  local lastPosition = currentPosition
  currentPosition = UnitPosition("player")

  if noRestoreBefore > currentTime then return end

  -- print("RestoreUnsheath", GetSheathState(), "should be", desiredUnsheath[playerName])


  local currentlyUnsheated = GetSheathState() ~= 1

  -- If only one of the two options is enabled, we might have to change desiredUnsheath.
  if (LP_config.persistentUnsheath_autoSheath ~= LP_config.persistentUnsheath_autoUnsheath) then
    -- If auto-sheath is disabled, and the game has unsheathed, the new desired state should become unsheathed.
    if not LP_config.persistentUnsheath_autoSheath and currentlyUnsheated then
      desiredUnsheath[playerName] = true
    -- If auto-unsheath is disabled, and the game has sheathed, the new desired state should become sheathed.
    elseif not LP_config.persistentUnsheath_autoUnsheath and not currentlyUnsheated then
      desiredUnsheath[playerName] = false
    end
  end

  local shouldUnsheath = desiredUnsheath[playerName]

  -- print("RestoreUnsheath", currentlyUnsheated, "should be", shouldUnsheath)

  -- Check if we should auto-unsheath
  if shouldUnsheath and not currentlyUnsheated and LP_config.persistentUnsheath_autoUnsheath then
    if not UnitAffectingCombat("player")
      and not IsMounted()
      and not UnitOnTaxi("player")
      and not UnitInVehicle("player")
      and not UnitCastingInfo("player")
      and not (IsSwimming("player") and (currentPosition ~= lastPosition))                         -- Not while swimming and moving.
      and not (MapUtil_GetDisplayableMapForPlayer() == 2301 and (currentPosition ~= lastPosition)) -- Not while underwater running in "The Sinkhole".
      and not (MapUtil_GetDisplayableMapForPlayer() == 2259 and (currentPosition ~= lastPosition)) -- Not while underwater running in "Tak-Rethan Abyss".
      and not C_UnitAuras_GetPlayerAuraBySpellID(221883)                                           -- Not while on Divine Steed.
    then
      -- print("Got to auto-toggle unsheath!")
      if unmuteTimer and not unmuteTimer:IsCancelled() then
        unmuteTimer:Cancel()
      end
      if LP_config.persistentUnsheath_muteToggleSounds then
        MuteUnsheathSounds(true)
      end
      ToggleSheath(folderName)
      noRestoreBefore = currentTime + 1.5
      if LP_config.persistentUnsheath_muteToggleSounds then
        unmuteTimer = C_Timer_NewTimer(1, function()
          MuteUnsheathSounds(false)
        end)
      end
    end

  -- Check if we should auto-sheath
  elseif not shouldUnsheath and currentlyUnsheated and LP_config.persistentUnsheath_autoSheath then
    if not C_UnitAuras_GetPlayerAuraBySpellID(453163) then -- Not while Cave Spelunker's Torch is out
      -- print("Got to auto-toggle sheath!")
      if unmuteTimer and not unmuteTimer:IsCancelled() then
        unmuteTimer:Cancel()
      end
      if LP_config.persistentUnsheath_muteToggleSounds then
        MuteUnsheathSounds(true)
      end
      ToggleSheath(folderName)
      noRestoreBefore = currentTime + 1.5
      if LP_config.persistentUnsheath_muteToggleSounds then
        unmuteTimer = C_Timer_NewTimer(1, function()
          MuteUnsheathSounds(false)
        end)
      end
    end
  end
end



local eventFrame = CreateFrame("Frame")
local hooksSetup = false


local function StartTicker()

  -- Stop existing ticker if running
  if restoreUnsheathTicker and not restoreUnsheathTicker:IsCancelled() then
    -- print("Stopping ticker", GetTime())
    restoreUnsheathTicker:Cancel()
  end

  -- Start ticker after delay to ensure GetSheathState() returns reliable values
  C_Timer_After(1.5, function()
    if not restoreUnsheathTicker or restoreUnsheathTicker:IsCancelled() then
      -- print("Starting ticker", GetTime())
      restoreUnsheathTicker = C_Timer.NewTicker(0.25, RestoreUnsheath)
    end
  end)
end


local function SetupPersistentUnsheath()
  -- print("SetupPersistentUnsheath")
  
  -- Register event handler for zone changes and reloads
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:SetScript("OnEvent", function()
    -- print("PLAYER_ENTERING_WORLD")
    StartTicker()
  end)

  -- Start immediately if we're already in the world
  StartTicker()

  -- Only setup hooks once
  if not hooksSetup then
    -- If player manually calls ToggleSheath(), we check the result.
    hooksecurefunc("ToggleSheath", function(caller)
      -- print("ToggleSheath", caller)
      if caller ~= folderName then
        -- Value is only reliable after some time.
        -- While checking we want no restoring.
        noRestoreBefore = GetTime() + 0.75
        C_Timer_After(0.5, function()
          local newDesiredUnsheath = (GetSheathState() ~= 1)
          if desiredUnsheath and desiredUnsheath[playerName] ~= newDesiredUnsheath then
            -- print("-----------> NOW CHANGING TO", newDesiredUnsheath)
            desiredUnsheath[playerName] = newDesiredUnsheath
          end
        end)
      end
    end)

    -- No restoring while an emote is in action! (roughly 3 seconds)
    hooksecurefunc("DoEmote", function(...)
      -- print("DoEmote", ...)
      noRestoreBefore = GetTime() + 3
    end)

    hooksSetup = true
  end
end


local function TeardownPersistentUnsheath()
  -- print("TeardownPersistentUnsheath")

  eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:SetScript("OnEvent", nil)
  
  if restoreUnsheathTicker and not restoreUnsheathTicker:IsCancelled() then
    restoreUnsheathTicker:Cancel()
  end
  if unmuteTimer and not unmuteTimer:IsCancelled() then
    unmuteTimer:Cancel()
  end
end


function addon.SetupOrTeardownPersistentUnsheath()
  -- print("SetupOrTeardownPersistentUnsheath", LP_config.persistentUnsheath_autoSheath, LP_config.persistentUnsheath_autoUnsheath)
  if LP_config and (LP_config.persistentUnsheath_autoSheath or LP_config.persistentUnsheath_autoUnsheath) then
    SetupPersistentUnsheath()
  else
    TeardownPersistentUnsheath()
  end
end


-- Initialize when addon loads
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
  if addonName == "LudiusPlus" then
  
    -- Initialize variables if needed.
    LP_desiredUnsheath = LP_desiredUnsheath or {}
    LP_desiredUnsheath[realmName] = LP_desiredUnsheath[realmName] or {}
    desiredUnsheath = desiredUnsheath or LP_desiredUnsheath[realmName]
  
    -- print("ADDON_LOADED LudiusPlus", LP_config.persistentUnsheath_autoSheath, LP_config.persistentUnsheath_autoUnsheath)
    self:UnregisterEvent("ADDON_LOADED")
    addon.SetupOrTeardownPersistentUnsheath()
  end
end)
