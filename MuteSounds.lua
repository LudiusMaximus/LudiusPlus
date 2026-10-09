local folderName, addon = ...


-- The same sound file can be muted for more than one reason: by this module and by Dialog Fade Sound's
-- "Mute quest turn-in fanfare" option. So we count the reasons and only really unmute a file once none is
-- left. Otherwise switching off one of them would silently undo the other's mute.
local muteReasons = {}  -- fileID -> number of reasons it is muted for

function addon.MuteSoundFile(fileID)
  muteReasons[fileID] = (muteReasons[fileID] or 0) + 1
  if muteReasons[fileID] == 1 then
    MuteSoundFile(fileID)
  end
end

function addon.UnmuteSoundFile(fileID)
  local reasons = muteReasons[fileID]
  if not reasons then return end
  if reasons > 1 then
    muteReasons[fileID] = reasons - 1
  else
    muteReasons[fileID] = nil
    UnmuteSoundFile(fileID)
  end
end


-- Store the currently muted sound IDs so we can unmute them if needed
local currentlyMutedSounds = {}

local function SetupMuteSounds()
  -- Parse the comma-separated sound IDs and mute them
  local soundIds = LP_config.muteSounds_soundIds
  for entry in soundIds:gmatch("([^,]+)") do
    local soundId = tonumber(entry:match("%d+"))
    -- Skipping IDs listed twice, so each counts as one reason only.
    if soundId and not currentlyMutedSounds[soundId] then
      addon.MuteSoundFile(soundId)
      currentlyMutedSounds[soundId] = true
    end
  end
end

local function TeardownMuteSounds()
  -- Unmute any previously muted sounds
  for soundId in pairs(currentlyMutedSounds) do
    addon.UnmuteSoundFile(soundId)
  end
  
  -- Clear the table
  for k in pairs(currentlyMutedSounds) do
    currentlyMutedSounds[k] = nil
  end
end

-- Public function to enable or disable based on config
addon.SetupOrTeardownMuteSounds = function()
  TeardownMuteSounds()
  
  if LP_config and LP_config.muteSounds_enabled then
    SetupMuteSounds()
  end
end

-- Event frame for initialization
local eventFrame = CreateFrame("Frame")

local function EventFrameScript(self, event, loadedAddonName)
  if event == "ADDON_LOADED" and loadedAddonName == folderName then
    self:UnregisterEvent("ADDON_LOADED")
    addon.SetupOrTeardownMuteSounds()
  end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", EventFrameScript)


