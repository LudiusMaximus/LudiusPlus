local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "itIT")
if not L then return end

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "Attiva/Disattiva Cavalcatura"
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both. The addon will remember your last mount and re-mount it when you press the hotkey again."] = "Assegna smonta e rimonta a un singolo tasto, così puoi passare comodamente da uno all'altro. L'addon ricorderà la tua ultima cavalcatura e la richiamerà quando premerai nuovamente il tasto."
L["Enable"] = "Abilita"
L["Assigned Hotkey:"] = "Tasto assegnato:"
L["Not Bound"] = "Non assegnato"
L["New Key Bind"] = "Nuova assegnazione"
L["Assign a new hotkey binding."] = "Assegna un nuovo tasto."
L["Unbind"] = "Rimuovi"
L["Unassign the current binding."] = "Rimuove l'assegnazione corrente."
L["When mounting, switch automatically to Action Bar:"] = "Quando monti, passa automaticamente alla Barra delle azioni:"
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."] = "Passa automaticamente a questa barra delle azioni quando monti in sella, così hai le abilità di volo/cavalcatura facilmente accessibili. Imposta su « disabilitato » per mantenere la tua barra attuale."
L["Druid Travel Form instead of mounting"] = "Forma di Viaggio Druido invece della cavalcatura"
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = "Solo Druidi: Usa Forma di Viaggio o Forma Volante come \"montare\", e la forma Umanoide come \"smontare\", invece delle cavalcature standard."
L["Dracthyr Soar instead of mounting"] = "Dracthyr Volteggio invece della cavalcatura"
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = "Solo Dracthyr: Usa Volteggio come \"montare\" e la forma Umanoide come \"smontare\", invece delle cavalcature standard."
L["Mounts to ignore (comma-separated Mount IDs)"] = "Cavalcature da ignorare (ID separati da virgola)"
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"] = "Inserisci gli ID delle cavalcature da ignorare quando memorizzi l'ultima cavalcatura. Utile per cavalcature di utilità come Yak o Brutosauro che usi temporaneamente ma non vuoi evocare con il tuo tasto rapido.\n\nTrova gli ID delle cavalcature su: https://www.wowhead.com/spells/mounts"
L["Fill in Utility Mounts"] = "Inserisci Cavalcature Utilità"
L["Adds commonly used utility mounts to the ignore list:"] = "Aggiunge le cavalcature di utilità comunemente usate alla lista ignorati:"
L["Auto-mount last non-ignored mount when on ignored mounts"] = "Monta automaticamente l'ultima cavalcatura non ignorata se su ignorata"
L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."] = "Mentre sei su una cavalcatura ignorata, il tasto ti farà smontare e monterà immediatamente l'ultima cavalcatura non ignorata. Disabilita per smontare solo."
L["Dismount/Mount Toggle module is disabled. Enable it in the addon options."] = "Il modulo Attiva/Disattiva Cavalcatura è disabilitato. Abilitalo nelle opzioni dell'addon."

-- RaceOnLastMount Options
L["Race on Last Mount"] = "Gara sull'ultima cavalcatura"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = "Se inizi una gara di Volo Dinamico senza essere in sella, verrai normalmente posizionato automaticamente sul Protodraco Rinnovato. Questo addon passa automaticamente alla tua ultima cavalcatura volante utilizzata durante il conto alla rovescia (dopo un ritardo di 2 secondi).\n\nNota: Il passaggio automatico alla Forma Volante del Druido non è possibile a causa di limitazioni dell'API."

-- Flashlight Options
L["Flashlight (Torch)"] = "Torcia elettrica (Torcia)"
L["Toggles the \"%s\" toy on and off with a hotkey."] = "Attiva e disattiva il giocattolo \"%s\" con un tasto rapido."
L["Torch Toggle"] = "Attiva/Disattiva Torcia"
L["Toy Missing:"] = "Giocattolo mancante:"
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = "Non possiedi il giocattolo \"%s\"!\nOttienilo dallo Scrigno illuminato:\nhttps://www.wowhead.com/it/object=437211/scrigno-illuminato"
L["Flashlight module is disabled. Enable it in the addon options."] = "Il modulo Torcia è disabilitato. Abilitalo nelle opzioni dell'addon."

-- MuteSounds Options
L["Mute Sounds"] = "Disattiva Suoni"
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "Disattiva suoni specifici tramite i loro ID file audio.\n\nTrova gli ID su Wowhead (https://www.wowhead.com/sounds/) o scopri altri metodi su https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nEsempio: 598079, 598187 (suoni di evocazione dello Scudiero Zelante)."
L["Sound IDs to mute (comma-separated)"] = "ID suoni da disattivare (separati da virgola)"
L["Enter Sound File IDs separated by commas."] = "Inserisci gli ID dei file audio separati da virgola."

-- DialogSkipper Options
L["Dialog Skipper"] = "Salta Dialoghi"
L["Automatically skip confirmation dialogs"] = "Salta automaticamente i dialoghi di conferma."
L["Skip auction house buyout confirmations"] = "Salta conferme di acquisto immediato all'asta"
L["Back to previous item list after buyout"] = "Torna all'elenco precedente dopo l'acquisto"
L["After buying out an item, the addon automatically returns you to the previous item list overview. This is useful when you typically purchase one listing of an item and then want to go back to browse other items."] = "Dopo aver acquistato un oggetto, l'addon ti riporta automaticamente alla panoramica dell'elenco degli oggetti precedente. È utile quando acquisti tipicamente un'offerta di un oggetto e poi vuoi tornare indietro per esplorare altri oggetti."
L["Only skip if price is below (gold)"] = "Salta solo se il prezzo è inferiore a (oro)"
L["Set the maximum price in gold for automatically confirming auctions."] = "Imposta il prezzo massimo in oro per confermare automaticamente le aste."
L["Skip Polished Pet Charm purchases"] = "Salta acquisti con Talismani per Mascotte Lucidati"
L["Skip Order Resources purchases"] = "Salta acquisti con Risorse per l'Enclave"
L["Skip equip bind confirmations"] = "Salta conferme vincolo all'equipaggiamento"
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = "Conferma automaticamente i dialoghi \"Vincolato all'Equipaggiamento\" quando equipaggi oggetti da ricompense missioni, venditori o altre fonti."

