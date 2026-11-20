extends RefCounted
## Começo de jogo novo, como o original (fonte C, cliente: tela /create-character "CHOOSE YOUR STARTER POKÉMON" com
## "CHOOSE YOUR TRAINER" Boy/Girl e o nome; tutorial do Professor Oak; Pokepedia "Combat on the Hunt"; A: vídeo do usuário
## jogando o começo, referencia_visual/quadros/03_criar_personagem). Puro e determinístico.
##
##   - Inicial: Bulbasaur (1), Charmander (4) ou Squirtle (7) — C: `ck = {1: "Bulbasaur", 4: "Charmander", 7: "Squirtle"}`
##     e `STARTERS`; entra no nível 1 (C: `level: Math.max(1, e.level || 1)`). O Geodude como inicial (decisão do
##     ciclo 2) saiu no ciclo 4, a pedido do usuário: o começo é o do original.
##   - IV e Quality do inicial (C, chunk 0fllz2m_ktm3s.js `getParty`): o cliente sorteia com um gerador semeado pela string
##     `<nome do treinador>:<id do inicial>` (GameWorld chama getParty com `seed: trainerName`): hash da string → gerador
##     tipo mulberry32 → rollGrowthSet (6 × 1+floor(32·r)) → rollQuality (tabela de pesos). Porte exato em
##     `ivs_quality_do_inicial` (conferido contra o código original no Node: testes/test_jogo_novo.gd). Que o servidor
##     use a mesma semente é F: o vídeo não mostra IV/Quality do inicial (só o cliente mostra a prévia com ela).
##   - Kit: "Every new player starts with 100 Small Potions and 100 Poké Balls" (C, Pokepedia); o tutorial repete "You
##     started with 100 Small Potions as a gift!" (C).
##   - Ouro inicial: não aparece no cliente nem nas gravações → 0 (classe 3).
##   - Primeira cidade: Cerulean (C/A).
##   - Primeira hunt recomendada (C, tutorial `cy`): Bulbasaur → Geodude ("Rock/Ground — your grass attacks deal ×4"),
##     Charmander → Paras ("Bug/Grass — your fire attacks deal ×4"), Squirtle → Geodude (água ×4). As três são nível 1.
##   - Tutorial (C): os 17 passos do cliente, de welcome a done, com "Pular tutorial" (painel_tutorial.gd).
## As ferramentas de teste (campanha, jogabilidade) seguem com a linha do Geodude como política delas (INICIAL_CAMPANHA);
## o jogo não oferece mais o Geodude.

const Balanceamento := preload("res://sim/balanceamento.gd")
const Regras := preload("res://sim/regras.gd")
const Rng := preload("res://sim/rng.gd")

const INICIAIS := {1: {"nome": "Bulbasaur", "hunt": "geodude", "por_que": "Rock/Ground — seus golpes de planta dão ×4"},
	4: {"nome": "Charmander", "hunt": "paras", "por_que": "Bug/Grass — seus golpes de fogo dão ×4"},
	7: {"nome": "Squirtle", "hunt": "geodude", "por_que": "Rock/Ground — seus golpes de água dão ×4"}}
const INICIAL_CAMPANHA := 74   # só as ferramentas de teste (campanha/jogabilidade); o jogo não oferece
const CAMPANHA := {74: {"nome": "Geodude", "hunt": "rattata", "por_que": "Normal"}}
const MODO_ORIGINAL := "original"
const KIT := {"pocoes": {200: 100}, "bolas": {1: 100}}    # C
const OURO_INICIAL := 0
const CIDADE_INICIAL := "cerulean"                          # C/A
const PASSOS_TUTORIAL := ["welcome", "party", "menu", "walk", "nurse", "depot", "shop", "market", "openMap", "firstHunt",
	"hunting", "throwBall", "openInv", "usePotion", "captureMgmt", "replay", "done"]   # C: os 17 passos do cliente (cC), na ordem
const QUALIDADE_PESOS := [[0.8, 0.9, 5.0], [0.9, 1.0, 5.0], [1.0, 1.1, 34.03846], [1.1, 1.2, 20.0], [1.2, 1.3, 10.0],
	[1.3, 1.4, 10.0], [1.4, 1.5, 10.0], [1.5, 1.6, 5.0], [1.7, 1.8, 0.67308], [1.8, 1.8, 0.28846]]   # C: rollQuality


static func iniciais(_modo: String = "") -> Dictionary:
	return INICIAIS


