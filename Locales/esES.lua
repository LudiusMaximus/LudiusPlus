local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "esES")
if not L then return end

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "Alternar Montar/Desmontar"
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both. The addon will remember your last mount and re-mount it when you press the hotkey again."] = "Asigna desmontar y volver a montar a una sola tecla, para que puedas cambiar cómodamente entre ambos. El addon recordará tu última montura y la volverá a invocar cuando presiones la tecla de nuevo."
L["Enable"] = "Habilitar"
L["Assigned Hotkey:"] = "Tecla asignada:"
L["Not Bound"] = "Sin asignar"
L["New Key Bind"] = "Nueva asignación"
L["Assign a new hotkey binding."] = "Asigna una nueva tecla."
L["Unbind"] = "Borrar"
L["Unassign the current binding."] = "Elimina la asignación actual."
L["When mounting, switch automatically to Action Bar:"] = "Al montar, cambiar a la Barra de acción:"
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."] = "Cambia automáticamente a esta barra de acción cuando montas, para tener tus habilidades de vuelo/montura accesibles. Establecer en «desactivado» para mantener tu barra de acción actual."
L["Druid Travel Form instead of mounting"] = "Forma de viaje de druida en lugar de montura"
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = "Solo druidas: Usa Forma de viaje o Forma de vuelo como «montar», y forma humanoide como «desmontar», en lugar de monturas estándar."
L["Dracthyr Soar instead of mounting"] = "Dracthyr Remontar en lugar de montura"
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = "Solo Dracthyr: Usa Remontar como «montar» y forma humanoide como «desmontar», en lugar de monturas estándar."
L["Mounts to ignore (comma-separated Mount IDs)"] = "Monturas a ignorar (IDs separados por comas)"
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"] = "Introduce IDs de monturas a ignorar al guardar tu última montura. Útil para monturas de utilidad como Yak o Brutosaurio que usas temporalmente pero no quieres invocar con tu tecla rápida.\n\nEncuentra IDs de monturas en: https://www.wowhead.com/spells/mounts"
L["Fill in Utility Mounts"] = "Rellenar Monturas de Utilidad"
L["Adds commonly used utility mounts to the ignore list:"] = "Añade monturas de utilidad comúnmente usadas a la lista de ignorados:"
L["Auto-mount last non-ignored mount when on ignored mounts"] = "Montar automáticamente última montura no ignorada si estás en montura ignorada"
L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."] = "Mientras estás en una montura ignorada, la tecla te desmontará e invocará inmediatamente la última montura no ignorada. Desactívalo para solo desmontar."
L["Dismount/Mount Toggle module is disabled. Enable it in the addon options."] = "El módulo Alternar Montar/Desmontar está desactivado. Actívalo en las opciones del addon."

-- RaceOnLastMount Options
L["Race on Last Mount"] = "Carrera en la última montura"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = "Si inicias una carrera de Surcacielos sin estar en una montura, normalmente se te coloca automáticamente en el Protodraco renovado. Este addon cambia automáticamente a tu última montura voladora utilizada durante la cuenta atrás (tras 2 segundos de retraso).\n\nNota: No es posible cambiar automáticamente a la Forma de vuelo de druida debido a limitaciones de la API."

-- Flashlight Options
L["Flashlight (Torch)"] = "Linterna (Antorcha)"
L["Toggles the \"%s\" toy on and off with a hotkey."] = "Activa y desactiva el juguete «%s» con una tecla de acceso rápido."
L["Torch Toggle"] = "Alternar antorcha"
L["Toy Missing:"] = "Falta el juguete:"
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = "¡No tienes el juguete «%s»!\nConsíguelo del Baúl iluminado:\nhttps://www.wowhead.com/es/object=437211/ba%C3%BAl-iluminado"
L["Flashlight module is disabled. Enable it in the addon options."] = "El módulo Linterna está desactivado. Actívalo en las opciones del addon."

