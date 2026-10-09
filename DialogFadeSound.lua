local folderName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("LudiusPlus")

-- Dialog Fade Sound: lowers the Music, Effects and/or Ambience volume while a
-- sound on the Dialog channel is playing, and fades it back afterwards.
--
-- DETECTION
-- There is no event for "dialog started/stopped", and VO the engine plays by
-- itself (NPC greetings, quest VO, monster says/yells) never passes through
-- Lua's PlaySound, so there is nothing to hook. Instead we rely on sound handles
-- being handed out from one increasing counter (the same fact the StopLastSound()
-- trick in other Ludius addons relies on):
--   * Every PROBE_INTERVAL we play a near-silent probe sound and stop it at once,
--     only to read the current counter.
--   * Every handle between the previous probe and this one is a sound somebody
--     else started in the meantime. C_Sound.IsPlaying() tells whether it runs.
--   * No API tells which channel a handle plays on. So for each new sound we read
--     C_Sound.GetSoundScaledVolume(), nudge Sound_DialogVolume, read again and put
--     the CVar back, all within the same frame. If the scaled volume followed the
--     nudge, it is a Dialog sound.
--   * A Dialog handle that is no longer IsPlaying() has ended.
--
-- FADING
-- While at least one Dialog sound plays, each enabled channel is faded out to its
-- "faded volume" (a fraction of the volume the user has set) over its fade-out
-- time, and faded back in over its fade-in time once the last Dialog sound has
-- ended. Fades run in decibels, see Interpolate().
--
-- Nothing is faded while the Dialog channel is muted, nor (optionally, "Don't fade
-- in delves") in delves, see ShouldFade().
--
-- We remember the user's value ("base") when we start touching a channel and
-- write it back verbatim at the end. If the CVar no longer holds what we wrote
-- last, somebody else (the user, another addon) has changed it meanwhile. We then
-- leave the channel alone and keep their value.
--
-- Verified in-game: the volume CVars can be set by addons during combat, and
-- writing the user's values back on PLAYER_LOGOUT does make it into Config.wtf
-- (a /reload while faded comes back with the original volumes).
--
-- QUEST TURN-IN FANFARE
-- Some sound kits make the engine itself lower ("duck") other channels while they
-- play, configured per sound kit in the SoundKitAdvanced DB2. Addons cannot see
-- this: no CVar changes, no events. The quest turn-in fanfare ducks the music to
-- 50% and brings it back within 100 ms when it ends, an audible jump. The fanfare
-- also often plays over the NPC's closing line. Muting its file (optional, "Mute
-- quest turn-in fanfare") silences both the fanfare and its duck (verified
-- in-game). Smoothing the duck from Lua instead is hopeless: its timing cannot be
-- observed, and Lua runs per graphics frame while the sound mixer does not.
--
-- TEST BUTTON
-- Plays a voice line from TEST_SOUNDKITS on the Dialog channel. It goes through
-- the regular detection like any other Dialog sound, with two special cases: it
-- is faded for in delves even with "Don't fade in delves", and if a Dialog sound
-- is already playing without fades, it starts them itself.
--
-- FOOTPRINT
-- Disabled at load: one frame with no events and no scripts, nothing else - no
-- ticker, no hooks, no muted files. Disabling in-session puts every channel back
-- to the user's volume right away, unmutes the fanfare, cancels the ticker,
-- unregisters all events and clears all scripts, which returns to that same state.


local C_CVar_GetCVar               = _G.C_CVar.GetCVar
local C_CVar_GetCVarBool           = _G.C_CVar.GetCVarBool
local C_CVar_SetCVar               = _G.C_CVar.SetCVar
local C_Sound_GetSoundScaledVolume = _G.C_Sound.GetSoundScaledVolume
local C_Sound_IsPlaying            = _G.C_Sound.IsPlaying
local C_Timer_NewTicker            = _G.C_Timer.NewTicker
local GetTime                      = _G.GetTime
local IsInInstance                 = _G.IsInInstance
local PlaySound                    = _G.PlaySound
local StopSound                    = _G.StopSound
local math_abs                     = _G.math.abs
local math_cos                     = _G.math.cos
local math_max                     = _G.math.max
local math_pi                      = _G.math.pi
local ipairs                       = _G.ipairs
local next                         = _G.next
local pairs                        = _G.pairs
local tonumber                     = _G.tonumber
local wipe                         = _G.wipe


