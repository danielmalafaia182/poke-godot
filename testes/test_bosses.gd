extends SceneTree
## Bosses (ciclo 3; A: 87 do snapshot; C: entrada por token, perde o token na derrota, Auto Boss fora de hunt, Altar;
## classe 3 em balanceamento.json "bosses"). Save ISOLADO (testes/rodar.sh).

const B := preload("res://sim/servico_bosses.gd")
const Regras := preload("res://sim/regras.gd")
const ESPECIES: Script = preload("res://especies_importadas.gd")

var falhas := 0
var total := 0
var quadros := 0
var feito := false


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _time(sp: int, nv: int, n: int = 1) -> Array:
	var t: Array = []
	for i in n:
		t.append({"speciesId": sp, "xp": Regras.xp_total_para_nivel(nv), "ivs": {"hp": 32, "atk": 32, "def": 32, "spAtk": 32, "spDef": 32, "speed": 32}, "quality": 1.4})
	return t


func _initialize() -> void:
	var dados = preload("res://ponte_cidade.gd").dados()
	var sv = B.new(dados)
	var cats := {}
	for b in sv.p.lista:
		cats[String(b["categoria"])] = int(cats.get(String(b["categoria"]), 0)) + 1
	checar(sv.p.lista.size() == 87 and int(cats.get("Especiais", 0)) == 48 and int(cats.get("Terror", 0)) == 12, "87 bosses do snapshot nas 5 categorias (A)", str(cats))
	var esp := ""
	for b in sv.p.lista:
		if b["entrada"] == null and int(b["nivel"]) <= 300:
			esp = String(b["key"])
			break
	var e := {"nivel": 290}
	var m = sv.tratar(e, {"type": "boss-desafiar", "key": esp, "agora": 1000, "nivel": 290, "time": _time(76, 400, 6), "semente": 3})
	checar(String(m[0]["type"]) == "error", "abaixo do nível do boss não desafia (C: 'Requer nível')")
	m = sv.tratar(e, {"type": "boss-desafiar", "key": esp, "agora": 1000, "nivel": 400, "time": _time(76, 600, 6), "semente": 3})
	checar(String(m[0]["type"]) == "boss-result" and bool(m[0]["venceu"]), "boss Especial com entrada grátis: time forte vence", "%.0f s" % (int(m[0]["duracaoMs"]) / 1000.0))
	var m2 = sv.tratar(e, {"type": "boss-desafiar", "key": esp, "agora": 1010, "nivel": 400, "time": _time(76, 600, 6), "semente": 4})
	checar(String(m2[0]["type"]) == "error", "recarga entre lutas do mesmo boss")
	var md := ""
	for b in sv.p.lista:
		if String(b["categoria"]) == "Mystery Dungeons":
			md = String(b["key"])
			break
	var e2 := {"nivel": 700, "bosses": {"itens": {}}}
	checar(String(sv.tratar(e2, {"type": "boss-desafiar", "key": md, "agora": 1, "nivel": 700, "time": _time(76, 600), "semente": 1})[0]["type"]) == "error", "sem Boss Token não entra na Mystery Dungeon (C)")
	e2["bosses"]["itens"]["Boss Token"] = 3
	var r = sv.tratar(e2, {"type": "boss-desafiar", "key": md, "agora": 1, "nivel": 700, "time": _time(74, 5), "semente": 1})[0]
	checar(not bool(r["venceu"]) and int(e2["bosses"]["itens"]["Boss Token"]) == 2, "derrota: o token da luta é perdido (C)")
	var a = sv.tratar(e2, {"type": "auto-boss", "key": md, "lutas": 10, "agora": 100, "nivel": 700, "time": _time(76, 900, 6), "semente": 2})[0]
	checar(String(a["type"]) == "auto-boss-result" and (a["lutas"] as Array).size() >= 2 and String(a["fim"]) in ["sem_token", "concluido"], "Auto Boss: lutas em sequência até acabar a fila ou os tokens (C)", "%d lutas, fim %s" % [(a["lutas"] as Array).size(), String(a["fim"])])
	var card := sv.card_do_shiny("Charizard")
	var e3 := {"nivel": 700, "itens": {str(card): 1}}
	var al = sv.tratar(e3, {"type": "altar-desafiar", "itemId": card, "agora": 5, "nivel": 700, "time": _time(76, 900, 6), "semente": 9})[0]
	checar(card > 0 and String(al["type"]) == "altar-result" and int(e3["itens"][str(card)]) == 0 and String(al["especie"]) in ["Raikou", "Entei", "Suicune"], "Altar: o Shiny Card é sacrificado e a luta é contra um shiny lendário (C)", String(al.get("especie", "")))
	get_root().get_node("EstadoJogo").iniciar_depot()
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if feito or current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	feito = true
	var ej = get_root().get_node("EstadoJogo")
	var g := DadosPokemon.new()
	g.especie = ESPECIES.obter_especies()["Golem"]
	g.experiencia_total = Regras.xp_total_para_nivel(700)
	g.iv_hp = 32; g.iv_atk = 32; g.iv_def = 32; g.iv_sp_atk = 32; g.iv_sp_def = 32; g.iv_spd = 32
	g.qualidade = 1.5
	g.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
	g.normalizar_atributos()
	var time: Array[DadosPokemon] = [g]
	for pk in ej.time_pokemon:
		if pk != null and time.size() < 6:
			time.append(pk)
	ej.colecao.time_pokemon = time
	ej.colecao.pokemon_lider = g
	ej.definir_perfil_treinador("Teste", 400)
	current_scene.get_node("Interface/MenuSuperior").botoes["bosses"].pressed.emit()
	var pb: Control = current_scene.get_node("Interface/PainelBosses")
	var info: Dictionary = ej.bosses_info(int(Time.get_unix_time_from_system()))
	var key := ""
	for b in info["bosses"]:
		if b["entrada"] == null and bool(b["liberado"]):
			key = String(b["key"])
			break
	checar(pb.visible and key != "" and pb.find_child("Desafiar_" + key, true, false) != null, "dock: Bosses abre com a lista")
	var r: Dictionary = pb.comando({"type": "boss-desafiar", "key": key})
	checar(bool(r.get("venceu", false)), "desafio pela janela com o time do save", str(r.get("erro", "")))
	checar(ej.salvar_agora(), "save gravado")
	var sl = load("res://salvamento_local.gd").new()
	var d: Dictionary = sl.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json")).get("dados", {})
	checar(not (d.get("bosses", {}).get("historico", []) as Array).is_empty(), "histórico de bosses no save")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
