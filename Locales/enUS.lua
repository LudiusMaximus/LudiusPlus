local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "enUS", true, true)
if not L then return end

-- DismountToggle Options
L["Dismount/Mount Toggle"] = true
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both. The addon will remember your last mount and re-mount it when you press the hotkey again."] = true
L["Enable"] = true
L["Assigned Hotkey:"] = true
L["Not Bound"] = true
L["New Key Bind"] = true
L["Assign a new hotkey binding."] = true
L["Unbind"] = true
L["Unassign the current binding."] = true
L["When mounting, switch automatically to Action Bar:"] = true
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."] = true
L["Druid Travel Form instead of mounting"] = true
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = true
L["Dracthyr Soar instead of mounting"] = true
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = true
L["Mounts to ignore (comma-separated Mount IDs)"] = true
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"] = true
L["Fill in Utility Mounts"] = true
L["Adds commonly used utility mounts to the ignore list:"] = true
L["Auto-mount last non-ignored mount when on ignored mounts"] = true
L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."] = true
L["Dismount/Mount Toggle module is disabled. Enable it in the addon options."] = true

-- RaceOnLastMount Options
L["Race on Last Mount"] = true
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = true

-- Flashlight Options
L["Flashlight (Torch)"] = true
L["Toggles the \"%s\" toy on and off with a hotkey."] = true
L["Torch Toggle"] = true
L["Toy Missing:"] = true
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = true
L["Flashlight module is disabled. Enable it in the addon options."] = true

-- MuteSounds Options
L["Mute Sounds"] = true
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = true
L["Sound IDs to mute (comma-separated)"] = true
L["Enter Sound File IDs separated by commas."] = true

-- DialogSkipper Options
L["Dialog Skipper"] = true
L["Automatically skip confirmation dialogs"] = true
L["Skip auction house buyout confirmations"] = true
L["Back to previous item list after buyout"] = true
L["After buying out an item, the addon automatically returns you to the previous item list overview. This is useful when you typically purchase one listing of an item and then want to go back to browse other items."] = true
L["Only skip if price is below (gold)"] = true
L["Set the maximum price in gold for automatically confirming auctions."] = true
L["Skip Polished Pet Charm purchases"] = true
L["Skip Order Resources purchases"] = true
L["Skip equip bind confirmations"] = true
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = true

-- VendorItemOverlay Options
L["Vendor Item Overlay"] = true
L["Display useful information as overlays for items at vendors."] = true
L["Ownership for decor items"] = true
L["Display ownership information for housing decor items when visiting vendors. Shows the count as [in storage]/[total owned] in the top-right corner of each item icon."] = true
L["Already known for toys"] = true
L["Grey out and mark toys that you already know."] = true
L["Already known for mounts"] = true
L["Grey out and mark mounts that you already know."] = true
L["Already known for transmogs and heirlooms"] = true
L["Grey out and mark transmog items/ensembles and heirlooms that you already know."] = true
L["Treat non-appearance items as known"] = true
L["Necklaces, rings and trinkets will be marked as already known even though they technically cannot be learned. This prevents them from looking like uncollected items in the vendor."] = true
L["Already known for pets"] = true
L["Grey out and mark battle pets that you have already collected."] = true
L["Already known for recipes"] = true
L["Grey out and mark recipes that you already know."] = true

-- SpellIconOverlay Options
L["Spell Icon Overlay"] = true
L["Display an |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in the spellbook or action bars that are included in the single-button combat rotation. So you can identify them at a glance."] = true
L["Show in Spellbook"] = true
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in your spellbook that are included in the single-button combat rotation."] = true
L["Show on Action Bars"] = true
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bar buttons for spells included in the rotation."] = true
L["Only when Single-Button is used"] = true
L["Only show the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bars if the Single-Button Assistant spell is currently placed on an action bar."] = true

-- PersistentUnsheath Options
L["Persistent Unsheath"] = true
L["Automatically maintain your desired weapon sheath state."] = true
L["Restore sheathed"] = true
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = true
L["Restore unsheathed"] = true
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = true
L["Silent restoration"] = true
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = true

-- PersistentCompanion Options
L["Persistent Companion"] = true
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals"] = true

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = true