local PROBE_SOUNDKIT = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
-- volumeOverride of the probe, on top of stopping it right away.
local PROBE_VOLUME   = 0.01
local PROBE_INTERVAL = 0.1
-- A handle that is not playing yet may still be loading its file, so it gets this long before we give up on it.
local PENDING_TIMEOUT = 1
-- After a loading screen the counter may have jumped a lot. Only look at this many of the newest handles.
local MAX_SCAN = 2000

-- sound/interface/iquestcomplete.ogg, the only file of sound kit 878 (SOUNDKIT.IG_QUEST_LIST_COMPLETE).
local QUEST_FANFARE_FILE = 567439

-- Prints Dialog sounds starting/stopping and every fade to the chat frame.
local DEBUG = false

-- Voice lines for the Test button, played one after the other, one per click. Sound kit IDs, not file IDs, so
-- that each plays in the client's language. Find more at https://www.wowhead.com/sounds (the number in "sound=12345").
-- Check a new one in-game with /script PlaySound(12345) first: Wowhead also lists sound kits the client cannot play.
local TEST_SOUNDKITS = {
  21401,   -- VO_QE_DT_Thrall_Maelstrom05
  34185,   -- VO_5.1_PROG_ANDUIN_REUNION_03
  139246,  -- VO_825_LADY_SYLVANAS_WINDRUNNER_16_F
  241335,  -- VO_1027_LADY_JAINA_PROUDMOORE_05_F
  274651,  -- VO_1115_SORIDORMI_01_F
}


local CHANNELS = {}
for _, v in ipairs({
  { cvar = "Sound_MusicVolume",    key = "music" },
  { cvar = "Sound_SFXVolume",      key = "sfx" },
  { cvar = "Sound_AmbienceVolume", key = "ambience" },
}) do
  CHANNELS[#CHANNELS + 1] = {
    name       = v.key,
    cvar       = v.cvar,
    enabledKey = "dialogFadeSound_" .. v.key .. "_enabled",
    volumeKey  = "dialogFadeSound_" .. v.key .. "_volume",
    fadeInKey  = "dialogFadeSound_" .. v.key .. "_fadeIn",
    fadeOutKey = "dialogFadeSound_" .. v.key .. "_fadeOut",

    -- Runtime state, all nil while we are not touching the channel.
    base       = nil,  -- the user's CVar value (string) from before we touched it
    baseNumber = nil,
    lastSet    = nil,  -- the CVar value (as read back) we wrote last
    factor     = nil,  -- current volume as a fraction of base
    -- Running fade, duration is nil while none runs.
    from       = nil,
    to         = nil,
    startTime  = nil,
    duration   = nil,
  }
end


local frame = CreateFrame("Frame")

local probeTicker = nil
local lastProbe   = nil
local pending     = {}  -- handle -> time first seen, not playing (yet)
local active      = {}  -- handle -> start time, for Dialog sounds currently playing
local started     = {}  -- reused buffer of handles that started playing in this tick
local before      = {}  -- reused buffer of their scaled volumes before the nudge
local testHandle  = nil -- handle of the Test button's voice line while it plays
local testIndex   = 0   -- position in TEST_SOUNDKITS of the voice line played last
local fanfareMuted = false


local function DebugPrint(msg)
  if DEBUG then
    print("|cff66ccff[DialogFadeSound]|r " .. msg)
  end
end


-- Easing curves, mapping fade progress t (0 to 1) to how far the fade has got (0 to 1) - in decibels,
-- see Interpolate().

-- Fade-in (back up after the dialog): starts and ends slowly, so it creeps in unnoticed.
local function EaseInOutSine(t)
  return 0.5 - 0.5 * math_cos(math_pi * t)
end

-- Fade-out (lowering the volume when a dialog starts): starts fast and ends slowly, to get out of the
-- dialog's way quickly. After a quarter of the time, 44% of the change is done. (Chosen to sound like
-- the fade-out tuned by ear before fading moved to decibels: 1 - (1 - t)^3 on the plain volume value.)
local function EaseOutQuad(t)
  return 1 - (1 - t) * (1 - t)
end

local FADE_IN_EASING  = EaseInOutSine
local FADE_OUT_EASING = EaseOutQuad

-- Fading cannot start from or go down to silence in decibels (log of 0), so 0% is treated as this (-60 dB).
local MIN_DECIBEL_FACTOR = 0.001

