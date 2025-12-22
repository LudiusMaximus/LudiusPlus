local folderName, addon = ...

local LibMountInfo = LibStub("LibMountInfo-1.0")

local C_MountJournal_SummonByID = C_MountJournal.SummonByID
local C_Timer_After = C_Timer.After
local pairs = pairs


-- Get all "Race Starting" buff IDs with the copy ID button here:
-- https://www.wowhead.com/spells/uncategorized/name:race+starting
-- (Use the "copy" icon, then select ID. Sorting must be done afterwards.)
local raceBuffsList = {369893, 370014, 370326, 370329, 370419, 370426, 372239, 373495, 373571, 373578, 373851, 373857, 374088, 374091, 374143, 374144, 374182, 374183, 374244, 374246, 374412, 374414, 374592, 374593, 374825, 375236, 375261, 375262, 375356, 375358, 375477, 375479, 375810, 376062, 376195, 376366, 376805, 376817, 377025, 377026, 377692, 377745, 378415, 378430, 378753, 378775, 379036, 379397, 381978, 382000, 382632, 382652, 382717, 382755, 383473, 383474, 383596, 383597, 386211, 386331, 387548, 387563, 392228, 395088, 396688, 396710, 396712, 396714, 396934, 396943, 396960, 396977, 396984, 396997, 397050, 397129, 397131, 397141, 397143, 397147, 397151, 397155, 397157, 397175, 397179, 397182, 397187, 397189, 398027, 398034, 398049, 398054, 398100, 398107, 398113, 398116, 398120, 398123, 398141, 398213, 398228, 398264, 398309, 398326, 398408, 398428, 403192, 403205, 403502, 403533, 403679, 403729, 403746, 403784, 403795, 403830, 403884, 403898, 403934, 403992, 404002, 404558, 404640, 404644, 406234, 406257, 406294, 406297, 406398, 406400, 406401, 406420, 406421, 406422, 406438, 406439, 406440, 406506, 406507, 406508, 406696, 406697, 406698, 406766, 406767, 406768, 406799, 406800, 406801, 406923, 406924, 406925, 406943, 406944, 406945, 407214, 407215, 407216, 407529, 407530, 407531, 407593, 407594, 407595, 407619, 407620, 407621, 407717, 407718, 407719, 407756, 407757, 407758, 409713, 409738, 409758, 409759, 409760, 409761, 409762, 409763, 409766, 409768, 409774, 409775, 409778, 409780, 409782, 409783, 409786, 409787, 409791, 409792, 409793, 409794, 409796, 409797, 409799, 409800, 409801, 409802, 409803, 409804, 409807, 409808, 409811, 409812, 409814, 409815, 409817, 409818, 409820, 409821, 409855, 409857, 409859, 409860, 409861, 409862, 409863, 409864, 409865, 409866, 409867, 409868, 410748, 410749, 410750, 410751, 410752, 410753, 410754, 410755, 410756, 410757, 410758, 410759, 410853, 410854, 410855, 410856, 410857, 410858, 410859, 410860, 410861, 410862, 410863, 410864, 411311, 411312, 411314, 411315, 411316, 411317, 411318, 411319, 411320, 411322, 411323, 411325, 411326, 411327, 411329, 411330, 411331, 411332, 411333, 411334, 411335, 411336, 411337, 411338, 411339, 411340, 411341, 411342, 411343, 411345, 411346, 411347, 413655, 413690, 413695, 413778, 413779, 413780, 413851, 413852, 413854, 413940, 413941, 413942, 413966, 413967, 413968, 414016, 414017, 414018, 414349, 414350, 414351, 414368, 414372, 414374, 414616, 414617, 414618, 414740, 414741, 414742, 414751, 414755, 414756, 414773, 414774, 414775, 414829, 414830, 414831, 414891, 414892, 414893, 415587, 417042, 417043, 417044, 417226, 417230, 417231, 417604, 417605, 417606, 417758, 417760, 417761, 417869, 417870, 417871, 417948, 417949, 417950, 418026, 418027, 418028, 418142, 418143, 418144, 418287, 418288, 418289, 418461, 418465, 418466, 419432, 419433, 419434, 419679, 419680, 419681, 420157, 420158, 420159, 420742, 420917, 420965, 420975, 420988, 421060, 421437, 421438, 421439, 421451, 421452, 422015, 422017, 422018, 422020, 422021, 422174, 422175, 422176, 422178, 422179, 422400, 422401, 422402, 422403, 422404, 423378, 423380, 423381, 423382, 423383, 423562, 423568, 423577, 423579, 423580, 425090, 425091, 425092, 425333, 425334, 425335, 425449, 425450, 425452, 425597, 425598, 425601, 425740, 425741, 425742, 426038, 426039, 426040, 426109, 426110, 426111, 426347, 426348, 426349, 426583, 426584, 426585, 427231, 427234, 427235, 431833, 431834, 431835, 431898, 431899, 431900, 439233, 439234, 439235, 439236, 439238, 439239, 439241, 439243, 439244, 439245, 439246, 439247, 439248, 439249, 439250, 439251, 439252, 439254, 439257, 439258, 439260, 439261, 439262, 439263, 439265, 439266, 439267, 439268, 439269, 439270, 439271, 439272, 439273, 439274, 439275, 439276, 439277, 439278, 439281, 439282, 439283, 439284, 439286, 439287, 439288, 439289, 439290, 439291, 439292, 439293, 439294, 439295, 439296, 439298, 439300, 439301, 439302, 439303, 439304, 439305, 439307, 439308, 439309, 439310, 439311, 439313, 439316, 439317, 439318, 439319, 439320, 439321}

