extends SceneTree
## Ditto (ciclo 8): sim/servico_ditto.gd e o efeito na simulação. C: transformação de 12 h no líder, −25% de HP/Atk/Def/
## SpA/SpD, sem Lendários, Megas, bosses de Orre e Pokémon da Outland; stats fixos IV 89 e Quality 1,4.

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")
const Ditto := preload("res://sim/servico_ditto.gd")

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
	var s = Ditto.new(dados)
	var est := {}
	checar(String(s.tratar(est, {"type": "ditto-receber", "nivel": 99})[0]["type"]) == "error", "antes do treinador 100: sem Ditto (classe 3)")
	var r: Dictionary = s.tratar(est, {"type": "ditto-receber", "nivel": 100})[0]
	var soma := 0
	for k in r["poke"]["ivs"]:
		soma += int(r["poke"]["ivs"][k])
	checar(String(r["type"]) == "ditto-recebido" and soma == 89 and float(r["poke"]["quality"]) == 1.4, "Ditto recebido: IV 89 e Quality 1,4 (C)")
	checar(String(s.tratar(est, {"type": "ditto-receber", "nivel": 200})[0]["type"]) == "error", "só um Ditto")
	var chz := _id(dados, "Charizard")
	checar(String(s.tratar(est, {"type": "ditto-transformar", "pokeId": "d", "speciesId": chz, "lider": false, "agora": 0})[0]["type"]) == "error", "fora da liderança: recusado (C)")
	var lend := -1
	for k in dados.especies:
		if String(dados.especies[k].get("raridade", "")) == "LEGENDARY":
			lend = int(k)
			break
	checar(lend > 0 and s.copiavel(lend) != "" and s.copiavel(10533) != "" and s.copiavel(chz) == "", "Lendário e forma da Outland não; Charizard sim (C)")
	var t: Dictionary = s.tratar(est, {"type": "ditto-transformar", "pokeId": "d", "speciesId": chz, "lider": true, "agora": 1000})[0]
	checar(String(t["type"]) == "ditto-transformado" and int(t["ate"]) == 1000 + 43200 and s.para_sim(est, 2000).get("d", 0) == chz and s.para_sim(est, 50000).is_empty(),
		"transformado em Charizard por 12 h (C)")
	var jogo := {"slug": "rhydon", "hunt": "rhydon", "equipe": [{"id": "d", "nome": "Ditto", "xp": Regras.xp_total_para_nivel(140), "ivs": r["poke"]["ivs"],
		"quality": 1.4, "hp": -1}], "auto_potion": true, "penalizar": false, "inventario": [{"itemId": 203, "quantity": 999}]}
	var sem = Simulacao.new(CenarioJogo.configurar(jogo, dados, 3, 0), dados, MapaHunt.carregar("rhydon", Fontes.ler_mapa("rhydon"), Fontes.ler_colisao()))
	jogo["ditto"] = {"d": chz}
	var com = Simulacao.new(CenarioJogo.configurar(jogo, dados, 3, 0), dados, MapaHunt.carregar("rhydon", Fontes.ler_mapa("rhydon"), Fontes.ler_colisao()))
	var esp_c: Dictionary = dados.especie(chz)
	var hp_c := Regras.hp_combate_aliado(int(Regras.calcular_stats(esp_c["base"], r["poke"]["ivs"], 140, 1.4)["hp"]))
	checar(String(com.equipe[0]["especie"]["nome"]) == "Charizard" and int(com.equipe[0]["max_hp"]) == Regras.js_round(float(hp_c) * 0.75) and String(sem.equipe[0]["especie"]["nome"]) == "Ditto",
		"na hunt luta como Charizard com 75% do HP (C)", "%d × %d" % [int(com.equipe[0]["max_hp"]), hp_c])
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
