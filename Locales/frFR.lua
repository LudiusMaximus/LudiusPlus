local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "frFR")
if not L then return end

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "Basculer Monter/Descendre"
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both. The addon will remember your last mount and re-mount it when you press the hotkey again."] = "Assigne le démontage et le remontage à une seule touche, pour que vous puissiez passer confortablement de l'un à l'autre. L'addon se souviendra de votre dernière monture et la réinvoquera lorsque vous appuierez à nouveau sur la touche."
L["Enable"] = "Activer"
L["Assigned Hotkey:"] = "Raccourci assigné :"
L["Not Bound"] = "Non assigné"
L["New Key Bind"] = "Nouveau raccourci"
L["Assign a new hotkey binding."] = "Assigne une nouvelle touche."
L["Unbind"] = "Effacer"
L["Unassign the current binding."] = "Supprime l'assignation actuelle."
L["When mounting, switch automatically to Action Bar:"] = "En montant, basculer vers la Barre d'action :"
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."] = "Bascule automatiquement vers cette barre d'action lorsque vous montez, pour que vos capacités de vol/monture soient facilement accessibles. Réglez sur « désactivé » pour conserver votre barre d'action actuelle."
L["Druid Travel Form instead of mounting"] = "Forme de voyage druide au lieu de monture"
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = "Druides uniquement : Utilise la Forme de voyage ou de vol comme « monter » et la forme Humanoïde comme « descendre », au lieu des montures standard."
L["Dracthyr Soar instead of mounting"] = "Dracthyr Envol au lieu de monture"
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = "Dracthyr uniquement : Utilise Envol comme « monter » et la forme Humanoïde comme « descendre », au lieu des montures standard."
L["Mounts to ignore (comma-separated Mount IDs)"] = "Montures à ignorer (ID séparés par des virgules)"
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"] = "Entrez les ID de montures à ignorer lors de la mémorisation de votre dernière monture. Utile pour les montures utilitaires comme le Yak ou le Brutosaure que vous utilisez temporairement mais ne voulez pas invoquer avec votre raccourci.\n\nTrouvez les ID de montures sur : https://www.wowhead.com/spells/mounts"
L["Fill in Utility Mounts"] = "Remplir Montures Utilitaires"
L["Adds commonly used utility mounts to the ignore list:"] = "Ajoute les montures utilitaires couramment utilisées à la liste d'ignorés :"
L["Auto-mount last non-ignored mount when on ignored mounts"] = "Monter automatiquement la dernière monture non-ignorée si sur une monture ignorée"
L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."] = "Si vous êtes sur une monture ignorée, le raccourci vous fera descendre et montera immédiatement la dernière monture non-ignorée. Désactivez pour seulement descendre."
L["Dismount/Mount Toggle module is disabled. Enable it in the addon options."] = "Le module Basculer Monter/Descendre est désactivé. Activez-le dans les options de l'addon."

-- RaceOnLastMount Options
L["Race on Last Mount"] = "Course sur la dernière monture"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = "Si vous démarrez une course de Vol dynamique sans être sur une monture, vous êtes normalement placé automatiquement sur le Proto-drake renouvelé. Cet addon bascule automatiquement sur votre dernière monture volante utilisée pendant le compte à rebours (après un délai de 2 secondes).\n\nNote : Le basculement automatique vers la Forme de vol druidique est impossible en raison des limitations de l'API."

-- Flashlight Options
L["Flashlight (Torch)"] = "Lampe de poche (Torche)"
L["Toggles the \"%s\" toy on and off with a hotkey."] = "Active et désactive le jouet « %s » avec un raccourci clavier."
L["Torch Toggle"] = "Basculer la torche"
L["Toy Missing:"] = "Jouet manquant :"
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = "Vous ne possédez pas le jouet « %s » !\nRécupérez-le dans la Cantine illuminée :\nhttps://www.wowhead.com/fr/object=437211/cantine-illumin%C3%A9e"
L["Flashlight module is disabled. Enable it in the addon options."] = "Le module Lampe torche est désactivé. Activez-le dans les options de l'addon."