static func _imul(a: int, b: int) -> int:
	## Math.imul: produto de 32 bits (resultado sem sinal em 0..2^32-1).
	a &= 0xFFFFFFFF
	b &= 0xFFFFFFFF
	var baixo := (a & 0xFFFF) * b
	var alto := ((a >> 16) * b) & 0xFFFF
	return (baixo + (alto << 16)) & 0xFFFFFFFF


static func _assinado(x: int) -> int:
	x &= 0xFFFFFFFF
	return x - 0x100000000 if x >= 0x80000000 else x


static func gerador_cliente(semente: String) -> Callable:
	## O gerador do cliente (C, getParty): hash da string → estado inicial → passos tipo mulberry32 em [0, 1).
	var o := (0x6a09e667 ^ semente.length()) & 0xFFFFFFFF
	for i in semente.length():
		o = _imul(o ^ semente.unicode_at(i), 0xcc9e2d51)
		o = ((o << 13) | (o >> 19)) & 0xFFFFFFFF
	o = _imul(o ^ (o >> 16), 0x85ebca6b)
	o = _imul(o ^ (o >> 13), 0xc2b2ae35)
	o = (o ^ (o >> 16)) & 0xFFFFFFFF
	var estado := [_assinado(o)]
	return func() -> float:
		var t: int = _assinado(int(estado[0]) + 0x6d2b79f5)
		estado[0] = t
		var tu := t & 0xFFFFFFFF
		var e := _imul(tu ^ (tu >> 15), 1 | tu)
		e = ((e + _imul(e ^ (e >> 7), 61 | e)) & 0xFFFFFFFF) ^ e
		e = (e ^ (e >> 14)) & 0xFFFFFFFF
		return float(e) / 4294967296.0


static func ivs_quality_do_inicial(nome_treinador: String, especie_id: int) -> Dictionary:
	## {ivs, quality} como o cliente (C): semente "<nome>:<id>", rollGrowthSet e depois rollQuality no mesmo gerador.
	var r := gerador_cliente("%s:%d" % [nome_treinador, especie_id])
	var ivs := {}
	for k in ["hp", "atk", "def", "spAtk", "spDef", "speed"]:
		ivs[k] = 1 + int(floor(32.0 * float(r.call())))
	var q := 1.0
	var x: float = 100.0 * float(r.call())
	for faixa in QUALIDADE_PESOS:
		if x < float(faixa[2]):
			if float(faixa[0]) == float(faixa[1]):
				q = float(faixa[0])
			else:
				q = floor((float(faixa[0]) + float(r.call()) * (float(faixa[1]) - float(faixa[0]))) * 1000.0) / 1000.0
			break
		x -= float(faixa[2])
	return {"ivs": ivs, "quality": q}


static func criar(especie_id: int, semente: int, nome: String = "Treinador", modo: String = "") -> Dictionary:
	## Estado inicial do jogador: {inicial {speciesId, nome, nivel, xp, ivs, quality}, pocoes, bolas, ouro, cidade,
	## hunt_recomendada, tutorial}. Fora de Bulbasaur/Charmander/Squirtle → erro (a campanha de teste usa modo "campanha").
	var lista: Dictionary = CAMPANHA if modo == "campanha" else INICIAIS
	if not lista.has(especie_id):
		return {"erro": "Inicial inválido: escolha Bulbasaur, Charmander ou Squirtle."}
	var ivs: Dictionary
	var q: float
	if modo == "campanha":
		var rng = Rng.new(semente * 2654435761 % 2147483647 + especie_id)
		ivs = Regras.sortear_ivs(rng)
		q = Regras.sortear_qualidade(rng)
	else:
		var iq := ivs_quality_do_inicial(nome, especie_id)
		ivs = iq["ivs"]
		q = float(iq["quality"])
	var i: Dictionary = lista[especie_id]
	return {"inicial": {"speciesId": especie_id, "nome": String(i["nome"]), "nivel": 1, "xp": Regras.xp_total_para_nivel(1),
		"ivs": ivs, "quality": q}, "pocoes": KIT["pocoes"].duplicate(), "bolas": KIT["bolas"].duplicate(), "ouro": int(Balanceamento.valor("jogo_novo", "ouro_inicial", OURO_INICIAL)),
		"cidade": CIDADE_INICIAL, "hunt_recomendada": String(i["hunt"]), "por_que": String(i["por_que"]), "treinador": nome,
		"tutorial": PASSOS_TUTORIAL.duplicate(), "modo": "campanha" if modo == "campanha" else MODO_ORIGINAL}
