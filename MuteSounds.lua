local folderName, addon = ...

-- Store the currently muted sound IDs so we can unmute them if needed
local currentlyMutedSounds = {}

addon.SetupMuteSounds = function()
  -- First, unmute any previously muted sounds
  for soundId in pairs(currentlyMutedSounds) do
    UnmuteSoundFile(soundId)
  end
  
  -- Clear the table
  for k in pairs(currentlyMutedSounds) do
    currentlyMutedSounds[k] = nil
  end
  
  -- If the module is disabled, don't mute anything
  if not LP_config or not LP_config.muteSounds_enabled then
    return
  end
  
  -- Parse the comma-separated sound IDs and mute them
  local soundIds = LP_config.muteSounds_soundIds or "598079, 598187"
  for soundId in soundIds:gmatch("([^,]+)") do
    soundId = tonumber(soundId:match("%d+"))
    if soundId then
      MuteSoundFile(soundId)
      currentlyMutedSounds[soundId] = true
    end
  end
end

-- Call setup on player login
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  addon.SetupMuteSounds()
end)