-- For faster lookups:
local raceBuffs = {}
for _, v in pairs(raceBuffsList) do
  raceBuffs[v] = true
end


-- A flag indicating that we are in the pre-race countdown phase,
-- where the mount swapping has to take place.
local preRacePhase = nil
local summoningLastMount = nil
local trackingResumeTimer = nil

local function ResumeTrackingWithCleanup()
  preRacePhase = nil
  summoningLastMount = nil
  LibMountInfo:ResumeTracking()
  if trackingResumeTimer then
    trackingResumeTimer:Cancel()
    trackingResumeTimer = nil
  end
end


local eventFrame = CreateFrame("Frame")


local function EventFrameScript(self, event, ...)

  if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
    local currentMount, isFlying = LibMountInfo:GetCurrentMount()
    local lastFlyingMount = LibMountInfo:GetLastFlyingMount()

    -- print(preRacePhase, currentMount, isFlying, lastFlyingMount)
    if preRacePhase and currentMount and isFlying and lastFlyingMount and currentMount ~= lastFlyingMount then
      if not summoningLastMount then
        summoningLastMount = true
        -- Got to delay because the game will switch back to the Protodrake within the first 2 seconds.
        C_Timer_After(2, function() C_MountJournal_SummonByID(lastFlyingMount) end)
      end
    end

  elseif event == "UNIT_AURA" then
    local unitTarget, updateInfo = ...
    if unitTarget ~= "player" then return end

    if updateInfo and updateInfo.addedAuras then
      for _, v in pairs(updateInfo.addedAuras) do
        if v.spellId then
          if raceBuffs[v.spellId] then
            -- print("Starting race countdown")
            preRacePhase = true
            -- Pause LibMountInfo tracking so the automatic race mount is not recorded as the last mount
            LibMountInfo:PauseTracking()
            -- Safeguard: resume tracking after 10 seconds in case race proper spell is never detected
            if trackingResumeTimer then
              trackingResumeTimer:Cancel()
            end
            trackingResumeTimer = C_Timer.NewTimer(10, ResumeTrackingWithCleanup)
            break
          elseif v.spellId == 369968 then
            -- print("Starting race proper")
            ResumeTrackingWithCleanup()
            break
          end
        end
      end
    end

  elseif event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "LudiusPlus" then
      self:UnregisterEvent("ADDON_LOADED")
      addon.SetupOrTeardownRaceOnLastMount()
    end

  end
end


local function SetupRaceOnLastMount()
  -- print("SetupRaceOnLastMount")

  eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
  eventFrame:RegisterEvent("UNIT_AURA")
  eventFrame:SetScript("OnEvent", EventFrameScript)
end


local function TeardownRaceOnLastMount()
  -- print("TeardownRaceOnLastMount")

  eventFrame:UnregisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
  eventFrame:UnregisterEvent("UNIT_AURA")
  eventFrame:SetScript("OnEvent", nil)

  -- Clean up any pending timers
  if trackingResumeTimer then
    trackingResumeTimer:Cancel()
    trackingResumeTimer = nil
  end

  -- Resume tracking if it was paused
  if preRacePhase then
    ResumeTrackingWithCleanup()
  end
end


function addon.SetupOrTeardownRaceOnLastMount()
  if LP_config and LP_config.raceOnLastMount_enabled then
    SetupRaceOnLastMount()
  else
    TeardownRaceOnLastMount()
  end
end


-- Initialize when addon loads
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", EventFrameScript)
