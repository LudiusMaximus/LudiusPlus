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

-- DialogFadeSound Options
L["Dialog Fade Sound"] = true
L["While many voice lines are playing - a quest giver greeting you, a \"%s\", an NPC speaking up nearby - the game itself lowers the other sound channels a little. This is called \"ducking\", but Blizzard keeps it very subtle: the music usually only drops to about 75%%, and some voice lines are not ducked at all.\n\nSo if you like your music, effects or ambience fairly loud and still want to understand every dialog clearly, you may want more than that. This module notices whenever a sound plays on the Dialog channel and lowers the other channels through the game's own volume settings for as long as the dialog lasts.\n\nFor music, effects and ambience you can set separately how far they are lowered (in percent of the volume you have set for them), how quickly they fade out when a dialog starts, and how quickly they fade back in after it has ended. Unlike Blizzard's ducking, which often switches within a quarter of a second, the fades follow smooth curves and can be set to bring the channels back almost unnoticed."] = true
L["Fade music during dialog"] = true
L["Lower the music volume while a dialog is playing."] = true
L["Fade effects during dialog"] = true
L["Lower the sound effects volume (spells, combat, footsteps and the like) while a dialog is playing."] = true
L["Fade ambience during dialog"] = true
L["Lower the ambience volume (background sounds of your surroundings like wind, water or crowds) while a dialog is playing."] = true
L["Faded volume"] = true
L["How loud this channel is while a dialog is playing, in percent of the volume you have set for it. At 0% it is silenced completely."] = true
L["Fade-in time (sec)"] = true
L["How long it takes to bring the volume back up after a dialog has ended."] = true
L["Fade-out time (sec)"] = true
L["How long it takes to lower the volume when a dialog starts."] = true
L["Test"] = true
L["Stop"] = true
L["Play a voice line on the Dialog channel, so you can hear how the fading sounds with your current settings. Click again to stop it early."] = true
L["Could not play the test dialog. Is Dialog sound enabled in the game's sound settings?"] = true
L["Reset to Defaults"] = true
L["Resets the faded volume and the fade times of all three channels to the values Ludius found to work best. Which channels are faded stays as it is."] = true
L["Don't fade in delves"] = true
L["In delves, your companion comments on their own actions quite often during combat, and some sound effects (like picking up treasure or collapsing rocks) play on the Dialog channel, too. Some players may find the fading for all of these annoying and might want to turn it off in delves.\nThe Test button at the top of this page will always trigger a fade regardless."] = true
L["Mute quest turn-in fanfare"] = true
L["The fanfare that plays when you hand in a quest often drowns out the NPC's last words. On top of that, the game lowers the music while it plays and brings it back abruptly afterwards. With this option, the fanfare is muted, and the music stays as it is."] = true

-- MuteSounds Options
L["Mute Sounds"] = true
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = true
L["Sound IDs to mute (comma-separated)"] = true
L["Enter Sound File IDs separated by commas."] = true

