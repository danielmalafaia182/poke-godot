extends RefCounted
## Profissões (ciclo 6, backlog). Puro e determinístico; tratar(estado, cmd) → mensagens, como os outros serviços.
##
## Do cliente (C, textos window.professions.*): Botânico (colhe Fresh Herbs nas hunts e cria berries; "Toque de
## Herbalista": as berries rendem mais a cada rank), Treinador de Prestígio (foto automática de shiny → Rare Pokémon
## Picture, o item de subir de rank), Cientista e Pesquisador "em breve"; ranks E, D, C, B, A, S; bônus de captura direta
## +N% por rank, cumulativo desde o E, até ×1,18 no S (→ +3% por rank); requisitos de rank: derrotar Pokémon de cada
## tipagem (N por tipo), espécies diferentes capturadas, berries craftadas (Botânico) ou pictures entregues (Prestígio);
## o rank de cada carreira fica salvo ao trocar.
## Medido (A, gravações livres da conta B): parcela `mentor` do Pokémon = 0,5% da base por nível de diferença acima de 200
## (treinador − Pokémon), teto 60% (212 → 6%, 222 → 11%, 252 → 26%, 262 → 31%, ≥ 320 → 60%; 189 e 193 → 0).
## Classe 3 (balanceamento.json "profissoes"): requisitos por rank, teto do mentor por rank, chance das ervas e da foto,
## receita das berries, bônus das berries por rank. Trocar é grátis offline (E: não há diamantes).
##
## Estado: profissao {atual, ranks {prof: "E"…}, abates_tipo {TIPO: n}, berries_craftadas, pictures_entregues}.
## Comandos: prof-get, prof-escolher {prof}, prof-subir, prof-craft {tipo} (Botânico: ervas → berry do tipo).

const Regras := preload("res://sim/regras.gd")
const Balanceamento := preload("res://sim/balanceamento.gd")
const RANKS := ["E", "D", "C", "B", "A", "S"]
const ATIVAS := ["botanist", "prestige"]       # C: as outras duas estão "em breve"
const HERB_ID := 0                               # Fresh Herbs não está no catálogo: contado no estado da profissão
const PICTURE := "Rare Pokémon Picture"

var p := {
	"captura_pct_rank": 3.0,     # C: até ×1,18 no S, cumulativo desde o E
	"mentor_gap": 200,           # A
	"mentor_pct_nivel": 0.5,     # A
	"mentor_teto_rank": {"E": 10.0, "D": 20.0, "C": 30.0, "B": 40.0, "A": 50.0, "S": 60.0},
	"req_abates_tipo": {"D": 50, "C": 200, "B": 500, "A": 1500, "S": 5000},
	"req_especies": {"D": 5, "C": 15, "B": 30, "A": 60, "S": 100},
	"req_craft_pictures": {"D": 5, "C": 15, "B": 40, "A": 100, "S": 250},
	"erva_chance_abate": 0.03,
	"foto_chance_shiny": 0.4,
	"craft_ervas": 10,
	"craft_ouro": 5000,
	"berry_bonus_rank": {"E": 0.0, "D": 5.0, "C": 10.0, "B": 15.0, "A": 20.0, "S": 25.0},
}
var dados


func _init(dados_jogo) -> void:
	dados = dados_jogo
	var b: Dictionary = Balanceamento.secao("profissoes")
	for k in b:
		p[k] = b[k]


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


func _est(estado: Dictionary) -> Dictionary:
	if not estado.has("profissao"):
		estado["profissao"] = {}
	var e: Dictionary = estado["profissao"]
	for k in [["atual", ""], ["ranks", {}], ["abates_tipo", {}], ["berries_craftadas", 0], ["pictures", 0], ["pictures_entregues", 0], ["ervas", 0]]:
		if not e.has(k[0]):
			e[k[0]] = k[1] if not k[1] is Dictionary else {}
	return e


func rank(estado: Dictionary) -> String:
	var e := _est(estado)
	return String(e["ranks"].get(String(e["atual"]), "")) if String(e["atual"]) != "" else ""


func bonus_captura(estado: Dictionary) -> float:
	## Fração somada à chance direta (C: +3% por rank, cumulativo desde o E).
	var r := rank(estado)
	return 0.0 if r == "" else float(RANKS.find(r) + 1) * float(p.captura_pct_rank) / 100.0


func mentor_teto(estado: Dictionary) -> float:
	var r := rank(estado)
	return 0.0 if r == "" else float(p.mentor_teto_rank.get(r, 0.0))


func para_sim(estado: Dictionary) -> Dictionary:
	## cfg da simulação: bonus_captura (soma), mentor {gap, pct_nivel, teto}, profissao {atual, erva_chance, foto_chance}.
	var e := _est(estado)
	return {"bonus_captura_prof": bonus_captura(estado), "mentor": {"gap": int(p.mentor_gap), "pct_nivel": float(p.mentor_pct_nivel), "teto": mentor_teto(estado)},
		"profissao": {"atual": String(e["atual"]), "erva_chance": float(p.erva_chance_abate), "foto_chance": float(p.foto_chance_shiny)}}


