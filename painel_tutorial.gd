extends Control
## Tutorial do Professor Carvalho (C: window.tutorial; textos e ordem dos passos do cliente, pacote original).
## Passos que pedem uma ação avançam sozinhos quando a ação acontece (Nurse, Depot, Mark, mapa aberto, entrar na hunt,
## primeiro abate); os outros, no clique. "Pular este passo" e "Pular tutorial" como no original.
## Fora do offline (E, uma linha cada): `market` (Mercado entre jogadores, online), `throwBall` (captura manual adiada:
## o jogo usa o Auto-Catch), `openInv`/`usePotion` (sem janela de Inventário com duplo clique; poções são automáticas).
## O passo atual vai no save (EstadoJogo.tutorial_passo: "" nunca começou, "fim" concluído); ⚙ → 🎓 Tutorial refaz.

const T := preload("res://textos.gd")
const ESTILO: Script = preload("res://estilo_hud_original.gd")
const PASSOS := ["welcome", "party", "menu", "walk", "nurse", "depot", "shop", "openMap", "firstHunt", "hunting", "captureMgmt", "replay", "done"]
const PASSOS_CIDADE := ["welcome", "party", "menu", "walk", "nurse", "depot", "shop", "openMap", "firstHunt", "replay", "done"]
const PASSOS_HUNT := ["hunting", "captureMgmt"]
## objetivo de cada passo de ação: nome do nó (filho de `raiz`) que fica visível quando o jogador faz a ação
const OBJETIVO := {"nurse": "NurseJoy", "depot": "PainelDepot", "shop": "PainelLoja", "openMap": "MapaMundi"}
const NPC := {"nurse": "nurse", "depot": "depot", "shop": "mark"}

var na_hunt := false
var raiz: Node                    # onde procurar os painéis (Interface da cidade, ou o HUD da hunt)
var cartao: PanelContainer
var titulo: Label
var texto: RichTextLabel
var objetivo: Label
var continuar: Button
var pular_passo: Button
var abates_vistos := 0
var _ultimo := "-"
var _novo_aberto := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao = PanelContainer.new()
	cartao.name = "CartaoTutorial"
	cartao.add_theme_stylebox_override("panel", ESTILO.moldura())
	cartao.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cartao)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	cartao.add_child(col)
	titulo = Label.new()
	titulo.add_theme_color_override("font_color", Color("f0c040"))
	titulo.add_theme_font_size_override("font_size", 18)
	col.add_child(titulo)
	texto = RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.custom_minimum_size = Vector2(520, 0)
	col.add_child(texto)
	objetivo = Label.new()
	objetivo.add_theme_color_override("font_color", Color("9fe0a0"))
	objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(objetivo)
	var h := HBoxContainer.new()
	col.add_child(h)
	continuar = Button.new()
	continuar.name = "Continuar"
	continuar.pressed.connect(avancar)
	h.add_child(continuar)
	pular_passo = Button.new()
	pular_passo.name = "PularPasso"
	pular_passo.text = T.t("window.tutorial.skipStep")
	pular_passo.pressed.connect(avancar)
	h.add_child(pular_passo)
	var pular := Button.new()
	pular.name = "PularTutorial"
	pular.text = T.t("window.tutorial.skipTutorial")
	pular.pressed.connect(func() -> void: _definir("fim"))
	h.add_child(pular)
	resized.connect(_ajustar)
	_mostrar()


func _ej() -> Node:
	return get_node("/root/EstadoJogo")


func passo() -> String:
	return String(_ej().tutorial_passo)


func _definir(p: String) -> void:
	_ej().tutorial_passo = p
	_ej().solicitar_salvamento()
	_mostrar()


func reiniciar() -> void:
	_definir("welcome")


func avancar() -> void:
	var i := PASSOS.find(passo())
	_definir("fim" if i < 0 or i + 1 >= PASSOS.size() else String(PASSOS[i + 1]))


func _ajustar() -> void:
	cartao.size = Vector2(minf(600.0, size.x - 32.0), 0)
	cartao.reset_size()
	cartao.size.x = minf(600.0, size.x - 32.0)
	cartao.position = Vector2(size.x - cartao.size.x - 24.0, size.y - cartao.get_combined_minimum_size().y - 140.0)


func _vars() -> Dictionary:
	var ej := _ej()
	var lider = ej.obter_lider()
	var starter := String(lider.especie.nome) if lider != null and lider.especie != null else T.t("window.tutorial.starterFallback")
	var hunt := "Rattata"
	var por_que := "nível 1, o Geodude é de Pedra/Terra e resiste ao golpe Normal dos Rattata"   # E: inicial do projeto
	var tipo := ""
	if lider != null and lider.especie != null:
		tipo = String(lider.especie.tipo_primario).to_lower()
	if T.tem("window.tutorial.why." + tipo):
		por_que = T.t("window.tutorial.why." + tipo)
		hunt = {"grass": "Geodude", "water": "Geodude", "fire": "Paras"}.get(tipo, hunt)
	return {"starter": starter, "hunt": hunt, "why": por_que}


func _mostrar() -> void:
	var p := passo()
	var lugar_ok: bool = (p in PASSOS_HUNT) if na_hunt else (p in PASSOS_CIDADE)
	visible = p != "" and p != "fim" and lugar_ok
	if not visible:
		return
	titulo.text = "%s — %s" % [T.t("window.tutorial.oakAlt", {}, "Professor Carvalho"), T.t("window.tutorial.step.%s.title" % p)]
	texto.text = T.bbcode(T.t("window.tutorial.step.%s.text" % p, _vars()))
	var acao := OBJETIVO.has(p) or p in ["firstHunt", "hunting"]
	objetivo.text = ""
	if NPC.has(p):
		objetivo.text = T.sem_html(T.t("window.tutorial.goalClickNpc", {"npcName": T.t("window.tutorial.npc." + String(NPC[p]))}))
	continuar.visible = not acao
	continuar.text = T.t("window.tutorial.startJourneyBtn") if p == "done" else T.t("window.tutorial.clickToContinue")
	pular_passo.visible = acao
	_ajustar()


func ao_abate() -> void:
	## A cena da hunt avisa cada abate: o passo "hunting" fecha no primeiro.
	if passo() == "hunting":
		avancar()


func _process(_d: float) -> void:
	var p := passo()
	var novo := raiz != null and raiz.get_node_or_null("PainelNovoJogo") != null
	if p != _ultimo or novo != _novo_aberto:
		_ultimo = p
		_novo_aberto = novo
		_mostrar()
		if novo:
			visible = false
	if na_hunt:
		if p == "firstHunt":
			_definir("hunting")
		return
	if not visible or raiz == null:
		return
	if OBJETIVO.has(p):
		var alvo := raiz.find_child(String(OBJETIVO[p]), true, false) as CanvasItem
		if alvo != null and alvo.is_visible_in_tree():
			avancar()
