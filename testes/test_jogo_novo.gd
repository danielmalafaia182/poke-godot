extends SceneTree
## Jogo novo do zero (save novo, nada herdado), com save ISOLADO (testes/rodar.sh), passo a passo, como o começo do
## original (C): escolhe Bulbasaur → kit de 100 Small Potions e 100 Poké Balls, ouro 0, Cerulean → mapa → a hunt
## recomendada (Geodude) por 10 min simulados → volta → vende o loot ao Mark → compra Poké Balls → Nurse Joy → evolução
## (o Bulbasaur só evolui no nível 40). Imprime uma linha "PASSO" para cada etapa, com os números.
## Rodar: testes/rodar.sh res://testes/test_jogo_novo.gd

var falhas := 0
var total := 0
var etapa := 0
var quadros := 0
var caca: Node
var bulba: DadosPokemon
var registro := {}


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func passo(t: String) -> void:
	print("PASSO " + t)


func _initialize() -> void:
	change_scene_to_file("res://cidade.tscn")


func _novo_jogo(ej) -> void:
	checar(ej.salvamento.jogo_novo, "abriu sem save: jogo novo")
	passo("0. Sem save: o começo herdado do P04 é %s Lv.%d, %d Small Potions, %d Poké Balls, %d Super Balls" % [
		ej.pokemon_inicial.especie.nome, ej.pokemon_inicial.nivel, ej.obter_quantidade_pocao(200), ej.obter_quantidade_bola(1), ej.obter_quantidade_bola(3)])
	checar(ej.novo_jogo(25, "Ash", 7).has("erro"), "inicial fora dos três: recusa (C)")
	var r: Dictionary = ej.novo_jogo(1, "Ash", 7)
	bulba = ej.pokemon_inicial
	checar(not r.has("erro") and bulba.especie.nome == "Bulbasaur" and bulba.nivel == 1 and ej.time_pokemon.size() == 1 and ej.obter_lider() == bulba,
		"escolheu Bulbasaur: nível 1, sozinho no time e líder (C)", "Q %.3f, IV %d" % [bulba.qualidade, bulba.obter_total_ivs()])
	var outras := 0
	for id in [201, 202, 203, 204]:
		outras += ej.obter_quantidade_pocao(id)
	checar(ej.obter_quantidade_pocao(200) == 100 and outras == 0 and ej.obter_quantidade_bola(1) == 100 and ej.obter_quantidade_bola(3) == 0 and ej.ouro == 0,
		"kit: 100 Small Potions e 100 Poké Balls, nada mais; ouro 0 (C; ouro E)")
	checar(String(r["hunt_recomendada"]) == "geodude", "hunt recomendada para o Bulbasaur: Geodude (C, tutorial)")
	checar(ej.salvar_agora(), "save do jogo novo gravado", String(ej.aviso_salvamento))
	passo("1. Novo jogo: Bulbasaur Lv.1 (HP %d), 100 Small Potions, 100 Poké Balls, ouro 0; recomendada: Geodude" % bulba.obter_vida_maxima())


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	match etapa:
		0:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn" and quadros > 5:
				_novo_jogo(ej)
				checar(ej.cidade_atual() == "cerulean" and current_scene.get_node_or_null("Interface/PainelNovoJogo") == null,
					"na cidade (Cerulean); nos testes a tela de escolha não abre sozinha")
				passo("2. Cidade: Cerulean. Auto-Catch %s (bola %d), Auto-Potion %s" % [str(ej.auto_catch), int(ej.auto_catch_ball_id), str(ej.auto_potion)])
				current_scene.add_child(load("res://mapa_mundi.tscn").instantiate())
				etapa = 1
				quadros = 0
		1:
			if quadros == 3:
				var mapa: Node = current_scene.get_child(current_scene.get_child_count() - 1)
				var reg := {}
				for rr in mapa.catalogo:
					if String(rr["name"]) == "Geodude":
						reg = rr
				checar(not reg.is_empty(), "o mapa tem a hunt do Geodude")
				mapa._selecionar_registro(reg)
				etapa = 2
				quadros = 0
		2:
			if current_scene != null and current_scene.scene_file_path == "res://caca_sim.tscn":
				caca = current_scene
				caca.velocidade = 30.0
				etapa = 3
				quadros = 0
			elif quadros > 300:
				checar(false, "a hunt abriu")
				return _fim()
		3:
			if caca.sim.tick >= int(600 * 1000 / 200) or caca._encerrada:
				registro = caca.registro.duplicate(true)
				var st: Dictionary = caca.sim.estatisticas
				checar(int(registro["abates"]) > 0, "10 min na hunt do Geodude: abates", "%d abates" % int(registro["abates"]))
				passo("3. Hunt Geodude, 10 min: %d abates, %d capturas, %d KOs do aliado, %d curas, nível %d, XP do treinador %d, loot %s%s" % [
					int(registro["abates"]), int(st.get("capturas", 0)), int(st.get("kos", 0)), int(st.get("curas", 0)), bulba.nivel,
					int(registro["xp_treinador"]), str(registro["loot"]), " (a hunt acabou: sem reserva viva)" if caca._encerrada else ""])
				caca.voltar_cidade()
				etapa = 4
				quadros = 0
		4:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn" and quadros > 3:
				_cidade(ej)
				return _fim()
			elif quadros > 300:
				checar(false, "voltou para a cidade")
				return _fim()
	return false


func _cidade(ej) -> void:
	passo("4. De volta: Bulbasaur Lv.%d com %d/%d de HP; %d Small Potions e %d Poké Balls; %d Pokémon capturados" % [
		bulba.nivel, bulba.obter_vida_atual(), bulba.obter_vida_maxima(), ej.obter_quantidade_pocao(200), ej.obter_quantidade_bola(1), ej.pokemons_capturados.size()])
	var loja: Dictionary = ej.loja()
	var venda: Array = []
	for it in loja["sell"]:
		if not int(it["itemId"]) in [200, 201, 202, 203, 204]:
			venda.append({"itemId": int(it["itemId"]), "qty": int(it["quantity"])})
	var v: Dictionary = ej.vender_itens(venda) if not venda.is_empty() else {"goldGained": 0}
	checar(not v.has("erro") and ej.ouro > 0, "vendeu o loot ao Mark", "+%d de ouro" % int(v.get("goldGained", 0)))
	passo("5. Vendeu %d tipos de loot ao Mark: +%d de ouro" % [venda.size(), int(v.get("goldGained", 0))])
	var n := mini(10, ej.ouro / 5)
	var poke0: int = ej.obter_quantidade_bola(1)
	var eb: String = ej.comprar_bola(1, maxi(1, n)) if n > 0 else "sem ouro"
	checar(eb.is_empty() and ej.obter_quantidade_bola(1) == poke0 + n, "comprou %d Poké Balls (5 cada)" % n, eb)
	passo("6. Comprou %d Poké Balls por %d; sobrou %d de ouro" % [n, n * 5, ej.ouro])
	var cura: Dictionary = ej.curar_time()
	checar(bulba.obter_vida_atual() == bulba.obter_vida_maxima(), "Nurse Joy curou (de graça)", str(cura))
	passo("7. Nurse Joy: time curado de graça")
	var ev: String = ej.validar_evolucao(bulba)
	checar(not ev.is_empty(), "evolução: o Bulbasaur Lv.%d ainda não evolui" % bulba.nivel, ev)
	passo("8. Evolução: %s (Bulbasaur → Ivysaur exige nível 40, C/A: evolveLevel)" % ev)
	checar(ej.salvar_agora(), "save gravado", String(ej.aviso_salvamento))


func _fim() -> bool:
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