-- MuteSounds Options
L["Mute Sounds"] = "Couper les sons"
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "Coupe des sons spécifiques par leurs ID de fichier son.\n\nTrouvez les ID sur Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) ou apprenez d'autres méthodes sur https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExemple : 598079, 598187 (sons d'invocation de l'Écuyer dévoué)."
L["Sound IDs to mute (comma-separated)"] = "ID de sons à couper (séparés par des virgules)"
L["Enter Sound File IDs separated by commas."] = "Entrez les ID de fichiers son séparés par des virgules."

-- DialogSkipper Options
L["Dialog Skipper"] = "Passeur de dialogue"
L["Automatically skip confirmation dialogs."] = "Passe automatiquement les dialogues de confirmation."
L["Skip auction house buyout confirmations"] = "Passer les confirmations d'achat immédiat à l'Hôtel des ventes"
L["Back to previous item list after buyout"] = "Retour à la liste précédente après l'achat"
L["After buying out an item, the addon automatically returns you to the previous item list overview. This is useful when you typically purchase one listing of an item and then want to go back to browse other items."] = "Après l'achat d'un objet, l'addon vous ramène automatiquement à la vue d'ensemble de la liste d'objets précédente. Ceci est utile lorsque vous achetez généralement une offre d'un objet puis voulez revenir parcourir d'autres objets."
L["Only skip if price is below (gold)"] = "Passer seulement si le prix est inférieur à (or)"
L["Set the maximum price in gold for automatically confirming auctions."] = "Définit le prix maximum en or pour confirmer automatiquement les enchères."
L["Skip Polished Pet Charm purchases"] = "Passer les achats avec Charmes pour mascotte polis"
L["Skip Order Resources purchases"] = "Passer les achats avec Ressources de domaine"
L["Skip equip bind confirmations"] = "Passer les confirmations « Lié quand équipé »"
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = "Confirme automatiquement les dialogues « Lié quand équipé » lors de l'équipement d'objets provenant de récompenses de quête, de vendeurs ou d'autres sources."

-- VendorItemOverlay Options
L["Vendor Item Overlay"] = "Superposition des articles du vendeur"
L["Display useful information as overlays for items at vendors."] = "Affiche des informations utiles en superposition pour les objets chez les vendeurs."
L["Ownership for decor items"] = "Possession des objets déco"
L["Display ownership information for housing decor items when visiting vendors. Shows the count as [in storage]/[total owned] in the top-right corner of each item icon."] = "Affiche les informations de possession pour les objets de décoration d'habitat chez les vendeurs. Le nombre est affiché sous la forme [en stockage]/[total possédé] dans le coin supérieur droit de chaque icône d'objet."
L["Already known for toys"] = "Déjà connu pour les jouets"
L["Grey out and mark toys that you already know."] = "Grise et marque les jouets que vous connaissez déjà."
L["Already known for mounts"] = "Déjà connu pour les montures"
L["Grey out and mark mounts that you already know."] = "Grise et marque les montures que vous connaissez déjà."
L["Already known for transmogs and heirlooms"] = "Déjà connu pour les transmogrifications et héritages"
L["Grey out and mark transmog items/ensembles and heirlooms that you already know."] = "Grise et marque les objets/ensembles de transmogrification et les héritages que vous connaissez déjà."
L["Treat non-appearance items as known"] = "Considérer les objets sans apparence comme connus"
L["Necklaces, rings and trinkets will be marked as already known even though they technically cannot be learned. This prevents them from looking like uncollected items in the vendor."] = "Les colliers, anneaux et bijoux seront marqués comme déjà connus même s'ils ne peuvent techniquement pas être appris. Cela évite qu'ils apparaissent comme des objets non collectés chez le vendeur."
L["Already known for pets"] = "Déjà connu pour les mascottes"
L["Grey out and mark battle pets that you have already collected."] = "Grise et marque les mascottes de combat que vous avez déjà collectées."
L["Already known for recipes"] = "Déjà connu pour les recettes"
L["Grey out and mark recipes that you already know."] = "Grise et marque les recettes que vous connaissez déjà."

