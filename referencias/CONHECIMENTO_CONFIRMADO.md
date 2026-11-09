# Referência do original — caça de Geodude

Coleta fornecida em 05/11/2026. Fontes preservadas: loogs_original.txt, screenshots de timestamps, hunt_original.png, snippets do cliente extraído, grade field-init e catálogo creatures.json. Os horários visíveis nos prints são do recebimento no navegador; serverNow é o relógio do servidor. Não são intercambiáveis.

## Sequência correlacionada

| Recebimento field-kill | Slot | Razor Leaf amount | eff | XP treinador | XP Bulbasaur após evento | Captura |
|---|---:|---:|---:|---:|---:|---|
|16:51:33.986|11|2688|5.5|12|712226|falha|
|16:51:36.221|6|1250|5.5|12|712238|falha|
|16:51:39.586|13|1205|5.5|12|712250|sucesso às 16:51:39.627|

Cada derrota: base8 + VIP4, tanto treinador como Pokémon. Bônus streak/boost/event/gym/typeDay zero; mentor zero para Pokémon. Não comprova arredondamento do VIP para bases ímpares, aplicação de outros bônus nem distribuição entre vários membros. A coleta apresenta apenas um aliado, Bulbasaur36.

field-kill.totalXp: 714292,714304,714316; são valores distintos de poke-xp.xp. O XP do treinador não deve sobrescrever o XP individual. O contador local de XP de treinador começa em zero; não importa estes saldos da conta original e não presume a curva de nível da conta.

Super Ball 5767→5766→5765→5764, uma unidade por tentativa. Seleção manual permanece1, captura automática usa3: são configurações distintas. Uma captura bem-sucedida em três tentativas NÃO estima a probabilidade original. A captura continua provisória no protótipo.

Loot: primeira derrota Small Stone4/Earth Ball1; segunda Earth Ball2; terceira Small Stone3/Earth Ball3/Stone Orb1. Variações de inventário da segunda/terceira conferem. Os IDs são Small Stone120, Earth Ball39, Stone Orb126. Não confundir Earth Ball (loot) com uma Pokébola utilizável. Catálogo adicional preservado em itens_loot_original.json. Chancen e faixas brutas estão em dados/caca/geodude_recompensas_original.json; denominador e políticas de sorteio não comprovados. Não é correto transformar as três amostras numa tabela fixa ou inventar chance de drop.

Geodude capturado: id cmw3yq3mdfkgf12ih566etdtx, level1, XP0, HP24, Quality1.394, ivTotal76, stats1/2/2/1/1/1, power11, BOX (teamfalse). Não pertence ao time automaticamente. Geodudes selvagens deste field têm120HP, dado separado do capturado. Não extrapolar120HP para outras hunts ou espécies.

Ataques observados: Razor Leaf/GRASS, amount2688,1250,1205, sempre eff5.5. Valores excedem120HP do alvo e não são HP efetivamente retirado. Não provam crítico, distribuição aleatória ou fórmula de dano. HP aliado permaneceu345/348 nesta janela; ausência de dano líquido não demonstra invulnerabilidade. Bulbasaur snapshot anterior: stats29/18/18/31/31/31, Quality0.835, power132, maxHP348. Os stats não são os seis IVs (há apenas ivTotal98). Dano permanece o protótipo até obter a fórmula real.

Recompensa e impacto não têm ordem fixa entre mensagens: field28 contém hit do slot11 antes do field-kill; hits dos slots6 e13 aparecem em field46 e64 depois dos respectivos eventos. targetSlot já pode apontar o PRÓXIMO alvo; não atribuir hits ao targetSlot atual, usar hits.slot. Slots são reutilizados e precisam de identidade do encontro para evitar duplicação.

O txt contém71 objetos JSON válidos:20field,3field-kill,3poke-xp,3catch-result,3inventory,6balls,1poke-delta e outros controles. Badge-refresh não contém XP/dano/loot. Saltos em seq não bastam para provar omissão manual. Nenhuma conclusão depende de recuperar badge-refresh.

## Grade e movimento

field-init rows88 cols109 minTx-54 minTy-43. grid true indica célula livre. Coordenadas locais: x=minTx+col; y=minTy+row.757células livres,754conectadas ao ponto inicial pelo movimento local que não corta quinas. Três livres restantes estão desconectadas sob essa regra. Todos15spawns validados. Uso da grade não prova que a política diagonal original seja idêntica à local.

heroStepMs500, trainerStepMs500, mobStepMs1000, tickMs200. Com tiles32, passo reto500ms equivale64px/s. Não usar tick200ms como cooldown de golpe/poção/respawn. Colunas/linhas dos mobs mudam durante a coleta; os selvagens do original se movimentam, não ficam apenas virando. Limites de perseguição, ociosidade e escolha de alvo ainda não comprovados. O protótipo mantém os selvagens nos pontos fixos.

## Cartões recuperados do cliente

cF: janela agrupamento700ms, idade máxima do grupo1500ms, máximo12kills/grupo,3cartõesdesktop/2phone. Normal expira4500ms desde últimoevento, shiny7000ms; entrada260ms e saída220ms no original. Shiny não agrupa. Componentes trainer e poke acumulam suas próprias partes; loot acumula por itemId. Na janela648px desta implementação usam-se2cartões para reservar a captura. Fade e cores aproximam o cliente; sombras, radialgradients, partículas e números animados não são reproduzidos integralmente.

## Print da hunt original

Layout: HUD permanente no alto à esquerda com nick/nívelda conta e equipe; dock horizontalcentral; Auto-Helper altoàdireita; cartões de derrota àdireita; Capture embaixoàdireita; chat embaixoàesquerda; nomes/HP no mundo; treinador próximo do aliado. A viewport1900px do print não corresponde a1152px do protótipo: exige adaptação, não posições fixas copiadas. O desenho completo contém bordas externas vegetadas e múltiplos andares. Não copiar nick/estoques/XP/VIP do usuário da referência para o save local. O chat multiplayer, indicadores de boosts e Shop não têm backend local nesta etapa.
