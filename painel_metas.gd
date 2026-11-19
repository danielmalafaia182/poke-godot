extends Control
## Metas (ciclo 2; classe 3, decidida pelo design): só desenha o que sim/metas.gd calcula (EstadoJogo.metas()).
## Hunt recomendada para o líder agora, a próxima meta (troca de hunt ou o nível em que um golpe a menos derruba o
## selvagem), o próximo marco de nível do treinador (com os desbloqueios de região, C) e a coleção.
## `linha_resumo()` dá a frase curta que a cidade mostra sempre, embaixo do ouro.

const ESTILO: Script = preload("res://estilo_hud_original.gd")
const Regras := preload("res://sim/regras.gd")
const NOMES_AREA := {"kanto": "Kanto", "outland": "Outland", "orre": "Orre", "nightmare": "Nightmare"}
var janela: PanelContainer
var corpo: VBoxContainer
var ultimo: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hide())
	janela = PanelContainer.new()
	janela.add_theme_stylebox_override("panel", ESTILO.moldura())
	add_child(janela)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 8)
	janela.add_child(corpo)
	resized.connect(_ajustar)
	hide()


func abrir() -> void:
	show()
	atualizar()


func _ajustar() -> void:
	janela.size = Vector2(520, 300).max(janela.get_combined_minimum_size())
	janela.position = (size - janela.size) * 0.5


static func _n(v: float) -> String:
	## 1234567 → "1.234.567"
	var s := str(int(round(v)))
	var r := ""
	while s.length() > 3:
		r = "." + s.substr(s.length() - 3) + r
		s = s.substr(0, s.length() - 3)
	return s + r


static func frase_proxima(m: Dictionary) -> String:
	var pr: Dictionary = m.get("hunt", {}).get("proxima", {})
	if pr.is_empty():
		return ""
	if bool(pr.get("salto", false)):
		return "No nível %d do líder, %s cai com um golpe a menos: +%d%% de XP/min." % [int(pr["nivel_lider"]), String(pr["nome"]), int(pr["ganho_pct"])]
	return "No nível %d do líder, %s (%s %d) rende +%d%% de XP/min." % [int(pr["nivel_lider"]), String(pr["nome"]),
		NOMES_AREA.get(String(pr["area"]), String(pr["area"])), int(pr["nivel"]), int(pr["ganho_pct"])]


static func linha_resumo(m: Dictionary) -> String:
	## A frase que fica sempre na cidade: a próxima meta mais perto (troca/salto de hunt, senão o marco de nível).
	if m.is_empty():
		return ""
	var pr := frase_proxima(m)
	if pr != "":
		return "🎯 " + pr
	var mc: Dictionary = m["marco"]
	if int(mc["proximo"]) > 0:
		var rot := String(mc["rotulo"])
		return "🎯 Treinador nível %d%s: faltam %s XP." % [int(mc["proximo"]), (" (" + rot + ")") if rot != "" else "", _n(float(m["xp_falta"]))]
	return ""


func _rotulo(t: String, cor: Color = Color("f0e6d2"), tam: int = 0) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", cor)
	if tam > 0:
		l.add_theme_font_size_override("font_size", tam)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	corpo.add_child(l)
	return l


func _barra(atual: float, total: float) -> void:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = maxf(1.0, total)
	b.value = clampf(atual, 0.0, b.max_value)
	b.custom_minimum_size = Vector2(0, 14)
	b.show_percentage = false
	corpo.add_child(b)


func atualizar() -> void:
	for c in corpo.get_children():
		corpo.remove_child(c)
		c.queue_free()
	var ej: Node = get_node("/root/EstadoJogo")
	ultimo = ej.metas()
	_rotulo("Metas", Color("f0c040"), 20)
	if ultimo.is_empty():
		_rotulo("Sem líder no time.")
		return
	var h: Dictionary = ultimo["hunt"]
	var at: Dictionary = h.get("atual", {})
	if not at.is_empty():
		_rotulo("Hunt recomendada para o seu líder agora:", Color("c8b89a"))
		_rotulo("%s  (%s, nível %d)" % [String(at["nome"]), NOMES_AREA.get(String(at["area"]), String(at["area"])), int(at["nivel"])], Color.WHITE, 18)
		_rotulo("~%s XP/min estimado · %.1f abates/min · %s XP por abate" % [_n(float(at["xp_min"])), float(at["abates_min"]), _n(float(at["xp_abate"]))], Color("c8b89a"))
	var fp := frase_proxima(ultimo)
	if fp != "":
		_rotulo("Próxima meta: " + fp, Color("9fe0a0"))
	var rg: Dictionary = h.get("regiao", {})
	if not rg.is_empty():
		var mr: Dictionary = rg.get("melhor", {})
		var txt := "%s abre no treinador nível %d." % [NOMES_AREA.get(String(rg["area"]), String(rg["area"])), int(rg["nivel_treinador"])]
		if not mr.is_empty():
			txt += " Lá, o melhor para este líder hoje: %s (~%s XP/min)." % [String(mr["nome"]), _n(float(mr["xp_min"]))]
		_rotulo(txt, Color("c8b89a"))
	var mc: Dictionary = ultimo["marco"]
	if int(mc["proximo"]) > 0:
		var rot := String(mc["rotulo"])
		_rotulo("Treinador: nível %d → próximo marco %d%s" % [int(ultimo["nivel_treinador"]), int(mc["proximo"]), (" (" + rot + ")") if rot != "" else ""], Color.WHITE)
		var ini := float(Regras.xp_total_para_nivel(int(mc["anterior"])))
		var fim := float(Regras.xp_total_para_nivel(int(mc["proximo"])))
		_barra(float(ej.experiencia_treinador_acumulada) - ini, fim - ini)
		_rotulo("Faltam %s XP." % _n(float(ultimo["xp_falta"])), Color("c8b89a"))
	var co: Dictionary = ultimo["colecao"]
	var tco := "Coleção: %d espécies diferentes" % int(co["especies"])
	if int(co["proximo"]) > 0:
		tco += " (próximo marco: %d)" % int(co["proximo"])
	_rotulo(tco, Color.WHITE)
	_rotulo("Espécies das hunts liberadas: %d de %d" % [int(co["liberadas_capturadas"]), int(co["liberadas_total"])], Color("c8b89a"))
	_barra(float(co["liberadas_capturadas"]), float(co["liberadas_total"]))
	var fechar := Button.new()
	fechar.text = "Fechar"
	fechar.pressed.connect(hide)
	corpo.add_child(fechar)
	_ajustar()
