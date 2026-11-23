extends CanvasLayer
## Painel do Game Master no jogo (F12). Só existe em build de desenvolvimento ou com a opção ligada nas Configurações
## (⚙ → "Painel do Game Master (F12)", em user://config_tela.cfg). Ferramentas de teste e ajuste:
##   VIP; nível do treinador; nível do líder e do time; dar ouro; dar item (nome ou id); velocidade do tempo na hunt;
##   forçar shiny; pular as esperas (troca de líder, captura manual, pesca, bosses); perfil de regras e
##   "Recarregar regras" (relê os .tres de dados/regras/ e user://regras/ sem fechar o jogo).

const RJ := preload("res://sim/regras_jogo.gd")
const Regras := preload("res://sim/regras.gd")
const LOOT: Script = preload("res://regras_loot.gd")

var painel: PanelContainer
var aviso: Label
var perfil_op: OptionButton


static func habilitado() -> bool:
	if OS.is_debug_build():
		return true
	var c := ConfigFile.new()
	return c.load("user://config_tela.cfg") == OK and bool(c.get_value("tela", "gm", false))


static func definir_habilitado(v: bool) -> void:
	var c := ConfigFile.new()
	c.load("user://config_tela.cfg")
	c.set_value("tela", "gm", v)
	c.save("user://config_tela.cfg")


func _ej() -> Node:
	return get_node("/root/EstadoJogo")


func _ready() -> void:
	layer = 120
	painel = PanelContainer.new()
	painel.name = "PainelGM"
	painel.position = Vector2(20, 80)
	painel.visible = false
	add_child(painel)
	var v := VBoxContainer.new()
	painel.add_child(v)
	var t := Label.new()
	t.text = "🛠 Game Master (F12)"
	t.add_theme_font_size_override("font_size", 18)
	v.add_child(t)
	var vip := CheckButton.new()
	vip.name = "VIP"
	vip.text = "VIP"
	vip.button_pressed = bool(_ej().vip)
	vip.toggled.connect(func(x: bool) -> void:
		_ej().vip = x
		_ej().solicitar_salvamento()
		_avisar("VIP " + ("ligado" if x else "desligado")))
	v.add_child(vip)
	_linha_num(v, "NivelTreinador", "Nível do treinador", 1, 3000, func(n: int) -> void:
		_ej().experiencia_treinador_acumulada = Regras.xp_total_para_nivel(n)
		_ej().nivel_treinador = n
		_ej().solicitar_salvamento()
		_avisar("Treinador no nível %d" % n))
	_linha_num(v, "NivelLider", "Nível do líder", 1, 3000, func(n: int) -> void: _nivel_pokes(n, true))
	_linha_num(v, "NivelTime", "Nível do time", 1, 3000, func(n: int) -> void: _nivel_pokes(n, false))
	_linha_num(v, "Ouro", "Dar ouro", 1, 1000000000, func(n: int) -> void:
		_ej().ouro += n
		_ej().ouro_alterado.emit()
		_ej().solicitar_salvamento()
		_avisar("+%d de ouro" % n))
	var hi := HBoxContainer.new()
	v.add_child(hi)
	var item := LineEdit.new()
	item.name = "Item"
	item.placeholder_text = "item (nome ou id)"
	item.custom_minimum_size.x = 180
	hi.add_child(item)
	var qtd := SpinBox.new()
	qtd.name = "ItemQtd"
	qtd.min_value = 1
	qtd.max_value = 100000
	qtd.value = 10
	hi.add_child(qtd)
	var bi := Button.new()
	bi.name = "DarItem"
	bi.text = "Dar item"
	bi.pressed.connect(func() -> void: _avisar(dar_item(item.text.strip_edges(), int(qtd.value))))
	hi.add_child(bi)
	var hv := HBoxContainer.new()
	v.add_child(hv)
	var lv := Label.new()
	lv.text = "Velocidade do tempo (hunt)"
	hv.add_child(lv)
	var vel := OptionButton.new()
	vel.name = "Velocidade"
	for x in [1, 2, 5, 10, 30]:
		vel.add_item("%d×" % x)
	vel.item_selected.connect(func(i: int) -> void:
		var f: float = [1.0, 2.0, 5.0, 10.0, 30.0][i]
		_ej().set_meta("gm_velocidade", f)
		var cena := get_tree().current_scene
		if cena != null and "velocidade" in cena:
			cena.velocidade = f
		_avisar("Tempo %.0f× na hunt" % f))
	hv.add_child(vel)
	var shiny := CheckButton.new()
	shiny.name = "ForcarShiny"
	shiny.text = "Forçar shiny (espécies com forma shiny)"
	shiny.toggled.connect(func(x: bool) -> void:
		_ej().set_meta("gm_forcar_shiny", x)
		var cena := get_tree().current_scene
		if cena != null and "sim" in cena and cena.sim != null:
			cena.sim.p["shiny_chance"] = 1.0 if x else float(RJ.valores("RegrasCaptura").get("shiny_chance", 0.0))
		_avisar("Shiny forçado" if x else "Shiny normal"))
	v.add_child(shiny)
	var pular := Button.new()
	pular.name = "PularEsperas"
	pular.text = "Pular esperas (troca, captura, pesca, bosses)"
	pular.pressed.connect(func() -> void: _avisar(pular_esperas()))
	v.add_child(pular)
	var hp := HBoxContainer.new()
	v.add_child(hp)
	perfil_op = OptionButton.new()
	perfil_op.name = "Perfil"
	hp.add_child(perfil_op)
	var ativ := Button.new()
	ativ.text = "Ativar perfil"
	ativ.pressed.connect(func() -> void:
		RJ.definir_perfil(perfil_op.get_item_text(perfil_op.selected), true)
		_avisar(recarregar_regras()))
	hp.add_child(ativ)
	var rec := Button.new()
	rec.name = "Recarregar"
	rec.text = "Recarregar regras (.tres)"
	rec.pressed.connect(func() -> void: _avisar(recarregar_regras()))
	v.add_child(rec)
	aviso = Label.new()
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.custom_minimum_size.x = 360
	v.add_child(aviso)
	_perfis()


