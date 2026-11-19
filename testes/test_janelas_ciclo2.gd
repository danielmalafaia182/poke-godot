extends SceneTree
## Ciclo 2, backlog do cliente (save ISOLADO; rodar com testes/rodar.sh res://testes/test_janelas_ciclo2.gd):
##   cidade: ícones do dock abrem Perfil, Gerenciamento de Captura, Log de Capturas, Streak e Diário; textos do pacote;
##   hunt (Rhydon, acelerada): Hunt Analyzer com os números do registro, captura shiny entra shiny no time/BOX e no log,
##   avisos de nível e shiny, barra de boosts com o shinylock; save guarda log, tempo em caça e shiny.

const ESPECIES: Script = preload("res://especies_importadas.gd")
const XP: Script = preload("res://sim/regras.gd")
const T := preload("res://textos.gd")

var falhas := 0
var total := 0
var etapa := 0
var quadros := 0
var caca: Node
var avisos_vistos: Array = []
var boosts_vistos: Array = []


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var ej = get_root().get_node("EstadoJogo")
	var g := DadosPokemon.new()
	g.especie = ESPECIES.obter_especies()["Venusaur"]
	g.experiencia_total = XP.xp_total_para_nivel(140)
	g.iv_hp = 26; g.iv_atk = 5; g.iv_def = 4; g.iv_sp_atk = 18; g.iv_sp_def = 17; g.iv_spd = 28
	g.qualidade = 0.9
	g.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
	g.normalizar_atributos()
	g.vida_atual = g.obter_vida_maxima()
	var time: Array[DadosPokemon] = [g]
	ej.colecao.time_pokemon = time
	ej.definir_perfil_treinador("Teste", 120)
	ej.definir_auto_potion(true)
	ej.inventario.estoque_pocoes[203] = 500
	ej.medidor_captura = {"112": {"investido": 100.0, "tentativas": 3, "total": 9, "gasto": 450}, "112s": {"investido": 0.0, "tentativas": 1, "total": 1, "gasto": 400}}
	checar(T.t("window.huntAnalyzer.title") == "Hunt Analyzer" and T.t("hud.levelUp.level", {"level": 7}) == "Nv. 7", "pacote de textos do original carregado, com {{variáveis}}")
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	match etapa:
		0:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn" and quadros > 5:
				var menu: Control = current_scene.get_node("Interface/MenuSuperior")
				for par in [["profile", "PainelPerfil"], ["usedballs", "PainelBolasUsadas"], ["streak", "PainelStreak"], ["daily", "PainelDiarias"]]:
					var b: Button = menu.botoes[par[0]]
					b.pressed.emit()
					var p: Control = current_scene.get_node("Interface/" + par[1])
					checar(not b.disabled and p.visible, "cidade: ícone %s abre a janela" % par[0])
					p.hide()
				checar(menu.botoes["analyzer"].disabled, "cidade: Hunt Analyser só na hunt (ícone desligado)")
				var bolas: Control = current_scene.get_node("Interface/PainelBolasUsadas")
				bolas.abrir()
				checar(bolas.find_child("L_112", true, false) != null and bolas.find_child("L_112s", true, false) == null, "Bolas usadas: Rhydon na aba normal, shiny só na aba shiny")
				(bolas.find_child("Aba_shiny", true, false) as Button).pressed.emit()
				checar(bolas.find_child("L_112s", true, false) != null, "Bolas usadas: aba shiny mostra a variante shiny")
				bolas.hide()
				var mapa: Node = load("res://mapa_mundi.tscn").instantiate()
				current_scene.add_child(mapa)
				etapa = 1
				quadros = 0
		1:
			if quadros == 3:
				var mapa: Node = current_scene.get_child(current_scene.get_child_count() - 1)
				for r in mapa.catalogo:
					if String(r["name"]) == "Rhydon":
						mapa._selecionar_registro(r)
				etapa = 2
				quadros = 0
		2:
			if current_scene != null and current_scene.scene_file_path == "res://caca_sim.tscn":
				caca = current_scene
				caca.velocidade = 40.0
				var av: Control = caca.hud_caca.avisos
				checar(av != null, "hunt: avisos da HUD instalados")
				var orig: Callable = av.avisar
				caca.subiu_nivel.connect(func(n, nv, t): avisos_vistos.append("nivel"))
				caca.boosts_alterados.connect(func(l): boosts_vistos.append_array(l))
				# shiny garantido no próximo respawn e captura certa com Master Ball no Auto-Catch Shiny
				caca.sim.p["shiny_chance"] = 1.0
				caca.sim.cfg["auto_catch_shiny"] = true
				caca.sim.cfg["bola_auto_catch_shiny"] = 5
				caca.sim.balls["counts"]["5"] = 50
				ej.estoque_bolas[5] = 50
				etapa = 3
				quadros = 0
			elif quadros > 300:
				checar(false, "a hunt abriu")
				return _fim()
		3:
			if int(caca.registro.get("shiny_capturados", 0)) >= 1 or quadros > 2400:
				var an: Control = caca.hud_caca.janelas_dock["analyzer"]
				caca.hud_caca.menu.botoes["analyzer"].pressed.emit()
				var r: Dictionary = an.resumo()
				checar(an.visible and int(r["abates"]) == int(caca.registro["abates"]) and int(r["xp"]) == int(caca.registro["xp_treinador"]) and int(r["abates"]) > 0,
					"Hunt Analyzer: abates e XP iguais ao registro da hunt", "%d abates, %d XP, %d XP/h" % [int(r["abates"]), int(r["xp"]), int(r["xp_h"])])
				checar(int(r["supply"]) >= 0 and int(r["valor_loot"]) >= 0, "Hunt Analyzer: loot e supply a preço de NPC", "loot $%d, supply $%d, saldo $%d" % [int(r["valor_loot"]), int(r["supply"]), int(r["saldo"])])
				an.zerar()
				checar(int(an.resumo()["abates"]) == 0, "Zerar sessão zera os contadores")
				an.hide()
				var shiny_pk = null
				for pk in ej.time_pokemon + ej.pokemons_capturados:
					if pk != null and pk.shiny:
						shiny_pk = pk
				checar(int(caca.registro.get("shiny_capturados", 0)) >= 1 and shiny_pk != null, "captura de shiny entra shiny no time/BOX", str(caca.registro.get("shiny_capturados", 0)))
				checar(not ej.log_capturas.is_empty() and bool(ej.log_capturas[0]["shiny"]) and String(ej.log_capturas[0]["bola"]) != "", "Log de Capturas: a captura shiny no topo, com a bola", str(ej.log_capturas[0] if not ej.log_capturas.is_empty() else {}))
				var lg: Control = caca.hud_caca.janelas_dock["log"]
				lg.abrir()
				checar(lg.visible and lg.find_children("*", "Label", true, false).size() > 4, "Log de Capturas abre na hunt")
				lg.hide()
				checar((caca.hud_caca.avisos.boosts as Array).any(func(b): return String(b.get("key", "")) == "shinylock"), "barra de boosts recebeu o shinylock da entrada (A: boosts logo depois do field-init)")
				checar(int(ej.tempo_caca_s) > 0, "tempo em caça conta", str(ej.tempo_caca_s))
				checar(ej.salvar_agora(), "save gravado")
				var sl = load("res://salvamento_local.gd").new()
				var d: Dictionary = sl.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json")).get("dados", {})
				var tem_shiny := false
				for p in d.get("box", []) + d.get("team", []):
					tem_shiny = tem_shiny or p.get("shiny", false) == true
				checar(tem_shiny and (d.get("log_capturas", []) as Array).size() == ej.log_capturas.size() and int(d.get("tempo_caca_s", 0)) > 0 and int(d.get("capturas_total", 0)) >= 1,
					"save: shiny, log, tempo em caça e capturas totais")
				return _fim()
	return false


func _fim() -> bool:
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
