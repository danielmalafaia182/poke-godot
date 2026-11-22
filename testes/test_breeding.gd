extends SceneTree
## Breeding (ciclo 6): regras do cliente (C) no sim/servico_breeding.gd, números classe 3.

const DadosJogo := preload("res://sim/dados_jogo.gd")
const Br := preload("res://sim/servico_breeding.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _id(dados, nome: String) -> int:
	for k in dados.especies:
		if String(dados.especies[k]["nome"]) == nome:
			return int(k)
	return -1


func _init() -> void:
	var dados = DadosJogo.carregar()
	var s = Br.new(dados)
	var gol := _id(dados, "Golem")
	var ivs_a := {"hp": 30, "atk": 31, "def": 32, "spAtk": 29, "spDef": 28, "speed": 27}
	var ivs_b := {"hp": 5, "atk": 5, "def": 5, "spAtk": 5, "spDef": 5, "speed": 5}
	var rocha: int = s.pedra_do_tipo(gol)
	var est := {"pokes": [{"id": "a", "speciesId": gol, "ivs": ivs_a, "quality": 1.4, "shiny": false, "team": false},
		{"id": "b", "speciesId": gol, "ivs": ivs_b, "quality": 1.1, "shiny": false, "team": false},
		{"id": "t", "speciesId": gol, "ivs": ivs_b, "quality": 1.0, "shiny": false, "team": true},
		{"id": "s", "speciesId": gol, "ivs": ivs_b, "quality": 1.0, "shiny": true, "team": false}],
		"itens": {str(rocha): 10, "44417": 1}}
	checar(rocha > 0 and s.estagio_base(gol) == _id(dados, "Geodude"), "filho nasce no estágio base (Golem → Geodude); pedra do tipo principal", str(rocha))
	checar(String(s.tratar(est, {"type": "breed", "paiA": "a", "paiB": "t"})[0]["type"]) == "error", "pai do time: recusado (os pais saem da box)")
	checar(String(s.tratar(est, {"type": "breed", "paiA": "a", "paiB": "s", "caminho": "livre"})[0]["type"]) == "error", "caminho livre com pai shiny: recusado (C)")
	var r: Array = s.tratar(est, {"type": "breed", "paiA": "a", "paiB": "b", "caminho": "feromonio", "semente": 5})
	var ovo: Dictionary = r[0].get("ovo", {})
	checar(String(r[0]["type"]) == "breed-egg" and est["pokes"].size() == 2 and not est["itens"].has("44417") and int(est["itens"][str(rocha)]) == 8,
		"ovo criado: pais consumidos, 1 Strange Pheromone e 2 pedras gastos")
	checar(float(ovo["quality"]) >= 1.4 + 0.15 - 1e-6 and float(ovo["quality"]) <= 1.4 + 0.30 + 1e-6, "Quality = melhor pai + Δ (0,15–0,30, feromônio)", str(ovo["quality"]))
	var herdados := 0
	for k in ivs_a:
		herdados += 1 if int(ovo["ivs"][k]) == int(ivs_a[k]) else 0
	checar(herdados >= 1, "IVs herdados do melhor pai (%d de 6)" % herdados)
	est["pokes"].append({"id": "c", "speciesId": gol, "ivs": ivs_b, "quality": 1.0, "shiny": true, "team": false})
	est["itens"]["44417"] = 1
	var r2: Array = s.tratar(est, {"type": "breed", "paiA": "s", "paiB": "c", "caminho": "feromonio", "semente": 9})
	checar(bool(r2[0]["ovo"]["shiny"]), "pai shiny → filho shiny (C)")
	est["pokes"].append({"id": "d", "speciesId": gol, "ivs": ivs_b, "quality": 1.0, "shiny": false, "team": false})
	est["pokes"].append({"id": "e", "speciesId": gol, "ivs": ivs_b, "quality": 1.0, "shiny": false, "team": false})
	checar(String(s.tratar(est, {"type": "breed", "paiA": "d", "paiB": "e"})[0]["type"]) == "error", "incubadora cheia (2 slots)")
	checar(s.chocar(est, 499).is_empty() and s.chocar(est, 1).size() == 2, "os ovos chocam com 500 abates nas hunts")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
