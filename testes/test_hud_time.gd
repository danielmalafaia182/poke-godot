extends SceneTree
## Migrado do P04 (test_qualidade, parte da cena antiga) para a cena nova (ciclo 3): os cartões do time na HUD da hunt
## (caca_sim → hud_caca → painel_time) se atualizam por sinal sem ser recriados — HP e XP do líder, outro Pokémon
## intacto, cura da Nurse e poção refletidas nas barras, adição e remoção do time sem recriar os outros cartões.
## Save ISOLADO (testes/rodar.sh).

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	call_deferred("testar")


func _novo() -> DadosPokemon:
	var p := DadosPokemon.new()
	p.especie = load("res://dados/especies/geodude.tres")
	p.normalizar_atributos()
	return p


func testar() -> void:
	var ej: Node = root.get_node("EstadoJogo")
	ej.forcar_cidade = "cerulean"
	ej.curar_time()
	var extra := _novo()
	ej.registrar_captura(extra)
	ej.mover_pokemon_depot(extra, false)
	ej.slug_caca = "geodude"
	var caca: Node = load("res://caca_sim.tscn").instantiate()
	caca.trocar_de_cena_ao_sair = false
	root.add_child(caca)
	caca.set_process(false)
	for i in 4:
		await process_frame
	var painel = caca.hud_caca.painel_time
	var lider: DadosPokemon = ej.obter_lider()
	var c_lider = painel.cartoes[lider]
	var c_extra = painel.cartoes[extra]
	var ids: Array = []
	for f in painel.lista.get_children():
		ids.append(f.get_instance_id())
	var hp_id: int = c_lider.barra_hp.get_instance_id()
	var extra_hp: float = c_extra.barra_hp.value
	ej.registrar_vida_pokemon(lider, maxi(1, lider.obter_vida_maxima() / 2))
	ej.conceder_experiencia(lider, 50)
	await process_frame
	var ids2: Array = []
	for f in painel.lista.get_children():
		ids2.append(f.get_instance_id())
	checar(ids == ids2, "alterações de HP/XP mantêm todos os cartões (sem recriar)")
	checar(c_lider.barra_hp.get_instance_id() == hp_id and absf(c_lider.barra_hp.value - lider.obter_vida_atual()) < 1.5 or absf(c_lider.barra_hp.value * lider.obter_vida_maxima() / maxf(1.0, c_lider.barra_hp.max_value) - lider.obter_vida_atual()) < 2.0,
		"o cartão do líder mantém as barras e mostra o HP novo", "%.0f/%.0f" % [c_lider.barra_hp.value, c_lider.barra_hp.max_value])
	checar(c_extra.barra_hp.value == extra_hp, "não altera o outro Pokémon")
	ej.curar_time()
	await process_frame
	checar(lider.obter_vida_atual() == lider.obter_vida_maxima() and c_lider.barra_hp.value >= c_lider.barra_hp.max_value - 0.5, "Nurse Joy: cura refletida na barra")
	var outro := _novo()
	ej.registrar_captura(outro)
	ej.mover_pokemon_depot(outro, false)
	await process_frame
	checar(painel.cartoes.has(outro) and painel.cartoes[lider] == c_lider and painel.cartoes[extra] == c_extra, "adição ao time não recria os outros cartões")
	ej.mover_pokemon_depot(outro, true)
	await process_frame
	checar(not painel.cartoes.has(outro) and painel.cartoes[lider] == c_lider, "remoção preserva os restantes")
	caca.queue_free()
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
