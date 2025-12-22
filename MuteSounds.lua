local folderName, addon = ...

-- Store the currently muted sound IDs so we can unmute them if needed
local currentlyMutedSounds = {}

local function SetupMuteSounds()
  -- Parse the comma-separated sound IDs and mute them
  local soundIds = LP_config.muteSounds_soundIds
  for soundId in soundIds:gmatch("([^,]+)") do
    soundId = tonumber(soundId:match("%d+"))
    if soundId then
      MuteSoundFile(soundId)
      currentlyMutedSounds[soundId] = true
    end
  end
end

local function TeardownMuteSounds()
  -- Unmute any previously muted sounds
  for soundId in pairs(currentlyMutedSounds) do
    UnmuteSoundFile(soundId)
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


