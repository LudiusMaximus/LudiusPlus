local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "ptBR")
if not L then return end

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "Alternar Montar/Desmontar"
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both. The addon will remember your last mount and re-mount it when you press the hotkey again."] = "Atribui desmontar e remontar a uma única tecla, para que você possa alternar confortavelmente entre ambos. O addon lembrará sua última montaria e a invocará novamente quando você pressionar a tecla de atalho."
L["Enable"] = "Habilitar"
L["Assigned Hotkey:"] = "Tecla de Atalho:"
L["Not Bound"] = "Não Vinculado"
L["New Key Bind"] = "Nova Vinculação"
L["Assign a new hotkey binding."] = "Atribui uma nova tecla."
L["Unbind"] = "Remover"
L["Unassign the current binding."] = "Remove a vinculação atual."
L["When mounting, switch automatically to Action Bar:"] = "Ao montar, mudar automaticamente para a Barra de Ações:"
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."] = "Muda automaticamente para esta barra de ações quando você monta, para que suas habilidades de voo/montaria fiquem acessíveis. Defina como \"desativado\" para manter sua barra atual."
L["Druid Travel Form instead of mounting"] = "Forma de Viagem de Druida em vez de montaria"
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = "Apenas Druidas: Usa Forma de Viagem ou de Voo como \"montar\", e forma Humanoide como \"desmontar\", em vez de montarias padrão."
L["Dracthyr Soar instead of mounting"] = "Dracthyr Voar Alto em vez de montaria"
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = "Apenas Dracthyr: Usa Voar Alto como \"montar\" e forma Humanoide como \"desmontar\", em vez de montarias padrão."
L["Mounts to ignore (comma-separated Mount IDs)"] = "Montarias a ignorar (IDs separados por vírgula)"
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"] = "Insira IDs de montarias para ignorar ao armazenar sua última montaria. Útil para montarias utilitárias como Iaque ou Brutossauro que você usa temporariamente, mas não quer invocar com seu atalho.\n\nEncontre IDs de montarias em: https://www.wowhead.com/spells/mounts"
L["Fill in Utility Mounts"] = "Preencher Montarias Utilitárias"
L["Adds commonly used utility mounts to the ignore list:"] = "Adiciona montarias utilitárias comumente usadas à lista de ignorados:"
L["Auto-mount last non-ignored mount when on ignored mounts"] = "Montar automaticamente última não ignorada se em montaria ignorada"
L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."] = "Enquanto estiver em uma montaria ignorada, o atalho desmontará e montará imediatamente a última montaria não ignorada. Desative para apenas desmontar."
L["Dismount/Mount Toggle module is disabled. Enable it in the addon options."] = "O módulo Alternar Montar/Desmontar está desativado. Ative-o nas opções do addon."

-- RaceOnLastMount Options
L["Race on Last Mount"] = "Corrida na Última Montaria"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = "Se você iniciar uma corrida de Pilotagem Aérea sem estar montado, normalmente será colocado automaticamente no Protodraco Renovado. Este addon muda automaticamente para sua última montaria voadora usada durante a contagem regressiva (após um atraso de 2 segundos).\n\nNota: A mudança automática para a Forma de Voo de Druida não é possível devido a limitações da API."

-- Flashlight Options
L["Flashlight (Torch)"] = "Lanterna (Tocha)"
L["Toggles the \"%s\" toy on and off with a hotkey."] = "Alterna o brinquedo \"%s\" ligado e desligado com uma tecla de atalho."
L["Torch Toggle"] = "Alternar Tocha"
L["Toy Missing:"] = "Brinquedo Ausente:"
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = "Você não tem o brinquedo \"%s\"!\nPegue-o na Maleta Iluminada:\nhttps://www.wowhead.com/pt/object=437211/maleta-iluminada"
L["Flashlight module is disabled. Enable it in the addon options."] = "O módulo Lanterna está desativado. Ative-o nas opções do addon."

