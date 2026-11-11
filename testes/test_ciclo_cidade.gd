extends SceneTree
## Fase 4, lote 1 — ciclo jogável de ponta a ponta com o save ISOLADO (rodar com testes/rodar.sh):
##   cidade → mapa-múndi → hunt do Rhydon (cena caca_sim, simulação acelerada, VIP ligado) → volta à cidade →
##   vender o loot ao Mark → comprar bolas e poções → curar com a Nurse Joy → evoluir (Geodude → Graveler com pedra) →
##   depositar (Pokémon na BOX e itens no depot) → save gravado e relido.
## Toda regra passa pelo serviço da cidade (sim/servico_cidade.gd) via EstadoJogo.

const ESPECIES: Script = preload("res://especies_importadas.gd")
const XP: Script = preload("res://sim/regras.gd")

var falhas := 0
var total := 0
var etapa := 0
var quadros := 0
var caca: Node
var venusaur: DadosPokemon
var geodude: DadosPokemon
var antes := {}


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _novo(nome: String, nivel: int, iv: int, q: float) -> DadosPokemon:
	var p := DadosPokemon.new()
	p.especie = ESPECIES.obter_especies()[nome]
	p.experiencia_total = XP.xp_total_para_nivel(nivel)
	for c in ["iv_hp", "iv_atk", "iv_def", "iv_sp_atk", "iv_sp_def", "iv_spd"]:
		p.set(c, iv)
	p.qualidade = q
	p.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
	p.normalizar_atributos()
	p.vida_atual = p.obter_vida_maxima()
	return p


func _initialize() -> void:
	var ej = get_root().get_node_or_null("EstadoJogo")
	checar(ej != null, "autoload EstadoJogo carregado (save isolado)", ProjectSettings.globalize_path("user://"))
	if ej == null:
		quit(1)
		return
	ej.iniciar_depot()
	venusaur = _novo("Venusaur", 120, 20, 0.835)
	geodude = _novo("Geodude", 40, 12, 1.1)
	var time: Array[DadosPokemon] = [venusaur, ej.pokemon_inicial, geodude]
	ej.colecao.time_pokemon = time
	ej.selecionar_lider(venusaur)
	ej.definir_perfil_treinador("Teste", 120)
	ej.definir_auto_potion(true)
	ej.inventario.estoque_pocoes[203] = 200
	ej.selecionar_pocao_auto_potion(0)
	ej.inventario.estoque_materiais[109] = 1           # 1 Rock Stone (receita do Geodude, hunt < 40: 1 de cada)
	ej.ouro = 0
	ej.vip = true                                      # E: opção ligada nesta corrida
	antes = {"ouro": ej.ouro, "bolas3": ej.obter_quantidade_bola(3), "small": ej.obter_quantidade_pocao(200)}
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	match etapa:
		0:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn" and quadros > 5:
				checar(ej.cidade_atual() == "cerulean", "na cidade: serviços de Cerulean")
				checar(ej.validar_evolucao(geodude).is_empty(), "Geodude Lv.40 pode evoluir em Cerulean (sem evoluir ainda)", ej.validar_evolucao(geodude))
				var mapa: Node = load("res://mapa_mundi.tscn").instantiate()
				current_scene.add_child(mapa)
				etapa = 1
				quadros = 0
		1:
			if quadros == 3:
				var mapa: Node = current_scene.get_child(current_scene.get_child_count() - 1)
				var reg := {}
				for r in mapa.catalogo:
					if String(r["name"]) == "Rhydon":
						reg = r
				mapa._selecionar_registro(reg)
				etapa = 2
				quadros = 0
		2:
			if current_scene != null and current_scene.scene_file_path == "res://caca_sim.tscn":
				caca = current_scene
				caca.velocidade = 30.0
				checar(bool(caca.sim.cfg.get("vip", false)), "VIP ligado chega na simulação (cfg.vip)")
				checar(ej.cidade_atual() == "", "na hunt não há cidade: os serviços recusam")
				checar(ej.curar_time().get("erro", "") != "", "Nurse Joy recusada durante a hunt")
				etapa = 3
				quadros = 0
			elif quadros > 300:
				checar(false, "cena da hunt abriu")
				return _fim()
		3:
			if caca.sim.tick >= int(240 * 1000 / 200) or caca._encerrada:
				var r: Dictionary = caca.registro
				checar(int(r["abates"]) > 0 and not (r["loot"] as Dictionary).is_empty(), "hunt: abates e loot", "%d abates" % int(r["abates"]))
				checar(int(r["xp_treinador"]) > 0, "XP do treinador ganha", str(r["xp_treinador"]))
				caca.voltar_cidade()
				etapa = 4
				quadros = 0
		4:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn" and quadros > 3:
				_ciclo_na_cidade(ej)
				return _fim()
			elif quadros > 300:
				checar(false, "voltou para a cidade")
				return _fim()
	return false


