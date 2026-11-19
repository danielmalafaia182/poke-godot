extends "res://janela_base.gd"
## Pokédex (C: window.pokedex; textos do pacote original). Espécies que aparecem em alguma hunt, com busca por nome ou
## número, filtro capturado/não capturado e por tipo, e o detalhe: tipos, nível da hunt, abates da espécie (Streak),
## evolução, stats base e se já capturou (normal/shiny). Contadores Capturados / Não capturados / Total.
## Fica de fora (E): o "Bônus de Captura +25% XP" por abates — o número de abates e o XP vêm do servidor, sem gravação.

const PONTE := preload("res://ponte_cidade.gd")
var busca := ""
var filtro := ""        # "", "cap", "nao"
var tipo := ""
var selecionado := -1


func _ready() -> void:
	tamanho = Vector2(760, 600)
	super._ready()


func especies() -> Array:
	## [{id, nome, tipos, nivel_hunt, capturado, shiny, abates}] em ordem de número.
	var ej: Node = get_node("/root/EstadoJogo")
	var dados = PONTE.dados()
	var nivel := {}
	for h in dados.hunts.values():
		for s in h.get("spawns", []):
			var id := int(s.get("pokeId", 0))
			nivel[id] = mini(int(nivel.get(id, 1 << 30)), int(h["nivel"]))
	var tem := {}
	var tem_sh := {}
	for pk in ej.time_pokemon + ej.pokemons_capturados:
		if pk != null and pk.especie != null:
			(tem_sh if pk.shiny else tem)[String(pk.especie.nome)] = true
	for e in ej.log_capturas:
		(tem_sh if bool(e.get("shiny", false)) else tem)[String(e.get("especie", ""))] = true
	var abates: Dictionary = ej.streak.get("bySpecies", {})
	var r: Array = []
	var ids := nivel.keys()
	ids.sort()
	for id in ids:
		var e: Dictionary = dados.especie(int(id))
		if e.is_empty():
			continue
		var nome := String(e["nome"])
		r.append({"id": int(id), "nome": nome, "tipos": e.get("tipos", []), "nivel_hunt": int(nivel[id]), "capturado": tem.has(nome) or tem_sh.has(nome),
			"shiny": tem_sh.has(nome), "abates": int(abates.get(str(int(id)), 0)), "esp": e})
	return r


func contagem() -> Dictionary:
	var l := especies()
	var c := 0
	for e in l:
		c += 1 if bool(e["capturado"]) else 0
	return {"capturados": c, "total": l.size()}


func montar() -> void:
	titulo.text = T.t("window.pokedex.title", {}, "Pokédex")
	var lista_toda := especies()
	var cont := contagem()
	rotulo("%s %d   ·   %s %d   ·   %s %d" % [T.t("window.pokedex.statsCaught"), cont["capturados"], T.t("window.pokedex.statsUncaught"),
		int(cont["total"]) - int(cont["capturados"]), T.t("window.pokedex.statsTotal"), cont["total"]], Color("f0c040"))
	var barra := HBoxContainer.new()
	corpo.add_child(barra)
	var campo := LineEdit.new()
	campo.name = "Busca"
	campo.placeholder_text = T.t("window.pokedex.searchPlaceholder")
	campo.text = busca
	campo.custom_minimum_size.x = 220
	campo.text_submitted.connect(func(t: String) -> void:
		busca = t
		atualizar())
	barra.add_child(campo)
	for par in [["cap", T.t("window.pokedex.caughtTag"), T.t("window.pokedex.filterCaughtTip")], ["nao", T.t("window.pokedex.notCaughtTag"), T.t("window.pokedex.filterUncaughtTip")]]:
		var b := Button.new()
		b.name = "Filtro_" + String(par[0])
		b.text = String(par[1])
		b.tooltip_text = String(par[2])
		b.toggle_mode = true
		b.button_pressed = filtro == par[0]
		var chave := String(par[0])
		b.pressed.connect(func() -> void:
			filtro = "" if filtro == chave else chave
			atualizar())
		barra.add_child(b)
	var tipos := OptionButton.new()
	tipos.name = "Tipo"
	tipos.add_item(T.t("window.pokedex.allTypes"))
	var todos := {}
	for e in lista_toda:
		for t in e["tipos"]:
			todos[String(t)] = true
	var tl := todos.keys()
	tl.sort()
	for t in tl:
		tipos.add_item(String(t).capitalize())
		if String(t) == tipo:
			tipos.select(tipos.item_count - 1)
	tipos.item_selected.connect(func(i: int) -> void:
		tipo = "" if i == 0 else String(tl[i - 1])
		atualizar())
	barra.add_child(tipos)
	if selecionado >= 0:
		_detalhe(lista_toda)
	var grade := GridContainer.new()
	grade.name = "Grade"
	grade.columns = 4
	corpo.add_child(grade)
	var n_vis := 0
	for e in lista_toda:
		if filtro == "cap" and not bool(e["capturado"]) or filtro == "nao" and bool(e["capturado"]):
			continue
		if tipo != "" and not (tipo in e["tipos"]):
			continue
		if busca != "" and String(e["nome"]).to_lower().find(busca.to_lower()) < 0 and str(int(e["id"])) != busca.trim_prefix("#"):
			continue
		n_vis += 1
		var b := Button.new()
		b.name = "P_%d" % int(e["id"])
		b.custom_minimum_size = Vector2(170, 0)
		b.text = "#%03d %s%s" % [int(e["id"]), String(e["nome"]), "  ✓" if bool(e["capturado"]) else ""]
		b.add_theme_color_override("font_color", Color.WHITE if bool(e["capturado"]) else Color("8a7f6a"))
		var id := int(e["id"])
		b.pressed.connect(func() -> void:
			selecionado = id
			atualizar())
		grade.add_child(b)
	if n_vis == 0:
		rotulo(T.t("window.pokedex.empty"), Color("c8b89a"))


