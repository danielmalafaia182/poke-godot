extends SceneTree
## Visual do treinador (ciclo 3; C: createCharacter e Perfil "Personalizar Outfit"; outfits A do snapshot). Save ISOLADO:
## seletor lista só os trainer coloríveis do gênero (VIP/Campeão travados); a cidade desenha o sprite pelo renderizador
## de outfits; o Perfil troca e o save guarda.

var falhas := 0
var total := 0
var quadros := 0
var etapa := 0
var sel: VBoxContainer


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var ej = get_root().get_node("EstadoJogo")
	ej.novo_jogo(74, "Teste", 3)
	ej.visual = {"looktype": 160, "genero": "female", "cores": {"head": 10, "body": 40, "legs": 70, "feet": 100}}
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	var ej = get_root().get_node("EstadoJogo")
	if etapa == 0:
		etapa = 1
		sel = load("res://seletor_visual.gd").new()
		current_scene.add_child(sel)
		return false
	if etapa == 1:
		etapa = 2
		var m: Array = sel.opcoes("male")
		var f: Array = sel.opcoes("female")
		var o = sel._outfits
		var nomes: Array = m.map(func(x): return String(o.entrada(x)["name"]))
		checar(m.has(159) and f.has(160) and not nomes.any(func(n): return n.contains("VIP") or n.contains("Champion") or n.contains("Founder")), "seletor: Trainer 159/160 livres; VIP, Campeão e Founder travados", "%d masc., %d fem." % [m.size(), f.size()])
		sel.campeao = true
		checar(sel.opcoes("male").has(3495), "Campeão dos Ginásios desbloqueia a Gym Champion Outfit (C)")
		(sel.find_child("Genero_female", true, false) as Button).pressed.emit()
		(sel.find_child("Cor_body", true, false) as HSlider).value = 40
		checar(String(sel.visual["genero"]) == "female" and int(sel.visual["looktype"]) in f and int(sel.visual["cores"]["body"]) == 40 and (sel.find_child("Preview", true, false) as TextureRect).texture != null, "Menina: outfit feminino, cor do corpo e prévia")
		sel.queue_free()
		var p = current_scene.personagem
		var tex: AtlasTexture = p.imagem.texture as AtlasTexture
		checar(tex != null and tex.atlas != preload("res://assets/interface/cidade/treinador.webp"), "cidade: o sprite vem do renderizador de outfits (não da textura fixa)")
		current_scene.get_node("Interface/MenuSuperior").botoes["profile"].pressed.emit()
		(current_scene.find_child("PersonalizarOutfit", true, false) as Button).pressed.emit()
		var pv: Control = current_scene.get_node("Interface/PainelVisual")
		checar(pv.visible, "Perfil → Personalizar Outfit abre o seletor")
		(pv.find_child("Genero_male", true, false) as Button).pressed.emit()
		var antes: Texture2D = p.imagem.texture
		(pv.find_child("SalvarVisual", true, false) as Button).pressed.emit()
		checar(String(ej.visual["genero"]) == "male" and p.imagem.texture != antes, "Salvar troca o visual e o sprite da cidade na hora")
		checar(ej.salvar_agora(), "save gravado")
		var sl = load("res://salvamento_local.gd").new()
		var d: Dictionary = sl.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json")).get("dados", {})
		checar(int(d.get("visual", {}).get("looktype", -1)) == int(ej.visual["looktype"]), "visual no save")
		print("RESULTADO: %d/%d" % [total - falhas, total])
		quit(1 if falhas else 0)
	return true