-- DialogSkipper Options
L["Dialog Skipper"] = true
L["Automatically skip confirmation dialogs."] = true
L["Skip auction house buyout confirmations"] = true
L["Back to previous item list after buyout"] = true
L["After buying out an item, the addon automatically returns you to the previous item list overview. This is useful when you typically purchase one listing of an item and then want to go back to browse other items."] = true
L["Only skip if price is below (gold)"] = true
L["Set the maximum price in gold for automatically confirming auctions."] = true
L["Skip Polished Pet Charm purchases"] = true
L["Skip Order Resources purchases"] = true
L["Skip Dragon Isles Supplies purchases"] = true
L["Skip Community Coupons purchases"] = true
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
L["Display an |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in the spellbook, in the talent tree, or on action bars that are included in the single-button combat rotation. So you can identify them at a glance."] = true
L["Show in Spellbook"] = true
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in your spellbook that are included in the single-button combat rotation."] = true
L["Spellbook Icon Position"] = true
L["Choose the corner where the overlay icon appears on spellbook buttons."] = true
L["Show on Action Bars"] = true
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bar buttons for spells included in the rotation."] = true
L["Action Bar Icon Position"] = true
L["Choose the corner where the overlay icon appears on action bar buttons."] = true
L["Show in Talents"] = true
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on talents in your talent tree that are included in the single-button combat rotation."] = true
L["Talent Icon Position"] = true
L["Choose the corner where the overlay icon appears on talent buttons."] = true
L["Only when Single-Button is used"] = true
L["Only show the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bars if the Single-Button Assistant spell is currently placed on an action bar."] = true
L["Top Left"] = true
L["Top Right"] = true
L["Bottom Left"] = true
L["Bottom Right"] = true

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
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals."] = true
L["Dismiss pet while stealthed"] = true
L["Automatically dismiss your pet when entering stealth and resummon it when leaving stealth."] = true
L["Dismiss pet in combat"] = true
L["Automatically dismiss your pet when entering combat and resummon it when combat ends."] = true
L["Mute automatic summon sound"] = true
L["Mute the pet summon sound when automatically resummoning your pet. The sound from manual summoning is not affected.\n\nThis works for most pets (the ones using the \"huntertrapopen\" sound). Feel free to let the addon author know the IDs of other pet summing sounds to be added."] = true

-- HouseEditorEnhancer Options
L["Enhanced House Editor"] = true
L["Not being able to properly inspect the decor items in the small icons of the House Editor's %s and %s frames is a s#!tshow obviously. Ludius Plus's \"Thoughtfully Augmented Editor\" (TAE) - among other things - adds a slider to change the decor icon size and a preview side-pane (opened with CTRL + LEFTCLICK). This way, TAE gives you a better knowledge of what decor items look like before you place them. And knowledge is power!"] = true
L["Icon resize with slider"] = true
L["When enabled, a slider is added to the House Editor's %s/%s frame to customize the size of the decor icons."] = true
L["Icon resize with CTRL + mouse wheel"] = true
L["When enabled, holding CTRL while scrolling the mouse wheel over the House Editor's %s/%s frame resizes the decor icons."] = true
L["Decor preview"] = true
L["When enabled, you can CTRL + LEFTCLICK on decor icons in the House Editor's %s/%s frame to open a model preview next to it."] = true
L["Chain placement when holding SHIFT"] = true
L["When enabled, holding SHIFT while committing a decor placement immediately starts a new placement of the same item (as long as there are copies left in storage). A small icon at the cursor shows the remaining count."] = true
L["Decor Icon Size:"] = true
L["Resize decor item icons"] = true
L["by Ludius Plus"] = true
L["Not working in the \"%1$s\" category. The \"Thoughtfully Augmented Editor\" (TAE) wants no part of %2$s!"] = true
L["Reset to default size"] = true
L["Recent"] = true
L["\"Recent\" category"] = true
L["When enabled, a custom \"Recent\" category is added to the House Editor's Storage tab. It lists the decor items you recently modified, newest first - kept separately per house and per indoors/outdoors. Hover a tile and click the red X to drop it from the history. Disabling this option clears the saved history."] = true
L["Remove from history"] = true
L["If you cannot resist, go and spend your actual real-life money on it in the %1$s's \"%2$s\" category!"] = true
L["Hide blueprint codes"] = true
L["When enabled, blueprint share codes in the import and export windows are hidden behind dots, with an eye button to reveal them. Handy while streaming or screen-sharing: blueprints can be saved or imported without being exposed to viewers. The Copy and Post-to-Chat buttons work on the real codes regardless."] = true
L["Show blueprint code"] = true
L["Hide blueprint code"] = true

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = true

-- Dangerous Scripts Warning
L["To use certain features (like Dismount Toggle and Flashlight), LudiusPlus needs your permission to run macros.\n\nPlease click \"Allow Scripts\" below, then \"Yes\" in the game's confirmation pop-up to enable these modules."] = true
L["Allow Scripts"] = true