func _detalhe(lista: Array) -> void:
	var e: Dictionary = {}
	for x in lista:
		if int(x["id"]) == selecionado:
			e = x
	if e.is_empty():
		return
	var esp: Dictionary = e["esp"]
	var caixa := PanelContainer.new()
	caixa.name = "Detalhe"
	corpo.add_child(caixa)
	var col := VBoxContainer.new()
	caixa.add_child(col)
	rotulo("#%03d %s  ·  %s  %s" % [int(e["id"]), String(e["nome"]), " / ".join(PackedStringArray((e["tipos"] as Array).map(func(t): return String(t).capitalize()))),
		T.t("window.pokedex.huntLevel", {"level": int(e["nivel_hunt"])})], Color.WHITE, 16, col)
	rotulo((T.t("window.pokedex.caughtTag") if bool(e["capturado"]) else T.t("window.pokedex.notCaughtTag")) + ("   ✨ " + T.t("window.pokedex.shinyPrefix") if bool(e["shiny"]) else ""),
		Color("9fe0a0") if bool(e["capturado"]) else Color("ff9a8a"), 0, col)
	rotulo(T.t("window.pokedex.killsProgress", {"kills": n(e["abates"]), "total": "—"}).replace("/—", ""), Color("c8b89a"), 0, col)
	var ev: Dictionary = esp.get("evolui", {}) if esp.get("evolui") is Dictionary else {}
	if not ev.is_empty():
		var alvo: Dictionary = PONTE.dados().especie(int(ev.get("para", 0)))
		rotulo(T.t("window.pokedex.evolvesTo", {"name": String(alvo.get("nome", "?"))}) + T.t("window.pokedex.evolveLevelSuffix", {"level": int(ev.get("nivel", 0))}), Color("c8b89a"), 0, col)
	else:
		rotulo(T.t("window.pokedex.noEvolve"), Color("c8b89a"), 0, col)
	var b: Dictionary = esp.get("base", {})
	var st := []
	for par in [["hp", "baseHp"], ["atk", "baseAtk"], ["def", "baseDef"], ["spAtk", "baseSpAtk"], ["spDef", "baseSpDef"], ["speed", "baseSpeed"]]:
		st.append("%s %d" % [T.t("window.pokedex.stat." + String(par[1])), int(b.get(par[0], 0))])
	rotulo(T.t("window.pokedex.statsTitle") + ":  " + "  ".join(PackedStringArray(st)), Color("c8b89a"), 0, col)
	botao(T.t("window.pokedex.back"), func() -> void:
		selecionado = -1
		atualizar(), "Voltar", col)
