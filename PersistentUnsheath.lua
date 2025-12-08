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
local noRestoreBefore = GetTime()
local currentPosition = UnitPosition("player")
local function RestoreUnsheath()
  -- Return early if module is disabled
  if not LP_config or (not LP_config.persistentUnsheath_autoSheath and not LP_config.persistentUnsheath_autoUnsheath) then return end
  
  local currentTime = GetTime()
  local lastPosition = currentPosition
  currentPosition = UnitPosition("player")

  if noRestoreBefore > currentTime then return end
  
  
  local currentlySheated = GetSheathState() == 1
  
  -- If only one of the two options is enabled, we might have to change desiredUnsheath.
  if (LP_config.persistentUnsheath_autoSheath ~= LP_config.persistentUnsheath_autoUnsheath) then
    -- If auto-sheath is disabled, and the game has unsheathed, the new desired state should become unsheathed.
    if not LP_config.persistentUnsheath_autoSheath and not currentlySheated then
      desiredUnsheath[playerName] = true
    -- If auto-unsheath is disabled, and the game has sheathed, the new desired state should become sheathed.
    elseif not LP_config.persistentUnsheath_autoUnsheath and currentlySheated then
      desiredUnsheath[playerName] = false
    end
  end

  local shouldUnsheath = desiredUnsheath[playerName]

  -- print("RestoreUnsheath", currentlySheated, "should be", shouldUnsheath)
  
  -- Check if we should auto-unsheath
  if shouldUnsheath and currentlySheated and LP_config.persistentUnsheath_autoUnsheath then
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
  elseif not shouldUnsheath and not currentlySheated and LP_config.persistentUnsheath_autoSheath then
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


local function CheckUnsheath()
  -- Value is only reliable after some time.
  -- While checking we want no restoring.
  noRestoreBefore = GetTime() + 0.5
  C_Timer_After(0.5, function()
    local newDesiredUnsheath = (GetSheathState() ~= 1)
    if desiredUnsheath[playerName] ~= newDesiredUnsheath then
      -- print("-----------> NOW CHANGING TO", newDesiredUnsheath)
      desiredUnsheath[playerName] = newDesiredUnsheath
    end
  end)
end


local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()

  LP_desiredUnsheath = LP_desiredUnsheath or {}
  LP_desiredUnsheath[realmName] = LP_desiredUnsheath[realmName] or {}
  desiredUnsheath = LP_desiredUnsheath[realmName]

  C_Timer.NewTicker(0.25, RestoreUnsheath)

end)



-- If player manually calls ToggleSheath(), we check the result.
hooksecurefunc("ToggleSheath", function(caller)
  if caller ~= folderName then
    CheckUnsheath()
  end
end)



-- No restoring while an emote is in action! (roughly 3 seconds)
hooksecurefunc("DoEmote", function(...)
  -- print("DoEmote", ...)
  noRestoreBefore = GetTime() + 3
end)