-- MuteSounds Options
L["Mute Sounds"] = "Silenciar Sons"
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "Silencia sons específicos por seus IDs de arquivo de som.\n\nEncontre IDs no Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) ou aprenda sobre outros métodos em https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExemplo: 598079, 598187 (sons de invocação do Escudeiro Zeloso)."
L["Sound IDs to mute (comma-separated)"] = "IDs de som para silenciar (separados por vírgula)"
L["Enter Sound File IDs separated by commas."] = "Insira IDs de arquivos de som separados por vírgulas."

-- DialogSkipper Options
L["Dialog Skipper"] = "Pular Diálogos"
L["Automatically skip confirmation dialogs."] = "Pula automaticamente diálogos de confirmação."
L["Skip auction house buyout confirmations"] = "Pular confirmações de compra na Casa de Leilões"
L["Back to previous item list after buyout"] = "Voltar à lista anterior após compra"
L["After buying out an item, the addon automatically returns you to the previous item list overview. This is useful when you typically purchase one listing of an item and then want to go back to browse other items."] = "Após comprar um item, o addon retorna automaticamente à visão geral da lista de itens anterior. Isso é útil quando você normalmente compra uma listagem de um item e depois quer voltar para explorar outros itens."
L["Only skip if price is below (gold)"] = "Pular apenas se o preço for inferior a (ouro)"
L["Set the maximum price in gold for automatically confirming auctions."] = "Define o preço máximo em ouro para confirmar leilões automaticamente."
L["Skip Polished Pet Charm purchases"] = "Pular compras com Patuás de Mascote Polidos"
L["Skip Order Resources purchases"] = "Pular compras com Recursos da Ordem"
L["Skip equip bind confirmations"] = "Pular confirmações de vincular ao equipar"
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = "Confirma automaticamente diálogos de \"Vinculado ao Equipar\" ao equipar itens de recompensas de missão, vendedores ou outras fontes."

-- VendorItemOverlay Options
L["Vendor Item Overlay"] = "Sobreposição de itens do vendedor"
L["Display useful information as overlays for items at vendors."] = "Exibe informações úteis como sobreposições para itens em vendedores."
L["Ownership for decor items"] = "Propriedade de itens decorativos"
L["Display ownership information for housing decor items when visiting vendors. Shows the count as [in storage]/[total owned] in the top-right corner of each item icon."] = "Exibe informações de propriedade para itens de decoração de moradia ao visitar vendedores. Mostra a contagem como [em armazenamento]/[total possuído] no canto superior direito de cada ícone de item."
L["Already known for toys"] = "Já conhecido para brinquedos"
L["Grey out and mark toys that you already know."] = "Acinenta e marca brinquedos que você já conhece."
L["Already known for mounts"] = "Já conhecido para montarias"
L["Grey out and mark mounts that you already know."] = "Acinenta e marca montarias que você já conhece."
L["Already known for transmogs and heirlooms"] = "Já conhecido para transmogrificações e heranças"
L["Grey out and mark transmog items/ensembles and heirlooms that you already know."] = "Acinenta e marca itens/conjuntos de transmogrificação e heranças que você já conhece."
L["Treat non-appearance items as known"] = "Tratar itens sem aparência como conhecidos"
L["Necklaces, rings and trinkets will be marked as already known even though they technically cannot be learned. This prevents them from looking like uncollected items in the vendor."] = "Colares, anéis e berloques serão marcados como já conhecidos, embora tecnicamente não possam ser aprendidos. Isso evita que pareçam itens não coletados no vendedor."
L["Already known for pets"] = "Já conhecido para mascotes"
L["Grey out and mark battle pets that you have already collected."] = "Acinenta e marca mascotes de batalha que você já coletou."
L["Already known for recipes"] = "Já conhecido para receitas"
L["Grey out and mark recipes that you already know."] = "Acinenta e marca receitas que você já conhece."

    -- SpellIconOverlay Options
