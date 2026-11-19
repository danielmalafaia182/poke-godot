extends "res://janela_base.gd"
## Álbum de Pokécards (C: window.pokeCardAlbum; textos do pacote original; cartas A do snapshot). Só desenha e manda
## "abrir pacote": o sorteio é em sim/servico_cards.gd (EstadoJogo.album_comando).

var set_atual := ""
var filtro := ""   # "", "tem", "falta"
var ultimo: Array = []


func _ready() -> void:
	tamanho = Vector2(780, 640)
	super._ready()


func abrir_pacotes(qtd: int) -> Dictionary:
	var r: Dictionary = get_node("/root/EstadoJogo").album_comando({"type": "pack-abrir", "qtd": qtd, "agora": int(Time.get_unix_time_from_system())})
	ultimo = r.get("cartas", [])
	atualizar()
	return r


func montar() -> void:
	var ej: Node = get_node("/root/EstadoJogo")
	var info: Dictionary = ej.album_comando({"type": "album-get"})
	titulo.text = T.t("window.pokeCardAlbum.title", {}, "Álbum de Pokécards")
	var tot := int(info["total"])
	var tem := int(info["obtidas"])
	rotulo("%s: %d/%d (%s)  ·  %s: %d" % [T.t("window.pokeCardAlbum.progressLabel"), tem, tot, T.t("window.pokeCardAlbum.progressPct", {"pct": int(round(100.0 * tem / maxi(1, tot)))}),
		T.t("window.pokeCardAlbum.packsAvailLabel"), int(info["packs"])], Color("f0c040"))
	var h := HBoxContainer.new()
	corpo.add_child(h)
	var b1 := botao(T.t("window.pokeCardAlbum.openPack"), func() -> void: abrir_pacotes(1), "AbrirPacote", h)
	b1.tooltip_text = T.t("window.pokeCardAlbum.openPackTip")
	b1.disabled = int(info["packs"]) <= 0
	var b10 := botao(T.t("window.pokeCardAlbum.openPackCount", {"count": mini(10, int(info["packs"]))}), func() -> void: abrir_pacotes(10), "AbrirPacote10", h)
	b10.disabled = int(info["packs"]) <= 1
	if int(info["packs"]) <= 0:
		rotulo(T.t("window.pokeCardAlbum.noPacks"), Color("8a7f6a"), 0, h)
	if not ultimo.is_empty():
		rotulo(T.t("window.pokeCardAlbum.latest") + ": " + ", ".join(PackedStringArray(ultimo.map(func(c): return ("✨ " if bool(c["nova"]) else "") + "%s (%s)" % [String(c["name"]), String(c["rarity"]).replace("_", " ")]))), Color("ffe080"))
	var barra := HBoxContainer.new()
	corpo.add_child(barra)
	for s in [{"key": "", "short": T.t("window.pokeCardAlbum.allSets")}] + (info["sets"] as Array):
		var bs := Button.new()
		bs.text = String(s.get("short", s.get("key", "")))
		bs.toggle_mode = true
		bs.button_pressed = set_atual == String(s["key"])
		var k := String(s["key"])
		bs.pressed.connect(func() -> void:
			set_atual = k
			atualizar())
		barra.add_child(bs)
	for par in [["tem", T.t("window.pokeCardAlbum.ownedLabel")], ["falta", T.t("window.pokeCardAlbum.notOwned")]]:
		var bf := Button.new()
		bf.name = "Filtro_" + String(par[0])
		bf.text = String(par[1])
		bf.toggle_mode = true
		bf.button_pressed = filtro == par[0]
		var fk := String(par[0])
		bf.pressed.connect(func() -> void:
			filtro = "" if filtro == fk else fk
			atualizar())
		barra.add_child(bf)
	var grade := GridContainer.new()
	grade.name = "Grade"
	grade.columns = 5
	corpo.add_child(grade)
	var al: Dictionary = info["album"]
	var n := 0
	for c in ej.servico_cards().cartas:
		if set_atual != "" and String(c["set"]) != set_atual:
			continue
		var e: Dictionary = al.get(str(int(c["id"])), {})
		var possui := not e.is_empty()
		if (filtro == "tem" and not possui) or (filtro == "falta" and possui):
			continue
		n += 1
		var l := rotulo(("%s ×%d" % [String(c["name"]), int(e["qtd"])]) if possui else "#%d ???" % int(c["num"]), Color.WHITE if possui else Color("5a554a"), 0, grade)
		l.name = "C_%d" % int(c["id"])
		l.custom_minimum_size.x = 140
		l.tooltip_text = (T.t("window.pokeCardAlbum.cellTipQty", {"name": String(c["name"]), "no": int(c["num"]), "rarity": String(c["rarity"]), "count": int(e["qtd"])}) if possui
			else T.t("window.pokeCardAlbum.cellTipMissing", {"name": "?", "no": int(c["num"])}))
		l.mouse_filter = Control.MOUSE_FILTER_STOP
	if n == 0:
		rotulo(T.t("window.pokeCardAlbum.empty"), Color("8a7f6a"))