-- MuteSounds Options
L["Mute Sounds"] = "Silenciar sonidos"
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "Silencia sonidos específicos por sus ID de archivo de sonido.\n\nEncuentra ID en Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) o aprende sobre otros métodos en https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nEjemplo: 598079, 598187 (sonidos de invocación del Escudero hacendoso)."
L["Sound IDs to mute (comma-separated)"] = "IDs de sonido a silenciar (separados por comas)"
L["Enter Sound File IDs separated by commas."] = "Introduce los IDs de archivo de sonido separados por comas."

-- DialogSkipper Options
L["Dialog Skipper"] = "Omitir Diálogos"
L["Automatically skip confirmation dialogs."] = "Omite automáticamente los diálogos de confirmación."
L["Skip auction house buyout confirmations"] = "Omitir confirmaciones de compra en subasta"
L["Back to previous item list after buyout"] = "Volver a la lista anterior después de la compra"
L["After buying out an item, the addon automatically returns you to the previous item list overview. This is useful when you typically purchase one listing of an item and then want to go back to browse other items."] = "Después de comprar un artículo, el addon te devuelve automáticamente a la vista general de la lista de artículos anterior. Esto es útil cuando normalmente compras una oferta de un artículo y luego quieres volver para explorar otros artículos."
L["Only skip if price is below (gold)"] = "Solo omitir si el precio es inferior a (oro)"
L["Set the maximum price in gold for automatically confirming auctions."] = "Establece el precio máximo en oro para confirmar subastas automáticamente."
L["Skip Polished Pet Charm purchases"] = "Omitir compras con Talismanes de mascotas pulidos"
L["Skip Order Resources purchases"] = "Omitir compras con Recursos de la sede"
L["Skip equip bind confirmations"] = "Omitir confirmaciones de «Se liga al equiparlo»"
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = "Confirma automáticamente los diálogos de «Se liga al equiparlo» al equipar objetos de recompensas de misión, vendedores u otras fuentes."

-- VendorItemOverlay Options
L["Vendor Item Overlay"] = "Superposición de artículos del vendedor"
L["Display useful information as overlays for items at vendors."] = "Muestra información útil como superposiciones para artículos en vendedores."
L["Ownership for decor items"] = "Propiedad de artículos decorativos"
L["Display ownership information for housing decor items when visiting vendors. Shows the count as [in storage]/[total owned] in the top-right corner of each item icon."] = "Muestra información de propiedad de artículos de decoración de vivienda en vendedores. Muestra la cuenta como [en almacén]/[total poseído] en la esquina superior derecha de cada icono de artículo."
L["Already known for toys"] = "Ya conocido para juguetes"
L["Grey out and mark toys that you already know."] = "Atenúa y marca los juguetes que ya conoces."
L["Already known for mounts"] = "Ya conocido para monturas"
L["Grey out and mark mounts that you already know."] = "Atenúa y marca las monturas que ya conoces."
L["Already known for transmogs and heirlooms"] = "Ya conocido para transfiguraciones y reliquias"
L["Grey out and mark transmog items/ensembles and heirlooms that you already know."] = "Atenúa y marca los objetos/conjuntos de transfiguración y reliquias que ya conoces."
L["Treat non-appearance items as known"] = "Tratar objetos sin apariencia como conocidos"
L["Necklaces, rings and trinkets will be marked as already known even though they technically cannot be learned. This prevents them from looking like uncollected items in the vendor."] = "Los collares, anillos y abalorios se marcarán como ya conocidos aunque técnicamente no se puedan aprender. Esto evita que parezcan objetos no coleccionados en el vendedor."
L["Already known for pets"] = "Ya conocido para mascotas"
L["Grey out and mark battle pets that you have already collected."] = "Atenúa y marca las mascotas de duelo que ya has coleccionado."
L["Already known for recipes"] = "Ya conocido para recetas"
L["Grey out and mark recipes that you already know."] = "Atenúa y marca las recetas que ya conoces."

