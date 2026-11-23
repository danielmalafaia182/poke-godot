extends SceneTree
## Dock do Game Master (addons/game_master/dock.gd) fora do editor, com user:// isolado (testes/rodar.sh): monta sem
## erro, busca e filtra parâmetros, edita um valor num perfil novo, restaura, e a aba Tabelas acha o Larvitar com XP,
## preço, chance de captura e drops.

const RJ := preload("res://sim/regras_jogo.gd")

var falhas := 0
var total := 0
var q := 0
var dock


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	RJ.criar_perfil("dock", "original", true)
	RJ.definir_perfil("dock", true)
	dock = load("res://addons/game_master/dock.gd").new()
	get_root().add_child(dock)


func _contar(it: TreeItem) -> int:
	var n := 0
	var c := it.get_first_child() if it != null else null
	while c != null:
		n += 1 + _contar(c)
		c = c.get_next()
	return n


func _process(_d: float) -> bool:
	q += 1
	if q < 3:
		return false
	var arv: Tree = dock.arvore
	checar(arv != null and _contar(arv.get_root()) > 200, "dock montado: Resources e parâmetros na árvore", str(_contar(arv.get_root())))
	dock.busca.text = "stab"
	dock._preencher()
	checar(_contar(arv.get_root()) == 2, "busca 'stab': 1 Resource com 1 parâmetro")
	var it: TreeItem = arv.get_root().get_first_child().get_first_child()
	it.select(0)
	dock._selecionar()
	checar(dock.campo_valor.text == "1.5" and String(it.get_text(3)) != "", "valor atual 1.5, origem e status na linha", it.get_text(3) + " · " + it.get_text(4))
	dock.campo_valor.text = "2.0"
	# no editor o perfil vive em res://; aqui o teste usa o perfil de usuário isolado
	RJ.gravar_valor("RegrasCombate", "stab", 2.0, "dock", true)
	checar(float(RJ.valores("RegrasCombate")["stab"]) == 2.0, "editar: stab = 2.0 no perfil 'dock'")
	RJ.restaurar("RegrasCombate", "stab", "dock", true)
	checar(float(RJ.valores("RegrasCombate")["stab"]) == 1.5, "restaurar original: stab volta a 1.5")
	dock.busca.text = ""
	dock.sistema_op.select(1)
	dock._preencher()
	checar(_contar(arv.get_root()) > 1 and _contar(arv.get_root()) < 200, "filtro por sistema")
	dock.busca_tab.text = "larvitar"
	dock._preencher_tab()
	var g: TreeItem = dock.arvore_tab.get_root().get_first_child()
	var campos: Array = []
	var c := g.get_first_child() if g != null else null
	while c != null:
		campos.append(c.get_text(0))
		c = c.get_next()
	checar(g != null and String(g.get_text(0)).begins_with("Larvitar") and "xpAbate" in campos and "precoNpc" in campos and String(g.get_text(1)).contains("Super Ball")
		and campos.any(func(x): return String(x).begins_with("drop ")), "Tabelas: Larvitar com XP, preço, chance de captura e drops", str(campos.slice(0, 6)))
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