func _ciclo_na_cidade(ej) -> void:
	checar(venusaur.obter_vida_atual() < venusaur.obter_vida_maxima(), "Venusaur volta ferido (a hunt não cura)",
		"%d/%d" % [venusaur.obter_vida_atual(), venusaur.obter_vida_maxima()])
	# 1. vender o loot ao Mark
	var loja: Dictionary = ej.loja()
	var venda: Array = []
	var esperado := 0
	for it in loja["sell"]:
		if int(it["itemId"]) == 109 or int(it["itemId"]) in [200, 201, 202, 203, 204]:
			continue                                     # só o loot: a Rock Stone fica para a evolução e as poções ficam
		venda.append({"itemId": int(it["itemId"]), "qty": int(it["quantity"])})
		esperado += int(it["price"]) * int(it["quantity"])
	var vendido: Dictionary = ej.vender_itens(venda)
	checar(not vendido.has("erro") and int(vendido["goldGained"]) == esperado and ej.ouro == esperado and esperado > 0,
		"loot vendido ao Mark pelo npcPrice (C)", "+%d de ouro" % esperado)
	# 2. comprar bolas e poções
	var n_bolas := mini(20, ej.ouro / 2 / 50)
	var erro_b: String = ej.comprar_bola(3, maxi(1, n_bolas))
	var erro_p: String = ej.comprar_item(200, 5)
	checar(erro_b.is_empty() and ej.obter_quantidade_bola(3) == int(antes["bolas3"]) + maxi(1, n_bolas), "comprou Super Balls (50 cada)", erro_b)
	checar(erro_p.is_empty() and ej.obter_quantidade_pocao(200) >= int(antes["small"]) + 5, "comprou 5 Small Potions (5 cada)", erro_p)
	checar(ej.ouro == esperado - maxi(1, n_bolas) * 50 - 25, "ouro descontado", str(ej.ouro))
	# 3. curar
	var cura: Dictionary = ej.curar_time()
	checar(int(cura["quantidade"]) >= 1 and venusaur.obter_vida_atual() == venusaur.obter_vida_maxima(), "Nurse Joy curou o time, de graça (C)", str(cura))
	# 4. evoluir com pedra
	var hp_antes := geodude.obter_vida_maxima()
	var iv_antes := geodude.obter_total_ivs()
	var erro_e: String = ej.evoluir_pokemon(geodude, true)
	checar(erro_e.is_empty() and geodude.especie.nome == "Graveler" and geodude.nivel == 40 and geodude.obter_total_ivs() == iv_antes
		and ej.inventario.quantidade_item_bag(109) == 0 and geodude.obter_vida_maxima() > hp_antes,
		"Geodude → Graveler com a Rock Stone: mantém Lv.40 e os IVs; stats da base nova", "%s Lv.%d, %s" % [geodude.especie.nome, geodude.nivel, erro_e])
	# 5. depositar
	var erro_d: String = ej.mover_pokemon_depot(geodude, true)
	checar(erro_d.is_empty() and ej.pokemons_capturados.has(geodude) and not ej.time_pokemon.has(geodude), "Graveler guardado na BOX", erro_d)
	checar(not ej.mover_pokemon_depot(ej.pokemon_inicial, true).is_empty(), "o inicial não vai para a BOX (E)")
	var erro_i: String = ej.mover_item_depot(200, true)
	checar(erro_i.is_empty() and int(ej.itens_depot.get(200, 0)) > 0 and ej.obter_quantidade_pocao(200) == 0, "Small Potions guardadas no depot", erro_i)
	# 6. save gravado e relido
	checar(ej.salvar_agora() and not ej.erro_salvamento, "save (isolado) gravado", String(ej.aviso_salvamento))
	var texto := FileAccess.get_file_as_string("user://progresso_v1.json")
	var lido: Dictionary = preload("res://salvamento_local.gd").new().decodificar(texto)
	var d: Dictionary = lido.get("dados", {})
	var na_box := false
	for p in d.get("box", []):
		na_box = na_box or (p["id"] == geodude.id_persistente and p["especie"] == "Graveler" and int(p["nivel"]) == 40)
	checar(lido.has("dados") and int(d.get("ouro", -1)) == ej.ouro and bool(d.get("vip", false)) and na_box and int(d["depot"].get("200", 0)) > 0,
		"save relido: ouro, VIP, Graveler na BOX e poções no depot", str(lido.get("erro", "")))


func _fim() -> bool:
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
