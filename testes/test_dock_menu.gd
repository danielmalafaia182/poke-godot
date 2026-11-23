extends SceneTree
## Barra de menu (ciclo 4, item 8; C: a lista de 33 itens do dock do cliente, na mesma ordem). Save ISOLADO.
## Confere, na cidade: a ordem dos botões é a do cliente; nenhum botão fica desligado; cada um abre uma janela (a própria
## ou a janela com a identidade do original), o mapa ou a pokepedia; a dica é o nome do original (hud.world.menu.*).

const ORDEM := ["pokemon", "profile", "pokedex", "pokecards", "ranking", "bosses", "professions", "clans", "guild", "breeding",
	"home", "map", "patchnotes", "pokepedia", "pvp", "gyms", "inventory", "trade", "usedballs", "analyzer", "seasonpass", "quest",
	"streak", "sleep", "daily", "viplist", "mail", "store", "referral", "streams", "pip", "config", "logout"]   # C

var falhas := 0
var total := 0
var quadros := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	get_root().get_node("EstadoJogo").novo_jogo(1, "Teste", 3)
	change_scene_to_file("res://cidade.tscn")


func _visiveis(raiz: Node) -> Array:
	var r: Array = []
	for c in raiz.get_children():
		if c is Control and (c as Control).visible and String(c.name) in ["PainelPerfil", "PainelBolasUsadas", "PainelPokedex",
				"PainelInventario", "PainelGinasios", "PainelBosses", "PainelAlbum", "PainelStreak", "PainelDiarias", "JanelaOriginal",
				"MyPokes", "PokepediaLocal", "MapaMundi", "PainelConfig", "PainelProfissoes", "PainelBreeding"]:
			r.append(String(c.name))
	return r


func _fechar(raiz: Node) -> void:
	for c in raiz.get_children():
		if c is Control and String(c.name) in ["PainelPerfil", "PainelBolasUsadas", "PainelPokedex", "PainelInventario", "PainelGinasios",
				"PainelBosses", "PainelAlbum", "PainelStreak", "PainelDiarias", "JanelaOriginal", "MyPokes", "PokepediaLocal", "PainelConfig", "PainelProfissoes", "PainelBreeding"]:
			(c as Control).hide()


func _process(_d: float) -> bool:
	quadros += 1
	if current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	get_root().get_node("EstadoJogo").tutorial_passo = "fim"
	var raiz: Node = current_scene.get_node("Interface")
	var menu = raiz.get_node("MenuSuperior")
	var ordem: Array = []
	for b in menu.linha.get_children():
		ordem.append(String(b.name))
	checar(ordem == ORDEM, "33 itens na ordem do cliente", str(ordem.size()))
	var desligados: Array = []
	var sem_efeito: Array = []
	for k in ORDEM:
		var b: Button = menu.botoes[k]
		if b.disabled and k != "analyzer":   # o Hunt Analyser abre dentro da hunt
			desligados.append(k)
			continue
		if k in ["map", "home", "analyzer"]:
			continue   # o mapa e a volta à cidade trocam de cena/abrem o mapa; testados em test_mapa_hunts e test_ciclo_cidade
		_fechar(raiz)
		b.pressed.emit()
		if _visiveis(raiz).is_empty():
			sem_efeito.append(k)
	_fechar(raiz)
	checar(desligados.is_empty(), "nenhum botão do dock fica desligado", str(desligados))
	checar(sem_efeito.is_empty(), "cada botão abre uma janela", str(sem_efeito))
	checar(String(menu.botoes["sleep"].tooltip_text).begins_with("Modo Soneca") and String(menu.botoes["store"].tooltip_text) == "Diamantes",
		"dicas com os nomes do original (hud.world.menu.*)", String(menu.botoes["sleep"].tooltip_text))
	var jo = raiz.get_node("JanelaOriginal")
	menu.botoes["clans"].pressed.emit()
	checar(jo.visible and jo.titulo.text == "CLÃS" and jo.icone.texture != null and not jo.acao.visible, "Clãs: janela do original com o ícone e o aviso de online")
	jo.hide()
	menu.botoes["logout"].pressed.emit()
	checar(jo.visible and jo.acao.visible, "Sair: pede confirmação antes de fechar")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
