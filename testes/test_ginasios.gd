extends SceneTree
## Ginásios (ciclo 3; classe 3 em balanceamento.json "ginasios", sim/servico_ginasios.gd). Save ISOLADO:
##   sim: 18 ginásios do cliente com os 4 tipos gravados (A); luta determinística pela semente; vencer dá insígnia de
##   48 h (C) que vale na hunt (+1% XP por insígnia, parcela gym); perder bloqueia 60 s; nível do treinador barra;
##   cena: o ícone do dock abre a janela; desafiar com o time do save; insígnia no save.

const G := preload("res://sim/servico_ginasios.gd")
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


func _time(sp: int, nv: int) -> Array:
	return [{"speciesId": sp, "xp": Regras.xp_total_para_nivel(nv), "ivs": {"hp": 20, "atk": 20, "def": 20, "spAtk": 20, "spDef": 20, "speed": 20}, "quality": 1.1}]


func _initialize() -> void:
	var dados = preload("res://ponte_cidade.gd").dados()
	var sv = G.new(dados)
	var tipos := {}
	for g in sv.p.lista:
		tipos[String(g["id"])] = String(g["tipo"])
	checar(sv.p.lista.size() == 18 and tipos.get("pewter") == "ROCK" and tipos.get("cerulean") == "WATER" and tipos.get("mahogany") == "ICE" and tipos.get("spikemuth") == "DARK",
		"18 ginásios; pewter Pedra, cerulean Água, mahogany Gelo, spikemuth Sombrio (A)")
	var g := sv.ginasio("vermilion")
	var r1 = sv.lutar(_time(76, 40), g, 7)
	var r2 = sv.lutar(_time(76, 40), g, 7)
	checar(JSON.stringify(r1) == JSON.stringify(r2) and bool(r1["venceu"]) and (r1["log"] as Array).size() > 3, "luta determinística; Golem 40 vence o Elétrico (vantagem de tipo)", "%d golpes" % (r1["log"] as Array).size())
	var r3 = sv.lutar(_time(76, 22), sv.ginasio("cerulean"), 7)
	checar(not bool(r3["venceu"]), "Golem 22 perde para a Água (desvantagem ×4)")
	var e := {"ginasios": {}, "nivel": 25}
	var m = sv.tratar(e, {"type": "ginasio-desafiar", "gymId": "vermilion", "agora": 1000, "nivel": 25, "time": _time(76, 40), "semente": 1})
	checar(String(m[0]["type"]) == "error", "treinador abaixo do nível do ginásio não desafia")
	m = sv.tratar(e, {"type": "ginasio-desafiar", "gymId": "vermilion", "agora": 1000, "nivel": 30, "time": _time(76, 40), "semente": 1})
	checar(bool(m[0]["badgeEarned"]) and int(e["ginasios"]["insignias"]["vermilion"]) == (1000 + 48 * 3600) * 1000 and sv.ativas(e, 1000) == 1, "vitória: insígnia por 48 h (C)")
	checar(sv.ativas(e, 1000 + 48 * 3600 + 1) == 0, "depois de 48 h a insígnia expira")
	m = sv.tratar(e, {"type": "ginasio-desafiar", "gymId": "cerulean", "agora": 2000, "nivel": 30, "time": _time(76, 22), "semente": 1})
	var m2 = sv.tratar(e, {"type": "ginasio-desafiar", "gymId": "cerulean", "agora": 2030, "nivel": 30, "time": _time(76, 22), "semente": 1})
	checar(not bool(m[0]["badgeEarned"]) and String(m2[0]["type"]) == "error", "derrota: 60 s sem novo desafio")
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
	g.experiencia_total = Regras.xp_total_para_nivel(60)
	g.iv_hp = 20; g.iv_atk = 20; g.iv_def = 20; g.iv_sp_atk = 20; g.iv_sp_def = 20; g.iv_spd = 20
	g.qualidade = 1.1
	g.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
	g.normalizar_atributos()
	var time: Array[DadosPokemon] = [g]
	for pk in ej.time_pokemon:
		if pk != null and time.size() < 6:
			time.append(pk)
	ej.colecao.time_pokemon = time
	ej.colecao.pokemon_lider = g
	ej.definir_perfil_treinador("Teste", 40)
	var menu: Control = current_scene.get_node("Interface/MenuSuperior")
	menu.botoes["gyms"].pressed.emit()
	var pg: Control = current_scene.get_node("Interface/PainelGinasios")
	checar(pg.visible and pg.find_child("G_pewter", true, false) != null and (pg.find_child("Desafiar_saffron", true, false) as Button).disabled, "dock: Ginásios abre; ginásio acima do nível fica trancado")
	var r: Dictionary = pg.desafiar("vermilion")
	checar(bool(r.get("venceu", false)) and ej.insignias_ativas(int(Time.get_unix_time_from_system())) == 1, "desafio pela janela com o time do save: vitória e insígnia ativa", str(r.get("erro", "")))
	(pg.find_child("PularLuta", true, false) as Button).pressed.emit()
	checar(pg.find_child("VoltarLuta", true, false) != null, "replay da luta até o fim, com Voltar")
	checar(ej.salvar_agora(), "save gravado")
	var sl = load("res://salvamento_local.gd").new()
	var d: Dictionary = sl.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json")).get("dados", {})
	checar(d.get("ginasios", {}).get("insignias", {}).has("vermilion"), "insígnia no save")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
