local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "ptBR")
if not L then return end

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "Alternar Montar/Desmontar"
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both."] = "Atribui desmontar e remontar a uma única tecla, para que você possa alternar confortavelmente entre ambos."
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
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "Silencia sons específicos por seus IDs de arquivo de som.\n\nEncontre IDs no Wowhead (https://www.wowhead.com/sounds/) ou aprenda sobre outros métodos em https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExemplo: 598079, 598187 (sons de invocação do Escudeiro Zeloso)."
L["Sound IDs to mute (comma-separated)"] = "IDs de som para silenciar (separados por vírgula)"
L["Enter Sound File IDs separated by commas."] = "Insira IDs de arquivos de som separados por vírgulas."

-- DialogSkipper Options
L["Dialog Skipper"] = "Pular Diálogos"
L["Automatically skip confirmation dialogs"] = "Pula automaticamente diálogos de confirmação."
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
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals"] = "Reinvoca automaticamente seu último companheiro mascote ativo após ele desaparecer. Por exemplo, após voar ou passar por portais."

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = "Bem-vindo ao LudiusPlus! Digite /ldp para escolher os módulos a ativar."