func _requisitos(estado: Dictionary, prox: String, especies: int) -> Array:
	var e := _est(estado)
	var precisa_tipo := int(p.req_abates_tipo.get(prox, 0))
	var tipos_ok := 0
	var tipos: Array = Regras.TABELA_TIPOS.keys()
	for t in tipos:
		if int(e["abates_tipo"].get(String(t), 0)) >= precisa_tipo:
			tipos_ok += 1
	var terceiro := "berries" if String(e["atual"]) == "botanist" else "pictures"
	var feito3 := int(e["berries_craftadas"]) if terceiro == "berries" else int(e["pictures_entregues"])
	return [{"chave": "abates_tipo", "tem": tipos_ok, "precisa": tipos.size(), "por_tipo": precisa_tipo},
		{"chave": "especies", "tem": especies, "precisa": int(p.req_especies.get(prox, 0))},
		{"chave": terceiro, "tem": feito3, "precisa": int(p.req_craft_pictures.get(prox, 0))}]


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	var e := _est(estado)
	match String(cmd.get("type", "")):
		"prof-get":
			return [_msg(estado, int(cmd.get("especies", 0)))]
		"prof-escolher":
			var pr := String(cmd.get("prof", ""))
			if not pr in ATIVAS:
				return [_erro("Esta profissão ainda não está disponível.")]   # C: soonTitle
			e["atual"] = pr
			if not e["ranks"].has(pr):
				e["ranks"][pr] = "E"   # C: volta no rank que já tinha; nova começa no inicial
			return [{"type": "prof-escolhida", "prof": pr, "rank": String(e["ranks"][pr])}, _msg(estado, int(cmd.get("especies", 0)))]
		"prof-subir":
			var r := rank(estado)
			if r == "" or r == "S":
				return [_erro("Rank máximo atingido." if r == "S" else "Escolha uma profissão.")]
			var prox: String = RANKS[RANKS.find(r) + 1]
			for q in _requisitos(estado, prox, int(cmd.get("especies", 0))):
				if int(q["tem"]) < int(q["precisa"]):
					return [_erro("Complete os requisitos primeiro.")]   # C: rankUpNotReady
			if String(e["atual"]) == "prestige":
				e["pictures"] = int(e["pictures"]) - int(p.req_craft_pictures.get(prox, 0))   # C: entregar as pictures
			e["ranks"][String(e["atual"])] = prox
			return [{"type": "prof-rank", "prof": String(e["atual"]), "rank": prox}, _msg(estado, int(cmd.get("especies", 0)))]
		"prof-craft":
			if String(e["atual"]) != "botanist":
				return [_erro("Só o Botânico cria berries.")]
			var tipo := String(cmd.get("tipo", "")).to_upper()
			var berry := _berry_do_tipo(tipo)
			if berry < 0:
				return [_erro("Não há berry desse tipo.")]
			if int(e["ervas"]) < int(p.craft_ervas) or int(estado.get("gold", 0)) < int(p.craft_ouro):
				return [_erro("Precisa de %d Fresh Herbs e %d de ouro." % [int(p.craft_ervas), int(p.craft_ouro)])]
			e["ervas"] = int(e["ervas"]) - int(p.craft_ervas)
			estado["gold"] = int(estado["gold"]) - int(p.craft_ouro)
			estado["itens"][str(berry)] = int(estado["itens"].get(str(berry), 0)) + 1
			e["berries_craftadas"] = int(e["berries_craftadas"]) + 1
			return [{"type": "prof-craft", "itemId": berry, "name": String(dados.itens[berry]["nome"])}, _msg(estado, int(cmd.get("especies", 0)))]
		"prof-entregar":
			# Prestígio: entrega as pictures guardadas (contam para o rank)
			var n := int(e["pictures"])
			e["pictures_entregues"] = int(e["pictures_entregues"]) + n
			e["pictures"] = 0
			return [{"type": "prof-entregue", "n": n}, _msg(estado, int(cmd.get("especies", 0)))]
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


func registrar_hunt(estado: Dictionary, abates_por_especie: Dictionary, ervas: int, fotos: int) -> void:
	## Depois de uma hunt: abates por tipagem (requisito de rank), ervas colhidas (Botânico), fotos (Prestígio).
	var e := _est(estado)
	for sid in abates_por_especie:
		for t in Regras.tipos_de(dados.especie(int(sid))):
			if String(t) != "":
				e["abates_tipo"][String(t)] = int(e["abates_tipo"].get(String(t), 0)) + int(abates_por_especie[sid])
	e["ervas"] = int(e["ervas"]) + ervas
	e["pictures"] = int(e["pictures"]) + fotos


var _berries_por_tipo := {}


func _berry_do_tipo(tipo: String) -> int:
	if _berries_por_tipo.is_empty():
		var sv = preload("res://sim/servico_itens.gd").new(dados)
		for id in dados.itens:
			var ef: Dictionary = sv.efeito_berry(int(id))
			if not ef.is_empty() and not _berries_por_tipo.has(String(ef["efeito"])):
				_berries_por_tipo[String(ef["efeito"])] = int(id)
	return int(_berries_por_tipo.get(tipo, -1))


func _msg(estado: Dictionary, especies: int) -> Dictionary:
	var e := _est(estado)
	var r := rank(estado)
	var prox: String = RANKS[RANKS.find(r) + 1] if r != "" and r != "S" else ""
	return {"type": "professions", "atual": String(e["atual"]), "rank": r, "ranks": e["ranks"].duplicate(), "proximo": prox,
		"requisitos": _requisitos(estado, prox, especies) if prox != "" else [], "ervas": int(e["ervas"]), "pictures": int(e["pictures"]),
		"bonusCaptura": bonus_captura(estado), "mentorTeto": mentor_teto(estado)}