-- VendorItemOverlay Options
L["Vendor Item Overlay"] = "Sovrapposizione articoli venditore"
L["Display useful information as overlays for items at vendors."] = "Mostra informazioni utili come sovrapposizioni per gli articoli dai venditori."
L["Ownership for decor items"] = "Proprietà oggetti decorativi"
L["Display ownership information for housing decor items when visiting vendors. Shows the count as [in storage]/[total owned] in the top-right corner of each item icon."] = "Mostra le informazioni di proprietà per gli oggetti decorativi per l'abitazione quando visiti i venditori. Mostra il conteggio come [in magazzino]/[totale posseduto] nell'angolo in alto a destra di ogni icona oggetto."
L["Already known for toys"] = "Già noto per i giocattoli"
L["Grey out and mark toys that you already know."] = "Grigia e segna i giocattoli che conosci già."
L["Already known for mounts"] = "Già noto per le cavalcature"
L["Grey out and mark mounts that you already know."] = "Grigia e segna le cavalcature che conosci già."
L["Already known for transmogs and heirlooms"] = "Già noto per trasmogrificazioni e cimeli"
L["Grey out and mark transmog items/ensembles and heirlooms that you already know."] = "Grigia e segna gli oggetti/insiemi di trasmogrificazione e i cimeli che conosci già."
L["Treat non-appearance items as known"] = "Tratta gli oggetti senza aspetto come noti"
L["Necklaces, rings and trinkets will be marked as already known even though they technically cannot be learned. This prevents them from looking like uncollected items in the vendor."] = "Collane, anelli e monili verranno segnati come già noti anche se tecnicamente non possono essere appresi. Questo impedisce che appaiano come oggetti non collezionati dal venditore."
L["Already known for pets"] = "Già noto per le mascotte"
L["Grey out and mark battle pets that you have already collected."] = "Grigia e segna le mascotte da battaglia che hai già collezionato."
L["Already known for recipes"] = "Già noto per le ricette"
L["Grey out and mark recipes that you already know."] = "Grigia e segna le ricette che conosci già."

-- SpellIconOverlay Options
L["Spell Icon Overlay"] = "Sovrapposizione icona incantesimo"
L["Display an |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in the spellbook or action bars that are included in the single-button combat rotation. So you can identify them at a glance."] = "Mostra una sovrapposizione dell'icona |A:UI-RefreshButton:16:16:0:0|a sugli incantesimi nel libro degli incantesimi o nelle barre delle azioni inclusi nella rotazione di combattimento a pulsante singolo. Così puoi identificarli a colpo d'occhio."
L["Show in Spellbook"] = "Mostra nel libro degli incantesimi"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in your spellbook that are included in the single-button combat rotation."] = "Mostra la sovrapposizione dell'icona |A:UI-RefreshButton:16:16:0:0|a sugli incantesimi nel tuo libro degli incantesimi inclusi nella rotazione di combattimento a pulsante singolo."
L["Show on Action Bars"] = "Mostra sulle barre delle azioni"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bar buttons for spells included in the rotation."] = "Mostra la sovrapposizione dell'icona |A:UI-RefreshButton:16:16:0:0|a sui pulsanti della barra delle azioni per gli incantesimi inclusi nella rotazione."
L["Only when Single-Button is used"] = "Solo quando si usa il pulsante singolo"
L["Only show the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bars if the Single-Button Assistant spell is currently placed on an action bar."] = "Mostra la sovrapposizione dell'icona |A:UI-RefreshButton:16:16:0:0|a sulle barre delle azioni solo se l'incantesimo Assistente a pulsante singolo è attualmente posizionato su una barra delle azioni."

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "Fodero Persistente"
L["Automatically maintain your desired weapon sheath state."] = "Mantiene automaticamente lo stato di fodero dell'arma desiderato."
L["Restore sheathed"] = "Ripristina foderato"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "Ricorda se l'ultima volta avevi l'arma nel fodero e la rimette automaticamente nel fodero ogni volta che un'azione di gioco la estrae (ad esempio, dopo il combattimento)."
L["Restore unsheathed"] = "Ripristina estratto"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "Ricorda se l'ultima volta avevi l'arma estratta e la estrae automaticamente ogni volta che un'azione di gioco la rimette nel fodero (ad esempio, dopo aver lanciato incantesimi o interagito con PNG)."
L["Silent restoration"] = "Ripristino silenzioso"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "Silenzia gli effetti sonori di estrazione e fodero quando l'addon ripristina automaticamente lo stato dell'arma. I suoni dell'azione manuale non sono influenzati."

-- PersistentCompanion Options
L["Persistent Companion"] = "Compagno Persistente"
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals"] = "Rievoca automaticamente il tuo ultimo compagno mascotte attivo dopo che scompare. Ad esempio, dopo aver volato o attraversato portali."

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = "Benvenuto in LudiusPlus! Digita /ldp per scegliere i moduli da abilitare."