L["Spell Icon Overlay"] = "Sobreposição de ícone de feitiço"
L["Display an |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in the spellbook or action bars that are included in the single-button combat rotation. So you can identify them at a glance."] = "Exibe uma sobreposição de ícone |A:UI-RefreshButton:16:16:0:0|a em feitiços no grimório ou barras de ação que estão incluídos na rotação de combate de botão único. Assim você pode identificá-los rapidamente."
L["Show in Spellbook"] = "Mostrar no grimório"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in your spellbook that are included in the single-button combat rotation."] = "Exibe a sobreposição de ícone |A:UI-RefreshButton:16:16:0:0|a em feitiços no seu grimório que estão incluídos na rotação de combate de botão único."
L["Show on Action Bars"] = "Mostrar nas barras de ação"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bar buttons for spells included in the rotation."] = "Exibe a sobreposição de ícone |A:UI-RefreshButton:16:16:0:0|a nos botões da barra de ação para feitiços incluídos na rotação."
L["Only when Single-Button is used"] = "Apenas quando o botão único é usado"
L["Only show the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bars if the Single-Button Assistant spell is currently placed on an action bar."] = "Exibe a sobreposição de ícone |A:UI-RefreshButton:16:16:0:0|a nas barras de ação apenas se o feitiço Assistente de Botão Único estiver atualmente colocado em uma barra de ação."

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "Bainha Persistente"
L["Automatically maintain your desired weapon sheath state."] = "Mantém automaticamente o estado desejado da bainha da arma."
L["Restore sheathed"] = "Restaurar embainhado"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "Lembra se você embainhou a arma por último e retorna automaticamente ao estado embainhado sempre que uma ação do jogo a desembainhar (por exemplo, após o combate)."
L["Restore unsheathed"] = "Restaurar desembainhado"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "Lembra se você desembainhou a arma por último e retorna automaticamente ao estado desembainhado sempre que uma ação do jogo a embainhar (por exemplo, após lançar feitiços ou interagir com NPCs)."
L["Silent restoration"] = "Restauração silenciosa"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "Silencia os efeitos sonoros de embainhar e desembainhar quando o addon restaura automaticamente o estado da sua arma. Os sons da alternância manual não são afetados."

-- PersistentCompanion Options
L["Persistent Companion"] = "Companheiro Persistente"
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals."] = "Reinvoca automaticamente seu último companheiro mascote ativo após ele desaparecer. Por exemplo, após voar ou passar por portais."
L["Dismiss pet while stealthed"] = "Dispensar mascote em furtividade"
L["Automatically dismiss your pet when entering stealth and resummon it when leaving stealth."] = "Dispensa automaticamente seu mascote ao entrar em furtividade e o invoca novamente ao sair."
L["Dismiss pet in combat"] = "Dispensar mascote em combate"
L["Automatically dismiss your pet when entering combat and resummon it when combat ends."] = "Dispensa automaticamente seu mascote ao entrar em combate e o invoca novamente quando o combate termina."
L["Mute automatic summon sound"] = "Silenciar som de invocação automática"
L["Mute the pet summon sound when automatically resummoning your pet. The sound from manual summoning is not affected.\n\nThis works for most pets (the ones using the \"huntertrapopen\" sound). Feel free to let the addon author know the IDs of other pet summing sounds to be added."] = "Silencia o som de invocação do mascote ao reinvocá-lo automaticamente. O som da invocação manual não é afetado.\n\nIsso funciona para a maioria dos mascotes (aqueles que usam o som \"huntertrapopen\"). Sinta-se à vontade para informar ao autor do addon os IDs de outros sons de invocação de mascotes a serem adicionados."

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = "Bem-vindo ao LudiusPlus! Digite /ldp para escolher os módulos a ativar."

-- Dangerous Scripts Warning
L["To use certain features (like Dismount Toggle and Flashlight), LudiusPlus needs your permission to run macros.\n\nPlease click \"Allow Scripts\" below, then \"Yes\" in the game's confirmation pop-up to enable these modules."] = "Para usar certas funcionalidades (como Alternar Montar/Desmontar e Lanterna), LudiusPlus precisa de sua permissão para executar macros.\n\nPor favor, clique em \"Permitir Scripts\" abaixo, depois em \"Sim\" na confirmação do jogo para habilitar esses módulos."
L["Allow Scripts"] = "Permitir Scripts"
