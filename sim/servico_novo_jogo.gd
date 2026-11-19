extends RefCounted
## Começo de jogo novo, como o original (fonte C, cliente: tela "CHOOSE YOUR STARTER POKÉMON", tutorial do Professor Oak e
## a Pokepedia "Combat on the Hunt"). Puro e determinístico (semente no comando).
##
##   - Inicial: Bulbasaur (1), Charmander (4) ou Squirtle (7) — C: `ck = {1: "Bulbasaur", 4: "Charmander", 7: "Squirtle"}`
##     e as bases/tipos dos três no chunk 0fllz2m_ktm3s.js; entra no nível 1 (C: `level: Math.max(1, e.level || 1)`).
##   - IV e Quality do inicial: o cliente sorteia com semente `starter-<id>` só na prévia; o do personagem vem do servidor
##     (não gravado). E: IV 1..32 por stat e Quality pelos pesos do cliente (Regras.sortear_qualidade), com a semente do jogo.
##   - Kit: "Every new player starts with 100 Small Potions and 100 Poké Balls" (C, Pokepedia); o tutorial repete "You
##     started with 100 Small Potions as a gift!" (C).
##   - Ouro inicial: não aparece no cliente nem nas gravações → 0 (E, decisão já registrada).
##   - Primeira cidade: Cerulean (C: o botão "Back to Cerulean" é a casa; A: o jogo grava `set-city` cerulean).
##   - Primeira hunt recomendada (C, tutorial `cy`): Bulbasaur → Geodude ("Rock/Ground — your grass attacks deal ×4"),
##     Charmander → Paras ("Bug/Grass — your fire attacks deal ×4"), Squirtle → Geodude (água ×4). As três são nível 1.
##   - **Inicial do projeto (E, 18/11, decisão do usuário): Geodude (74) no nível 1.** É o padrão do jogo novo; os três do
##     original ficam como opção (`MODO_ORIGINAL`, caixa "Iniciais do original" na tela de jogo novo). Primeira hunt do
##     Geodude: Rattata (A: a gravação geodude-10min é um Geodude Lv.1 upando na hunt `rattata`; Tackle neutro no Rattata
##     Normal, e o Tackle do Rattata é resistido pela Rocha). Mesmo kit e mesmo ouro dos outros.
##   - Tutorial (C): welcome, party, menu, walk, nurse, depot, shop, market, openMap, firstHunt, hunting, throwBall, …,
##     replay, done; "Skip tutorial". Aqui só a lista de passos (o roteiro na tela é E: ainda não feito).

const Balanceamento := preload("res://sim/balanceamento.gd")
const Regras := preload("res://sim/regras.gd")
const Rng := preload("res://sim/rng.gd")

const INICIAIS := {1: {"nome": "Bulbasaur", "hunt": "geodude", "por_que": "Rock/Ground — seus golpes de planta dão ×4"},
	4: {"nome": "Charmander", "hunt": "paras", "por_que": "Bug/Grass — seus golpes de fogo dão ×4"},
	7: {"nome": "Squirtle", "hunt": "geodude", "por_que": "Rock/Ground — seus golpes de água dão ×4"}}
const INICIAL_PROJETO := 74                                 # E (decisão do usuário, 18/11)
const INICIAIS_PROJETO := {74: {"nome": "Geodude", "hunt": "rattata", "por_que": "Normal — o Tackle acerta cheio e o Tackle dele é resistido pela sua Rocha"}}
const MODO_PROJETO := "projeto"    # E: só o Geodude
const MODO_ORIGINAL := "original"  # C: Bulbasaur, Charmander, Squirtle
const KIT := {"pocoes": {200: 100}, "bolas": {1: 100}}    # C
const OURO_INICIAL := 0                                     # E
const CIDADE_INICIAL := "cerulean"                          # C/A
const PASSOS_TUTORIAL := ["welcome", "party", "menu", "walk", "nurse", "depot", "shop", "market", "openMap", "firstHunt",
	"hunting", "throwBall", "captureMgmt", "openInv", "replay", "done"]   # C (ordem do cliente; os do fim, aproximada)


static func iniciais(modo: String) -> Dictionary:
	return INICIAIS if modo == MODO_ORIGINAL else INICIAIS_PROJETO


static func criar(especie_id: int, semente: int, nome: String = "Treinador", modo: String = MODO_PROJETO) -> Dictionary:
	## Estado inicial do jogador: {inicial {speciesId, nome, nivel, xp, ivs, quality}, pocoes, bolas, ouro, cidade,
	## hunt_recomendada, tutorial, modo}. Espécie fora das do modo → erro.
	var lista := iniciais(modo)
	if not lista.has(especie_id):
		return {"erro": "Inicial inválido: escolha Bulbasaur, Charmander ou Squirtle." if modo == MODO_ORIGINAL else "Inicial inválido: o jogo começa com o Geodude."}
	var rng = Rng.new(semente * 2654435761 % 2147483647 + especie_id)
	var ivs: Dictionary = Regras.sortear_ivs(rng)   # C: rollGrowthSet (IV 1..32)
	var q: float = Regras.sortear_qualidade(rng)
	var i: Dictionary = lista[especie_id]
	return {"inicial": {"speciesId": especie_id, "nome": String(i["nome"]), "nivel": 1, "xp": Regras.xp_total_para_nivel(1),
		"ivs": ivs, "quality": q}, "pocoes": KIT["pocoes"].duplicate(), "bolas": KIT["bolas"].duplicate(), "ouro": int(Balanceamento.valor("jogo_novo", "ouro_inicial", OURO_INICIAL)),
		"cidade": CIDADE_INICIAL, "hunt_recomendada": String(i["hunt"]), "por_que": String(i["por_que"]), "treinador": nome,
		"tutorial": PASSOS_TUTORIAL.duplicate(), "modo": modo}