-- The volume factor at eased progress p (0 to 1) of a fade from "from" to "to".
-- We fade in decibels rather than in the plain volume value, because we hear loudness logarithmically:
-- 25% -> 50% sounds as big a step as 50% -> 100%. Sweeping the plain value evenly would put most of the
-- audible change at the start, which makes a slow fade-in sound like a noticeable swell.
local function Interpolate(from, to, p)
  from = math_max(from, MIN_DECIBEL_FACTOR)
  to   = math_max(to, MIN_DECIBEL_FACTOR)
  return from * (to / from) ^ p
end


-- ===== Fading =====

-- Fading towards the user's volume is a fade-in, anything below it a fade-out.
local function FadeName(channel)
  return (channel.to >= 1 and "fade-in" or "fade-out") .. " " .. channel.name
end

local function Forget(channel)
  channel.base, channel.baseNumber, channel.lastSet, channel.factor = nil, nil, nil, nil
  channel.from, channel.to, channel.startTime, channel.duration = nil, nil, nil, nil
end

-- True if the CVar no longer holds the value we wrote last.
local function ChangedByOthers(channel)
  return tonumber(C_CVar_GetCVar(channel.cvar)) ~= channel.lastSet
end

-- Writes the user's value back (unless somebody else has set a new one meanwhile) and stops touching the channel.
local function Restore(channel)
  if channel.base and not ChangedByOthers(channel) then
    C_CVar_SetCVar(channel.cvar, channel.base)
  end
  Forget(channel)
end

-- Restore() outside of a regular fade-in, e.g. when the channel or the whole module gets disabled.
local function RestoreNow(channel, reason)
  if channel.base then
    if channel.duration then
      DebugPrint("|cffff6666stop|r " .. FadeName(channel) .. " (" .. reason .. ")")
    end
    DebugPrint(channel.name .. " restored to " .. channel.base .. " instantly (" .. reason .. ")")
  end
  Restore(channel)
end

local function SetFactor(channel, factor)
  channel.factor = factor
  C_CVar_SetCVar(channel.cvar, channel.baseNumber * factor)
  channel.lastSet = tonumber(C_CVar_GetCVar(channel.cvar))
end

local function OnUpdate()
  local now = GetTime()
  local fading = false

  for _, channel in ipairs(CHANNELS) do
    if channel.duration then
      if ChangedByOthers(channel) then
        -- Somebody else has set a volume meanwhile. Theirs wins.
        DebugPrint("|cffff6666stop|r " .. FadeName(channel) .. " (volume changed by someone else to " .. tostring(C_CVar_GetCVar(channel.cvar)) .. ", keeping it)")
        Forget(channel)
      else
        local t = (now - channel.startTime) / channel.duration
        if t < 1 then
          local easing = channel.to >= 1 and FADE_IN_EASING or FADE_OUT_EASING
          SetFactor(channel, Interpolate(channel.from, channel.to, easing(t)))
          fading = true
        elseif channel.to >= 1 then
          DebugPrint("|cffff6666stop|r " .. FadeName(channel) .. " (back at " .. channel.base .. ")")
          Restore(channel)
        else
          SetFactor(channel, channel.to)
          channel.duration = nil
          DebugPrint("|cffff6666stop|r " .. FadeName(channel) .. " (at " .. tostring(C_CVar_GetCVar(channel.cvar)) .. ")")
        end
      end
    end
  end

  if not fading then
    frame:SetScript("OnUpdate", nil)
  end
end

