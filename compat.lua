local folderName, addon = ...

-- Differences between the clients LudiusPlus runs on. Loaded before all module files.


-- WOW_PROJECT_CAMELOT is only defined in WoW Forever.
-- Forever's UI is built on the retail one, but some content (housing, delves,
-- Skyriding races, Dracthyr, ...) does not exist there.
addon.isForever = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT


-- The keys under which the per-character saved variables (LP_desiredCompanion,
-- LP_desiredUnsheath, LP_lastMount) store the current character:
-- savedVariable[realmKey][characterKey]
--
-- Not before PLAYER_LOGIN, because the character is not reliably known before that.
-- WoW Forever for example returns "Unknown" for UnitName("player") at load time.
function addon.GetCharacterKeys()

  local realmKey = GetRealmName()
  local characterKey = UnitName("player")

  -- WoW Forever has no realms. All characters of an account share one world and
  -- GetRealmName() only returns the leftover name of whatever shard a character was
  -- migrated from. What actually keeps characters apart there is the game ruleset,
  -- so we use that as the realm key, just like AceDB-3.0 does.
  if addon.isForever then
    if C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset) then
      realmKey = "Hardcore"
    elseif C_GameRules.IsGameRuleActive(Enum.GameRule.RPRuleset) then
      realmKey = "RP"
    elseif C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset) then
      realmKey = "PvP"
    else
      realmKey = "PvE"
    end

    -- Without realms, first names are no longer unique on WoW Forever, only first name
    -- and surname together are. UnitName() returns the surname where other clients
    -- return the realm. We join them the same way AceDB-3.0 does.
    local name, surname = UnitNameUnmodified("player")
    if surname and surname ~= "" then
      characterKey = name .. " " .. surname
    end
  end

  -- Must never be nil or empty, because they are used as table keys.
  if not realmKey or realmKey == "" then realmKey = UNKNOWN end
  if not characterKey or characterKey == "" then characterKey = UNKNOWN end

  return realmKey, characterKey
end
