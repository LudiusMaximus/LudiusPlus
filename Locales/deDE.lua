local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "deDE")
if not L then return end

-- Module Descriptions
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both."] = "Weist dem Ab- und Aufsitzen eine einzelne Taste zu, sodass ihr bequem zwischen beidem wechseln könnt."
L["Toggles the \"%s\" toy on and off with a hotkey."] = "Schaltet das „%s“ Spielzeug per Hotkey an und aus."
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "Schaltet spezifische Töne anhand ihrer Sound-Datei-IDs stumm.\n\nIDs findet ihr auf Wowhead (https://www.wowhead.com/sounds/) oder informiert euch über andere Methoden unter https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nBeispiel: 598079, 598187 (Ruf-Geräusche des Pflichtbewussten Knappen)."
L["Automatically skip confirmation dialogs"] = "Überspringt automatisch Bestätigungsdialoge."
L["Automatically maintain your desired weapon sheath state."] = "Behält automatisch den gewünschten Waffen-Zieh-Status bei."
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals"] = "Beschwört automatisch euren letzten aktiven Haustier-Begleiter neu, nachdem er verschwunden ist. Zum Beispiel nach dem Fliegen oder dem Durchschreiten von Portalen."

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "Ab-/Aufsitzen-Umschalter"
L["Enable"] = "Aktivieren"
L["Assigned Hotkey:"] = "Zugewiesener Hotkey:"
L["Not Bound"] = "Nicht gebunden"
L["New Key Bind"] = "Neue Tastenbelegung"
L["Assign a new hotkey binding."] = "Weist eine neue Taste zu."
L["Unbind"] = "Löschen"
L["Unassign the current binding."] = "Entfernt die aktuelle Belegung."
L["When mounting, switch automatically to Action Bar:"] = "Wechsle beim Aufsitzen automatisch zur Aktionsleiste:"
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."] = "Wechselt beim Aufsitzen automatisch zu dieser Aktionsleiste, damit Flug-/Reittier-Fähigkeiten sofort erreichbar sind. Auf „deaktiviert“ setzen, um die jeweils aktuelle Leiste beizubehalten."
L["Druid Travel Form instead of mounting"] = "Druiden-Reisegestalt statt Reittier"
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = "Nur Druiden: Nutzt Reise- oder Fluggestalt als „Aufsitzen“ und Humanoide Gestalt als „Absitzen“, anstatt normaler Reittiere."
L["Dracthyr Soar instead of mounting"] = "Dracthyr-Segeln statt Reittier"
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = "Nur Dracthyr: Nutzt Segeln als „Aufsitzen“ und Humanoide Gestalt als „Absitzen“, anstatt normaler Reittiere."
L["Mounts to ignore (comma-separated Mount IDs)"] = "Zu ignorierende Reittiere (kommagetrennte IDs)"
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"] = "Gebt Reittier-IDs ein, die beim Speichern des letzten Reittiers ignoriert werden sollen. Nützlich für Nutz-Reittiere wie Yak oder Brutosaurus, die ihr nur kurzzeitig nutzt, aber nicht per Hotkey rufen wollt.\n\nReittier-IDs findet ihr unter: https://www.wowhead.com/spells/mounts"
L["Fill in Utility Mounts"] = "Nutz-Reittiere eintragen"
L["Adds commonly used utility mounts to the ignore list:"] = "Fügt häufig genutzte Nutz-Reittiere zur Ignorierliste hinzu:"
L["Auto-mount last non-ignored mount when on ignored mounts"] = "Automatisch auf nicht-ignoriertes Reittier wechseln, wenn auf ignoriertem Reittier"
L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."] = "Wenn ihr auf einem ignorierten Reittier sitzt, wird der Hotkey euch absitzen lassen und sofort das letzte nicht-ignorierte Reittier beschwören. Deaktivieren, um nur abzusitzen."

-- RaceOnLastMount Options
L["Race on Last Mount"] = "Rennen mit letztem Reittier"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = "Wenn ihr ein Himmelsreiten-Rennen startet, ohne aufzusitzen, werdet ihr automatisch auf den Erneuerten Protodrachen gesetzt. Dieses Addon wechselt während des Countdowns automatisch auf euer letztes aktives Flugreittier (nach 2 Sekunden Verzögerung).\n\nHinweis: Automatischer Wechsel in Druiden-Fluggestalt ist aufgrund von API-Beschränkungen nicht möglich."

-- Flashlight Options
L["Flashlight (Torch)"] = "Taschenlampe (Fackel)"
L["Torch Toggle"] = "Fackel umschalten"
L["Toy Missing:"] = "Spielzeug fehlt:"
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = "Ihr besitzt das „%s“ nicht!\nHolt es euch aus der Beleuchteten Schließkiste:\nhttps://www.wowhead.com/de/object=437211/beleuchtete-schließkiste"

-- MuteSounds Options
L["Mute Sounds"] = "Töne stummschalten"
L["Sound IDs to mute (comma-separated)"] = "Stummzuschaltende Sound-IDs (kommagetrennt)"
L["Enter Sound File IDs separated by commas."] = "Gebt Sound-Datei-IDs durch Kommas getrennt ein."

-- DialogSkipper Options
L["Dialog Skipper"] = "Dialog-Überspringer"
L["Skip auction house buyout confirmations"] = "Sofortkauf-Bestätigungen im Auktionshaus überspringen"
L["Only skip if price is below (gold)"] = "Nur überspringen, wenn Preis niedriger ist als (Gold)"
L["Set the maximum price in gold for automatically confirming auctions."] = "Legt den Höchstpreis in Gold fest, bis zu dem Auktionen automatisch bestätigt werden."
L["Skip Polished Pet Charm purchases"] = "Käufe mit Polierten Haustierglücksbringern überspringen"
L["Skip Order Resources purchases"] = "Käufe mit Ordenressourcen überspringen"
L["Skip equip bind confirmations"] = "Bestätigungen für „Beim Anlegen gebunden“ überspringen"
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = "Bestätigt automatisch Dialoge für „Beim Anlegen gebunden“, wenn Ausrüstung von Questbelohnungen, Händlern oder anderen Quellen angelegt wird."

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "Dauerhafte Waffenhaltung"
L["Restore sheathed"] = "Weggesteckt wiederherstellen"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "Merkt sich, wenn ihr die Waffe zuletzt weggesteckt habt, und kehrt automatisch in diesen Zustand zurück, sobald eine Spielaktion die Waffe zieht (z.B. nach dem Kampf)."
L["Restore unsheathed"] = "Gezogen wiederherstellen"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "Merkt sich, wenn ihr die Waffe zuletzt gezogen habt, und kehrt automatisch in diesen Zustand zurück, sobald eine Spielaktion die Waffe wegsteckt (z.B. nach dem Zaubern oder Interagieren mit NPCs)."
L["Silent restoration"] = "Stille Wiederherstellung"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "Schaltet die Soundeffekte beim Ziehen und Wegstecken stumm, wenn das Addon den Waffenstatus automatisch wiederherstellt. Die Töne beim manuellen Umschalten sind nicht betroffen."

-- PersistentCompanion Options
L["Persistent Companion"] = "Dauerhafter Begleiter"