-- Fades the channel from wherever it is now to target (a fraction of the user's volume, 1 = back to normal).
local function FadeTo(channel, target, duration)
  if channel.base and ChangedByOthers(channel) then
    if channel.duration then
      DebugPrint("|cffff6666stop|r " .. FadeName(channel) .. " (volume changed by someone else to " .. tostring(C_CVar_GetCVar(channel.cvar)) .. ", keeping it)")
    end
    Forget(channel)
  end

  if not channel.base then
    -- Nothing to bring back for a channel we never touched.
    if target >= 1 then return end
    channel.base       = C_CVar_GetCVar(channel.cvar)
    channel.baseNumber = tonumber(channel.base) or 1
    channel.lastSet    = tonumber(channel.base)
    channel.factor     = 1
  end

  if channel.duration then
    DebugPrint("|cffff6666stop|r " .. FadeName(channel) .. " (interrupted)")
  end

  channel.from      = channel.factor
  channel.to        = target
  channel.startTime = GetTime()
  -- A zero duration still goes through OnUpdate and is done on the next frame.
  channel.duration  = math_max(duration or 0, 0.001)
  frame:SetScript("OnUpdate", OnUpdate)

  DebugPrint(("|cff66ff66start|r %s: %.0f%% -> %.0f%% of %s in %.2fs")
    :format(FadeName(channel), channel.from * 100, target * 100, channel.base, duration or 0))
end


-- In delves, your companion comments on their own actions quite often during combat, and some sound
-- effects (picking up treasure, collapsing rocks) play on the Dialog channel, too.
-- HasActiveDelve() alone stays true after leaving a delve that is still going, hence IsInInstance().
-- Lairs count as delves here, too ("every lair is a delve", Blizzard_FrameXML/InstanceDifficulty.lua).
local function InDelve()
  return C_DelvesUI and C_DelvesUI.HasActiveDelve() and IsInInstance()
end

-- Whether the Dialog sounds playing right now should get the other channels faded out.
local function ShouldFade()
  -- No point in making room for a dialog the user cannot hear.
  if not C_CVar_GetCVarBool("Sound_EnableDialog") or (tonumber(C_CVar_GetCVar("Sound_DialogVolume")) or 0) == 0 then
    DebugPrint("Dialog channel is muted, not fading")
    return false
  end
  -- The Test button's line is faded for anywhere, so the settings can be tried out in a delve, too.
  if LP_config.dialogFadeSound_ignoreDelves and not testHandle and InDelve() then
    DebugPrint("in a delve, not fading")
    return false
  end
  return true
end

local function OnDialogStart()
  if not ShouldFade() then return end
  for _, channel in ipairs(CHANNELS) do
    if LP_config[channel.enabledKey] then
      FadeTo(channel, LP_config[channel.volumeKey], LP_config[channel.fadeOutKey])
    end
  end
end

local function OnDialogEnd()
  for _, channel in ipairs(CHANNELS) do
    FadeTo(channel, 1, LP_config[channel.fadeInKey])
  end
end


-- ===== Dialog detection =====

-- Moves those of the first count handles in started that play on the Dialog channel into active.
local function CollectDialogSounds(count, now)
  for i = 1, count do
    before[i] = C_Sound_GetSoundScaledVolume(started[i])
  end

  local original = C_CVar_GetCVar("Sound_DialogVolume")
  local current = tonumber(original) or 1
  C_CVar_SetCVar("Sound_DialogVolume", current > 0.5 and current - 0.25 or current + 0.25)
  for i = 1, count do
    local after = C_Sound_GetSoundScaledVolume(started[i])
    if before[i] and after and math_abs(after - before[i]) > 0.0001 then
      active[started[i]] = now
      -- Printing the sound kit ID here is only possible for talking heads. No API maps a handle back to its
      -- sound kit, and VO the engine plays by itself leaves no trace in Lua at all. But Blizzard keeps a talking
      -- head's handle in TalkingHeadFrame.voHandle, and C_TalkingHead.GetCurrentLineInfo() returns its sound kit.
      DebugPrint("|cff4d88ffstart dialog #" .. started[i] .. "|r")
    end
  end
  C_CVar_SetCVar("Sound_DialogVolume", original)
end

-- The Test button's label depends on whether its voice line is playing.
local function RefreshOptions()
  LibStub("AceConfigRegistry-3.0"):NotifyChange("Ludius Plus")
end

local function ProbeTick()
  local now = GetTime()

  local _, probe = PlaySound(PROBE_SOUNDKIT, "Master", false, false, nil, PROBE_VOLUME)
  if not probe then return end
  StopSound(probe)

  -- Everything between the previous probe and this one was started by someone else.
  if lastProbe then
    for h = math_max(lastProbe + 1, probe - MAX_SCAN), probe - 1 do
      pending[h] = now
    end
  end
  lastProbe = probe

  local count = 0
  for h, seen in pairs(pending) do
    if C_Sound_IsPlaying(h) then
      pending[h] = nil
      count = count + 1
      started[count] = h
    elseif now - seen > PENDING_TIMEOUT then
      pending[h] = nil
    end
  end

  -- The test line is over once it neither plays nor is still waiting to start (its file may take a while to load).
  if testHandle and not pending[testHandle] and not C_Sound_IsPlaying(testHandle) then
    testHandle = nil
    RefreshOptions()
  end

  local wasTalking = next(active) ~= nil

  if count > 0 then
    CollectDialogSounds(count, now)
  end
  for h, startTime in pairs(active) do
    if not C_Sound_IsPlaying(h) then
      active[h] = nil
      DebugPrint(("|cff4d88ffstop dialog #%d after %.1fs|r"):format(h, now - startTime))
    end
  end

  local talking = next(active) ~= nil
  if talking and not wasTalking then
    OnDialogStart()
  elseif wasTalking and not talking then
    OnDialogEnd()
  end
end


-- ===== Quest turn-in fanfare =====

-- Through Mute Sounds' helper, which counts mute reasons: the user may also have this file in Mute Sounds' list.
local function SetQuestFanfareMuted(mute)
  if mute == fanfareMuted then return end
  fanfareMuted = mute
  if mute then
    addon.MuteSoundFile(QUEST_FANFARE_FILE)
  else
    addon.UnmuteSoundFile(QUEST_FANFARE_FILE)
  end
end


-- ===== Setup / Teardown =====

local function EventFrameScript(self, event, ...)
  if event == "PLAYER_LOGOUT" then
    -- CVars are written to Config.wtf on logout and reload. Never let a faded volume get stuck in there.
    for _, channel in ipairs(CHANNELS) do
      RestoreNow(channel, "logout")
    end

  elseif event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == folderName then
      self:UnregisterEvent("ADDON_LOADED")
      addon.SetupOrTeardownDialogFadeSound()
    end
  end
end


local function SetupDialogFadeSound()
  if not probeTicker then
    lastProbe = nil
    wipe(pending)
    wipe(active)
    probeTicker = C_Timer_NewTicker(PROBE_INTERVAL, ProbeTick)
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", EventFrameScript)
  end

  SetQuestFanfareMuted(LP_config.dialogFadeSound_muteQuestFanfare)

  -- The settings may have changed while a dialog is playing.
  local talking = next(active) ~= nil
  local fade = talking and ShouldFade()
  for _, channel in ipairs(CHANNELS) do
    if not LP_config[channel.enabledKey] then
      RestoreNow(channel, "channel disabled")
    elseif fade then
      FadeTo(channel, LP_config[channel.volumeKey], LP_config[channel.fadeOutKey])
    elseif talking then
      -- E.g. "Don't fade in delves" just got switched on.
      FadeTo(channel, 1, LP_config[channel.fadeInKey])
    end
  end
end


local function TeardownDialogFadeSound()
  if probeTicker then
    probeTicker:Cancel()
    probeTicker = nil
  end

  if testHandle then
    StopSound(testHandle)
    testHandle = nil
  end

  for _, channel in ipairs(CHANNELS) do
    RestoreNow(channel, "module disabled")
  end

  SetQuestFanfareMuted(false)

  lastProbe = nil
  wipe(pending)
  wipe(active)
  wipe(started)
  wipe(before)

  frame:UnregisterAllEvents()
  frame:SetScript("OnEvent", nil)
  frame:SetScript("OnUpdate", nil)
end


-- ===== Test button =====

function addon.IsDialogFadeSoundTestPlaying()
  return testHandle ~= nil
end

-- Plays a voice line on the Dialog channel, or stops the one still playing. It is picked up by the regular
-- detection like any other Dialog sound, so what you hear is what a real dialog gets (see TEST BUTTON above
-- for the exceptions).
function addon.ToggleDialogFadeSoundTest()
  if testHandle then
    StopSound(testHandle)
    testHandle = nil
    return
  end

  testIndex = testIndex % #TEST_SOUNDKITS + 1
  local soundKit = TEST_SOUNDKITS[testIndex]

  local willPlay, handle = PlaySound(soundKit, "Dialog")
  if willPlay then
    testHandle = handle
    DebugPrint("test playing sound kit " .. soundKit)
    -- Fades only start when the first Dialog sound starts. If one is already playing without them (e.g. a
    -- companion remark in a delve with "Don't fade in delves"), the test line has to start them itself.
    if next(active) ~= nil then
      OnDialogStart()
    end
  else
    print("|cffff0000Ludius Plus:|r " .. L["Could not play the test dialog. Is Dialog sound enabled in the game's sound settings?"])
  end
end


function addon.SetupOrTeardownDialogFadeSound()
  if LP_config and (LP_config.dialogFadeSound_music_enabled or LP_config.dialogFadeSound_sfx_enabled or LP_config.dialogFadeSound_ambience_enabled) then
    SetupDialogFadeSound()
  else
    TeardownDialogFadeSound()
  end
end


-- Initialize when addon loads
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", EventFrameScript)