-- SpellIconOverlay Options
L["Spell Icon Overlay"] = "Superposición de icono de hechizo"
L["Display an |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in the spellbook or action bars that are included in the single-button combat rotation. So you can identify them at a glance."] = "Muestra una superposición de icono |A:UI-RefreshButton:16:16:0:0|a en los hechizos del libro de hechizos o barras de acción que están incluidos en la rotación de combate de un solo botón. Para que puedas identificarlos de un vistazo."
L["Show in Spellbook"] = "Mostrar en el libro de hechizos"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in your spellbook that are included in the single-button combat rotation."] = "Muestra la superposición de icono |A:UI-RefreshButton:16:16:0:0|a en los hechizos de tu libro de hechizos que están incluidos en la rotación de combate de un solo botón."
L["Show on Action Bars"] = "Mostrar en barras de acción"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bar buttons for spells included in the rotation."] = "Muestra la superposición de icono |A:UI-RefreshButton:16:16:0:0|a en los botones de la barra de acción para los hechizos incluidos en la rotación."
L["Only when Single-Button is used"] = "Solo cuando se usa un solo botón"
L["Only show the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bars if the Single-Button Assistant spell is currently placed on an action bar."] = "Solo muestra la superposición de icono |A:UI-RefreshButton:16:16:0:0|a en las barras de acción si el hechizo Asistente de un solo botón está colocado actualmente en una barra de acción."

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "Envainado persistente"
L["Automatically maintain your desired weapon sheath state."] = "Mantiene automáticamente el estado de envainado de arma deseado."
L["Restore sheathed"] = "Restaurar envainado"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "Recuerda si tu última acción fue envainar y vuelve automáticamente al estado envainado siempre que una acción del juego desenvaine el arma (por ejemplo, después del combate)."
L["Restore unsheathed"] = "Restaurar desenvainado"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "Recuerda si tu última acción fue desenvainar y vuelve automáticamente al estado desenvainado siempre que una acción del juego envaine el arma (por ejemplo, después de lanzar hechizos o interactuar con PNJs)."
L["Silent restoration"] = "Restauración silenciosa"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "Silencia los efectos de sonido de envainar y desenvainar cuando el addon restaura automáticamente el estado de tu arma. Los sonidos de la acción manual no se ven afectados."

-- PersistentCompanion Options
L["Persistent Companion"] = "Compañero persistente"
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals."] = "Vuelve a invocar automáticamente a tu último compañero de mascota activo después de que desaparezca. Por ejemplo, después de volar o cruzar portales."
L["Dismiss pet while stealthed"] = "Despedir mascota en sigilo"
L["Automatically dismiss your pet when entering stealth and resummon it when leaving stealth."] = "Despide automáticamente a tu mascota al entrar en sigilo y la vuelve a invocar al salir."
L["Dismiss pet in combat"] = "Despedir mascota en combate"
L["Automatically dismiss your pet when entering combat and resummon it when combat ends."] = "Despide automáticamente a tu mascota al entrar en combate y la vuelve a invocar cuando termina el combate."
L["Mute automatic summon sound"] = "Silenciar sonido de invocación automática"
L["Mute the pet summon sound when automatically resummoning your pet. The sound from manual summoning is not affected.\n\nThis works for most pets (the ones using the \"huntertrapopen\" sound). Feel free to let the addon author know the IDs of other pet summing sounds to be added."] = "Silencia el sonido de invocación de mascota cuando se vuelve a invocar automáticamente. El sonido de la invocación manual no se ve afectado.\n\nEsto funciona para la mayoría de las mascotas (las que usan el sonido \"huntertrapopen\"). No dudes en informar al autor del addon sobre los ID de otros sonidos de invocación de mascotas para agregarlos."

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = "¡Bienvenido a LudiusPlus! Escribe /ldp para elegir los módulos a activar."
