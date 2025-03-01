




-- -- Open inspector for any table:
-- UIParentLoadAddOn("Blizzard_DebugTools")
-- DisplayTableInspectorWindow(UIParent)



-- /tableinspect

-- /dump table
-- /run DevTools_DumpCommand("table")
-- /run DevTools_Dump(table)



-- -- For debugging.
-- function PrintTable(t, indent)
  -- assert(type(t) == "table", "PrintTable() called for non-table!")

  -- if not indent then indent = 0 end

  -- local indentString = ""
  -- for i = 1, indent do
    -- indentString = indentString .. "  "
  -- end

  -- for k, v in pairs(t) do
    -- if type(v) ~= "table" then
      -- print(indentString, k, "=", v)
    -- else
      -- print(indentString, k, "=")
      -- print(indentString, "  {")
      -- PrintTable(v, indent + 2)
      -- print(indentString, "  }")
    -- end
  -- end
-- end




-- -- ####### Get info about buffs. #######

-- local eventFrame = CreateFrame("Frame")
-- eventFrame:RegisterEvent("UNIT_AURA")
-- eventFrame:SetScript("OnEvent", function(_, event, ...)

  -- if event == "UNIT_AURA" then

    -- local unitTarget, updateInfo = ...
    -- if unitTarget == "player" and updateInfo.addedAuras then
      -- print(unitTarget)
      -- PrintTable(updateInfo.addedAuras)
    -- end
  -- end

-- end)








-- hooksecurefunc("PlaySound", function(...)
  -- print("PlaySound", ...)
  -- local id, channel, forceNoDuplicates, runFinishCallback = ...
-- end)







-- ####### Check for already done world quest. #######

-- hooksecurefunc("GameTooltip_AddQuest",
  -- function(self)
    -- print("GameTooltip_AddQuest", self.questID)

    -- if not self.worldQuest then return end


    -- -- Cannot list completed world quest. :-(
    -- -- https://www.wowinterface.com/forums/showthread.php?p=340098

    -- -- for _, id in pairs(C_QuestLog.GetAllCompletedQuestIDs()) do
      -- -- print(self.questID, "==", id)

      -- -- if (C_QuestLog.IsWorldQuest(id)) then
        -- -- print("AAAAAAAAAAAA")
        -- -- return
      -- -- end

      -- -- if self.questID == id then
        -- -- print("Did this before!")
        -- -- return
      -- -- end
    -- -- end

    -- -- print("Never done before!")

  -- end
-- )








-- ####### Critical hit camera shake. #######


-- local shakeFrame = CreateFrame("Frame")
-- local function OnUpdateShake()
  -- print("shake", GetTime())
-- end


-- local endShakeTimer = nil

-- local function ShakeCamera(duration)

  -- if shakeFrame:GetScript("OnUpdate") == nil then
    -- shakeFrame:SetScript("OnUpdate", OnUpdateShake)
  -- end

  -- if endShakeTimer and not endShakeTimer:IsCancelled() then
    -- endShakeTimer:Cancel()
  -- end

  -- endShakeTimer = C_Timer.NewTimer(duration, function()
    -- shakeFrame:SetScript("OnUpdate", nil)
  -- end)

-- end



-- playerGuid = UnitGUID("player")
-- local eventFrame = CreateFrame("Frame")
-- eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
-- eventFrame:SetScript("OnEvent", function()

  -- timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
  -- if sourceGUID == playerGuid then

    -- local amount, critical
    -- if subevent == "SWING_DAMAGE" then
      -- amount, _, _, _, _, _, critical = select(12, CombatLogGetCurrentEventInfo())
    -- elseif subevent == "SPELL_DAMAGE" then
      -- _, _, _, amount, _, _, _, _, _, critical = select(12, CombatLogGetCurrentEventInfo())
    -- else
      -- return
    -- end

    -- -- This comes noticeably earlier than the in-game action takes place.
    -- print(amount, critical)

  -- end
-- end)