-- SpellIconOverlay Options
L["Spell Icon Overlay"] = "Superposition d'icône de sort"
L["Display an |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in the spellbook or action bars that are included in the single-button combat rotation. So you can identify them at a glance."] = "Affiche une superposition d'icône |A:UI-RefreshButton:16:16:0:0|a sur les sorts du grimoire ou des barres d'action qui sont inclus dans la rotation de combat à bouton unique. Vous pouvez ainsi les identifier en un coup d'œil."
L["Show in Spellbook"] = "Afficher dans le grimoire"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in your spellbook that are included in the single-button combat rotation."] = "Affiche la superposition d'icône |A:UI-RefreshButton:16:16:0:0|a sur les sorts de votre grimoire qui sont inclus dans la rotation de combat à bouton unique."
L["Show on Action Bars"] = "Afficher sur les barres d'action"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bar buttons for spells included in the rotation."] = "Affiche la superposition d'icône |A:UI-RefreshButton:16:16:0:0|a sur les boutons de la barre d'action pour les sorts inclus dans la rotation."
L["Only when Single-Button is used"] = "Seulement si le bouton unique est utilisé"
L["Only show the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bars if the Single-Button Assistant spell is currently placed on an action bar."] = "Affiche la superposition d'icône |A:UI-RefreshButton:16:16:0:0|a sur les barres d'action uniquement si le sort Assistant à bouton unique est actuellement placé sur une barre d'action."

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "Dégainage persistant"
L["Automatically maintain your desired weapon sheath state."] = "Maintient automatiquement l'état rengainé/dégainé de votre arme."
L["Restore sheathed"] = "Restaurer rengainé"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "Se souvient si vous aviez rengainé votre arme et retourne automatiquement à l'état rengainé chaque fois qu'une action de jeu la dégaine (par exemple, après un combat)."
L["Restore unsheathed"] = "Restaurer dégainé"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "Se souvient si vous aviez dégainé votre arme et retourne automatiquement à l'état dégainé chaque fois qu'une action de jeu la rengaine (par exemple, après avoir incanté ou interagi avec des PNJ)."
L["Silent restoration"] = "Restauration silencieuse"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "Coupe les bruitages de dégainage et rengainage lorsque l'addon restaure automatiquement l'état de votre arme. Les sons de l'action manuelle ne sont pas affectés."

-- PersistentCompanion Options
L["Persistent Companion"] = "Compagnon persistant"
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals."] = "Rappelle automatiquement votre dernier compagnon mascotte actif après sa disparition. Par exemple, après avoir volé ou traversé des portails."
L["Dismiss pet while stealthed"] = "Renvoyer la mascotte en camouflage"
L["Automatically dismiss your pet when entering stealth and resummon it when leaving stealth."] = "Renvoie automatiquement votre mascotte lorsque vous entrez en camouflage et la rappelle lorsque vous en sortez."
L["Dismiss pet in combat"] = "Renvoyer la mascotte en combat"
L["Automatically dismiss your pet when entering combat and resummon it when combat ends."] = "Renvoie automatiquement votre mascotte lorsque vous entrez en combat et la rappelle lorsque le combat se termine."
L["Mute automatic summon sound"] = "Couper le son d'invocation automatique"
L["Mute the pet summon sound when automatically resummoning your pet. The sound from manual summoning is not affected.\n\nThis works for most pets (the ones using the \"huntertrapopen\" sound). Feel free to let the addon author know the IDs of other pet summing sounds to be added."] = "Coupe le son d'invocation de la mascotte lors de son rappel automatique. Le son de l'invocation manuelle n'est pas affecté.\n\nCela fonctionne pour la plupart des mascottes (celles utilisant le son « huntertrapopen »). N'hésitez pas à communiquer à l'auteur de l'addon les ID d'autres sons d'invocation de mascottes à ajouter."

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = "Bienvenue dans LudiusPlus ! Tapez /ldp pour choisir les modules à activer."
