local folderName = ...

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
  local currentTime = GetTime()
  local lastPosition = currentPosition
  currentPosition = UnitPosition("player")

  if noRestoreBefore > currentTime then return end
  -- print("RestoreUnsheath", (GetSheathState() ~= 1), "should be", desiredUnsheath[playerName])

  if (
      desiredUnsheath[playerName]
      and GetSheathState() == 1
      and not UnitAffectingCombat("player")
      and not IsMounted()
      and not UnitOnTaxi("player")
      and not UnitInVehicle("player")
      and not UnitCastingInfo("player")
      and not (IsSwimming("player") and (currentPosition ~= lastPosition))                         -- Not while swimming and moving.
      and not (MapUtil_GetDisplayableMapForPlayer() == 2301 and (currentPosition ~= lastPosition)) -- Not while underwater running in "The Sinkhole".
      and not (MapUtil_GetDisplayableMapForPlayer() == 2259 and (currentPosition ~= lastPosition)) -- Not while underwater running in "Tak-Rethan Abyss".
      and not C_UnitAuras_GetPlayerAuraBySpellID(221883)                                           -- Not while on Divine Steed.
    ) or (
      not desiredUnsheath[playerName]
      and GetSheathState() ~= 1
    )
    then
    -- print("Got to auto-toggle!")

    -- Sound for automatic unsheathing gets annoying.
    if unmuteTimer and not unmuteTimer:IsCancelled() then
      -- print("Canceling unmute")
      unmuteTimer:Cancel()
    end

    MuteUnsheathSounds(true)

    ToggleSheath(folderName)

    -- Give this toggle some time to come into effect, before checking again.
    noRestoreBefore = currentTime + 1.5

    -- Re-enable sound after the toggle is complete.
    unmuteTimer = C_Timer_NewTimer(1, function()
      MuteUnsheathSounds(false)
    end)

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