func _perfis() -> void:
	perfil_op.clear()
	for p in RJ.perfis():
		perfil_op.add_item(p)
		if p == RJ.perfil():
			perfil_op.select(perfil_op.item_count - 1)


func _linha_num(pai: Control, nome: String, rotulo: String, mn: int, mx: int, cb: Callable) -> void:
	var h := HBoxContainer.new()
	pai.add_child(h)
	var l := Label.new()
	l.text = rotulo
	l.custom_minimum_size.x = 150
	h.add_child(l)
	var s := SpinBox.new()
	s.name = nome
	s.min_value = mn
	s.max_value = mx
	s.value = mn
	h.add_child(s)
	var b := Button.new()
	b.name = nome + "Aplicar"
	b.text = "Aplicar"
	b.pressed.connect(func() -> void: cb.call(int(s.value)))
	h.add_child(b)


func _avisar(t: String) -> void:
	aviso.text = t


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F12:
		painel.visible = not painel.visible
		if painel.visible:
			_perfis()
		get_viewport().set_input_as_handled()


func _nivel_pokes(n: int, so_lider: bool) -> void:
	var ej := _ej()
	var alvos: Array = [ej.obter_lider()] if so_lider else ej.time_pokemon
	for pk in alvos:
		if pk == null:
			continue
		pk.experiencia_total = Regras.xp_total_para_nivel(n)
		pk.nivel = n
		pk.normalizar_atributos()
		pk.vida_atual = pk.obter_vida_maxima()
	ej.lider_alterado.emit()
	ej.solicitar_salvamento()
	_avisar("%s no nível %d" % ["Líder" if so_lider else "Time", n])


func dar_item(texto: String, qtd: int) -> String:
	var ej := _ej()
	var d = preload("res://ponte_cidade.gd").dados()
	var id := int(texto) if texto.is_valid_int() else -1
	if id < 0:
		for k in d.itens:
			if String(d.itens[k].get("nome", "")).to_lower() == texto.to_lower():
				id = int(k)
				break
	if id <= 0 or not d.itens.has(id) and not (id >= 1 and id <= 7):
		return "Item não encontrado: " + texto
	if id >= 200 and id <= 204:
		ej.inventario.estoque_pocoes[id] = int(ej.inventario.estoque_pocoes.get(id, 0)) + qtd
		ej.estoque_pocoes_alterado.emit()
	elif id >= 1 and id <= 7:
		ej.inventario.estoque_bolas[id] = int(ej.inventario.estoque_bolas.get(id, 0)) + qtd
		ej.estoque_bolas_alterado.emit()
	else:
		var k: int = LOOT.id_interno(id)
		ej.inventario.estoque_materiais[k] = int(ej.inventario.estoque_materiais.get(k, 0)) + qtd
	ej.solicitar_salvamento()
	return "+%d× %s" % [qtd, String(d.itens.get(id, {}).get("nome", "Ball %d" % id))]


func pular_esperas() -> String:
	var ej := _ej()
	var cena := get_tree().current_scene
	if cena != null and "sim" in cena and cena.sim != null:
		cena.sim.troca_manual_liberada_tick = 0
		cena.sim.set("_captura_manual_livre_ms", 0)
	if ej.pesca is Dictionary:
		ej.pesca["prox_ms"] = 0
	if ej.bosses is Dictionary and ej.bosses.has("recarga"):
		ej.bosses["recarga"] = {}
	return "Esperas zeradas"


func recarregar_regras() -> String:
	RJ.recarregar()
	var ej := _ej()
	for v in ["_servico_itens", "_servico_prof", "_servico_breed", "_servico_gs", "_servico_pesca"]:
		if v in ej:
			ej.set(v, null)
	return "Regras recarregadas (perfil %s). Valem já nos serviços da cidade e a partir da próxima hunt." % RJ.perfil()
