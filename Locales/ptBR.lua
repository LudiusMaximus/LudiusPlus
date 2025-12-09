local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "ptBR")
if not L then return end

-- Module Descriptions
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both."] = "Assign dismounting and re-mounting to a single key, so you can comfortably switch between both."
L["Switch between Cave Spelunker's Torch on and off with a hotkey."] = "Switch between Cave Spelunker's Torch on and off with a hotkey."
L["Mute specific sounds by their Sound File IDs. E.g. annoying summon sounds."] = "Mute specific sounds by their Sound File IDs. E.g. annoying summon sounds."
L["Automatically skip confirmation dialogs"] = "Automatically skip confirmation dialogs"
L["Automatically maintain your desired weapon sheath state."] = "Automatically maintain your desired weapon sheath state."
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals"] = "Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals"

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "Dismount/Mount Toggle"
L["Enable"] = "Enable"
L["Assigned Hotkey:"] = "Assigned Hotkey:"
L["Not Bound"] = "Not Bound"
L["New Key Bind"] = "New Key Bind"
L["Assign a new hotkey binding."] = "Assign a new hotkey binding."
L["Unbind"] = "Unbind"
L["Unassign the current binding."] = "Unassign the current binding."
L["When mounting, switch automatically to Action Bar:"] = "When mounting, switch automatically to Action Bar:"
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to 'disabled' to keep your current action bar."] = "Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to 'disabled' to keep your current action bar."
L["Druid Travel Form instead of mounting"] = "Druid Travel Form instead of mounting"
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = "Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."
L["Dracthyr Soar instead of mounting"] = "Dracthyr Soar instead of mounting"
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = "Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."
L["Mounts to ignore (comma-separated Mount IDs)"] = "Mounts to ignore (comma-separated Mount IDs)"
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey. Find Mount IDs at: https://www.wowhead.com/spells/mounts"] = "Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey. Find Mount IDs at: https://www.wowhead.com/spells/mounts"
L["Fill in Utility Mounts"] = "Fill in Utility Mounts"
L["Adds commonly used utility mounts to the ignore list:"] = "Adds commonly used utility mounts to the ignore list:"

-- RaceOnLastMount Options
L["Race on Last Mount"] = "Race on Last Mount"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game). Note: Cannot automatically switch to Druid Flight Form due to API limitations."] = "When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game). Note: Cannot automatically switch to Druid Flight Form due to API limitations."

-- Flashlight Options
L["Flashlight (Torch)"] = "Flashlight (Torch)"
L["Torch Toggle"] = "Torch Toggle"

-- MuteSounds Options
L["Mute Sounds"] = "Mute Sounds"
L["Sound IDs to mute (comma-separated)"] = "Sound IDs to mute (comma-separated)"
L["Enter Sound File IDs separated by commas. Find IDs on WoW databases like Wowhead or using UI addons. Example: 598079, 598187"] = "Enter Sound File IDs separated by commas. Find IDs on WoW databases like Wowhead or using UI addons. Example: 598079, 598187"

-- DialogSkipper Options
L["Dialog Skipper"] = "Dialog Skipper"
L["Skip auction house buyout confirmations"] = "Skip auction house buyout confirmations"
L["Only skip if price is below (gold)"] = "Only skip if price is below (gold)"
L["Set the maximum price in gold for automatically confirming auctions."] = "Set the maximum price in gold for automatically confirming auctions."
L["Skip Polished Pet Charm purchases"] = "Skip Polished Pet Charm purchases"
L["Skip Order Resources purchases"] = "Skip Order Resources purchases"
L["Skip equip bind confirmations"] = "Skip equip bind confirmations"
L["Automatically confirm 'Bind on Equip' dialogs when equipping gear from quest rewards, vendors, or other sources."] = "Automatically confirm 'Bind on Equip' dialogs when equipping gear from quest rewards, vendors, or other sources."

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "Persistent Unsheath"
L["Restore sheathed"] = "Restore sheathed"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."
L["Restore unsheathed"] = "Restore unsheathed"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."
L["Silent restoration"] = "Silent restoration"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."

-- PersistentCompanion Options
L["Persistent Companion"] = "Persistent Companion"
