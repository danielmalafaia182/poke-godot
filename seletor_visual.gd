extends VBoxContainer
## Escolha do visual do treinador (C: createCharacter "ESCOLHA SEU TREINADOR", Menino/Menina, e Perfil "Personalizar
## Outfit"; outfits do índice do snapshot, A; colorização e paleta de 133 cores do cliente, C, em render/outfits.gd).
## Livres: os outfits `trainer` coloríveis do gênero; VIP só com VIP; Gym Champion só para o Campeão dos Ginásios (C);
## Founder, Boss, premium e passe ficam de fora (são do servidor/loja).
## `visual` = {looktype, genero, cores {head, body, legs, feet}}; `alterado(visual)` a cada mudança.

signal alterado(visual: Dictionary)
const Outfits := preload("res://render/outfits.gd")
const T := preload("res://textos.gd")
const PARTES := [["head", "Cabeça"], ["body", "Corpo"], ["legs", "Pernas"], ["feet", "Pés"]]

var visual: Dictionary = {"looktype": 159, "genero": "male", "cores": {"head": 94, "body": 95, "legs": 0, "feet": 0}}
var vip := false
var campeao := false
var _outfits = null
var _preview: TextureRect
var _lista: OptionButton
var _opcoes: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	if _outfits == null:
		_outfits = Outfits.padrao()
	var titulo := Label.new()
	titulo.text = T.t("createCharacter.trainerTitle", {}, "ESCOLHA SEU TREINADOR")
	titulo.add_theme_color_override("font_color", Color("f0c040"))
	add_child(titulo)
	var h := HBoxContainer.new()
	add_child(h)
	_preview = TextureRect.new()
	_preview.name = "Preview"
	_preview.custom_minimum_size = Vector2(96, 96)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(_preview)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var gen := HBoxContainer.new()
	col.add_child(gen)
	for par in [["male", T.t("createCharacter.genderMale", {}, "Menino")], ["female", T.t("createCharacter.genderFemale", {}, "Menina")]]:
		var b := Button.new()
		b.name = "Genero_" + String(par[0])
		b.text = String(par[1])
		b.toggle_mode = true
		var g := String(par[0])
		b.pressed.connect(func() -> void:
			visual["genero"] = g
			_montar_lista(true))
		gen.add_child(b)
	_lista = OptionButton.new()
	_lista.name = "Outfit"
	_lista.item_selected.connect(func(i: int) -> void:
		visual["looktype"] = int(_opcoes[i])
		_atualizar())
	col.add_child(_lista)
	for par in PARTES:
		var linha := HBoxContainer.new()
		col.add_child(linha)
		var l := Label.new()
		l.text = String(par[1])
		l.custom_minimum_size.x = 64
		linha.add_child(l)
		var s := HSlider.new()
		s.name = "Cor_" + String(par[0])
		s.min_value = 0
		s.max_value = 132
		s.step = 1
		s.custom_minimum_size.x = 180
		s.value = int(visual["cores"].get(par[0], 0))
		var parte := String(par[0])
		s.value_changed.connect(func(v: float) -> void:
			visual["cores"][parte] = int(v)
			_atualizar())
		linha.add_child(s)
	_montar_lista(false)


func definir(v: Dictionary) -> void:
	if not v.is_empty():
		visual = v.duplicate(true)
	if is_inside_tree() and _lista != null:
		for par in PARTES:
			var s := find_child("Cor_" + String(par[0]), true, false) as HSlider
			if s != null:
				s.set_value_no_signal(int(visual["cores"].get(par[0], 0)))
		_montar_lista(false)


func opcoes(genero: String) -> Array:
	## Looktypes livres para o gênero (e os desbloqueados por VIP / campeão).
	if _outfits == null:
		_outfits = Outfits.padrao()
	var r: Array = []
	for k in _outfits._indice:
		var e: Dictionary = _outfits._indice[k]
		if String(e.get("kind", "")) != "trainer" or not bool(e.get("colorizable", false)) or String(e.get("gender", "")) != genero:
			continue
		var n := String(e.get("name", ""))
		if n.contains("Founder") or n.contains("Boss"):
			continue
		if n.contains("VIP") and not vip:
			continue
		if n.contains("Champion") and not campeao:
			continue
		r.append(int(k))
	r.sort()
	return r


func _montar_lista(trocou_genero: bool) -> void:
	_opcoes = opcoes(String(visual["genero"]))
	_lista.clear()
	for lt in _opcoes:
		_lista.add_item(String(_outfits.entrada(lt).get("name", str(lt))).replace("(Colorável)", "").strip_edges())
	if trocou_genero or not (int(visual["looktype"]) in _opcoes):
		visual["looktype"] = int(_opcoes[0]) if not _opcoes.is_empty() else 159
	_lista.select(maxi(0, _opcoes.find(int(visual["looktype"]))))
	for b in ["male", "female"]:
		var bt := find_child("Genero_" + b, true, false) as Button
		if bt != null:
			bt.set_pressed_no_signal(String(visual["genero"]) == b)
	_atualizar()


func _atualizar() -> void:
	var o: Dictionary = _outfits.obter(int(visual["looktype"]), visual["cores"])
	var q: Dictionary = _outfits.quadro(o, 3, 0)
	if not q.is_empty():
		var at := AtlasTexture.new()
		at.atlas = q["tex"]
		at.region = q["rect"]
		_preview.texture = at
	alterado.emit(visual.duplicate(true))
