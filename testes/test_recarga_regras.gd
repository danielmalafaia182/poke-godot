extends SceneTree
## Recarga de verdade na composição do jogo: serviços existentes e tabelas em cache.
const RJ := preload("res://sim/regras_jogo.gd")
const Ponte := preload("res://ponte_cidade.gd")
var total := 0
var falhas := 0


func checar(ok: bool, nome: String) -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome)


func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var ej := root.get_node("EstadoJogo")
	ej.iniciar_depot()
	var mapa: Node = load("res://mapa_mundi.tscn").instantiate()
	root.add_child(mapa)
	for i in 4:
		await process_frame
	var nivel_original := _nivel_mapa(mapa, "rhydon")
	var gm := ej.get_node("PainelGM")
	var antigos := {}
	for nome in ["servico_jogador", "servico_diarias", "servico_itens", "servico_profissoes", "servico_breeding", "servico_golden_stars", "servico_pesca", "servico_bosses", "servico_cards", "servico_ginasios"]:
		antigos[nome] = ej.call(nome)
	var dados_antes = Ponte.dados()
	var cidade_antes = Ponte.servico()
	var xp_original := int(dados_antes.especie(246).xpAbate)
	RJ.criar_perfil("recarga")
	RJ.definir_perfil("recarga")
	RJ.gravar_valor("RegrasJogador", "streak_custo_base", 123)
	RJ.gravar_valor("RegrasDiarias", "kill_min_nivel", 99)
	RJ.gravar_alteracao("especies", {"id": 246, "campo": "xpAbate"}, 123456)
	RJ.gravar_alteracao("hunts", {"id": "rhydon", "campo": "nivel"}, 321)
	gm.recarregar_regras()
	checar(_nivel_mapa(mapa, "rhydon") == 321, "mapa já aberto recebe o nível alterado da hunt")
	for nome in antigos:
		checar(ej.call(nome) != antigos[nome], "recarga substitui " + nome)
	checar(Ponte.servico() != cidade_antes, "recarga substitui serviço da cidade")
	checar(Ponte.dados() != dados_antes and int(Ponte.dados().especie(246).xpAbate) == 123456, "a próxima hunt recebe a tabela nova")
	checar(int(dados_antes.especie(246).xpAbate) == xp_original, "snapshot de hunt em andamento permanece estável")
	checar(int(ej.servico_jogador().p.streak_custo_base) == 123 and int(ej.servico_diarias().p.kill_min_nivel) == 99, "serviços usam os valores novos")
	var estoque: Dictionary = ej.inventario.estoque_bolas.duplicate()
	checar(gm.dar_item("3", -5).contains("quantidade") and ej.inventario.estoque_bolas == estoque, "GM recusa quantidade negativa sem mutação")
	RJ.definir_perfil("original")
	gm.recarregar_regras()
	checar(_nivel_mapa(mapa, "rhydon") == nivel_original, "mapa já aberto volta ao nível original")
	checar(int(Ponte.dados().especie(246).xpAbate) == xp_original, "voltar ao original restaura os dados em execução")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)


func _nivel_mapa(mapa: Node, slug: String) -> int:
	for registro in mapa.catalogo:
		if registro.get("slug", "") == slug:
			return int(registro.level)
	return -1
