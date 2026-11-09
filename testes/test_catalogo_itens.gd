extends SceneTree
## Catálogo de itens migrado para o gerado (dados/gerados/itens.json): todo item existe no inventário, nada do catálogo
## antigo se perde e um save ANTIGO (dados/testes/save_antigo_inventario.json, gerado com o código de antes da
## migração) carrega com os mesmos materiais e depot. Save isolado (rodar com testes/rodar.sh).

const LOOT: Script = preload("res://regras_loot.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	call_deferred("executar")


func executar() -> void:
	var gerados: Array = JSON.parse_string(FileAccess.get_file_as_string("res://dados/gerados/itens.json"))
	var faltando := []
	for g in gerados:
		var id := int(g["id"])
		if id in LOOT.POCOES_DO_JOGO:
			continue
		var it: Dictionary = LOOT.obter(LOOT.id_interno(id))
		if it.is_empty() or String(it["nome"]) != String(g["nome"]):
			faltando.append(id)
	checar(faltando.is_empty(), "todos os itens do catálogo gerado existem no inventário (fora as 5 poções do jogo)",
		"%d itens; faltando %s" % [gerados.size() - 5, str(faltando.slice(0, 5))])
	var antigo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/referencias/loot_hunts.json"))
	var perdidos := []
	for it in antigo["itens"]:
		var n: Dictionary = LOOT.obter(int(it["id"]))
		if n.is_empty() or String(n["nome"]) != String(it["nome"]) or String(n["icone"]) != String(it["icone"]):
			perdidos.append(int(it["id"]))
	checar(perdidos.is_empty(), "os 183 itens do catálogo antigo continuam com o mesmo id, nome e ícone", str(perdidos.slice(0, 5)))
	checar(LOOT.id_interno(2) == 1000002 and LOOT.id_original(1000002) == 2 and LOOT.id_interno(39) == 39,
		"ids 1..7 do servidor viram 1000000 + id (convenção do save do P04)")

	# --- save antigo
	var e: Node = root.get_node("EstadoJogo")
	var s: RefCounted = load("res://salvamento_local.gd").new()
	var lido: Dictionary = s.decodificar(FileAccess.get_file_as_string("res://dados/testes/save_antigo_inventario.json"))
	checar(lido.has("dados"), "save antigo passa na validação com o catálogo novo", str(lido.get("erro", "")))
	if lido.has("dados"):
		s._restaurar(e, lido["dados"])
		var mat: Dictionary = e.inventario.estoque_materiais
		checar(int(mat.get(1000002, 0)) == 3 and int(mat.get(39, 0)) == 120 and int(mat.get(44417, 0)) == 1 and int(mat.get(120, 0)) == 55,
			"materiais do save antigo preservados", str(mat))
		checar(int(e.itens_depot.get(126, 0)) == 9 and int(e.itens_depot.get(1000004, 0)) == 2 and int(e.itens_depot.get(203, 0)) == 4,
			"depot do save antigo preservado", str(e.itens_depot))
	# --- Ancient Stone (id 2 do servidor) e um item só do catálogo gerado (Air Tank? não: 207 Medicine, categoria heal)
	var antes := int(e.inventario.estoque_materiais.get(1000002, 0))
	var r: Array = e.inventario.receber_loot([{"itemId": LOOT.id_interno(2), "qty": 1}, {"itemId": 207, "qty": 2}, {"itemId": 90130, "qty": 1}] as Array[Dictionary])
	checar(r.size() == 3 and int(e.inventario.estoque_materiais.get(1000002, 0)) == antes + 1 and int(e.inventario.estoque_materiais.get(207, 0)) == 2,
		"Ancient Stone e itens que só existem no catálogo gerado entram no inventário", str(r))
	var dados: Dictionary = s.construir_dados(e)
	checar(s._validar(dados) == "", "save com os itens novos passa na validação", s._validar(dados))
	var ida := JSON.stringify(dados)
	var volta: Dictionary = s.decodificar(JSON.stringify({"formato": s.FORMATO, "versao": s.VERSAO, "sha256": ida.sha256_text(), "conteudo": ida}))
	checar(volta.has("dados") and int(volta["dados"]["materiais"].get("207", 0)) == 2, "ida e volta do save mantém os itens novos")
	var icones_ok := 0
	var gifs := 0
	for it in LOOT.catalogo():
		if String(it["icone"]).ends_with(".gif"):
			gifs += 1
		elif LOOT.textura(String(it["icone"])) != null:
			icones_ok += 1
	print("ícones carregáveis: %d de %d (GIF, não lido pelo Godot: %d)" % [icones_ok, LOOT.catalogo().size(), gifs])
	checar(icones_ok + gifs == LOOT.catalogo().size(), "todo ícone que não é GIF carrega")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
