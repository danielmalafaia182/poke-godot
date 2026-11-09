extends SceneTree
func _initialize() -> void:call_deferred("executar")
func executar() -> void:
 var estado: Node=root.get_node("EstadoJogo")
 for i in range(5):await process_frame
 var p: DadosPokemon=estado.obter_lider()
 var antes: Array=[p.id_persistente,p.especie,p.nivel,p.experiencia_total,p.obter_vida_atual(),p.obter_total_ivs(),estado.nivel_treinador,estado.experiencia_treinador_acumulada]
 var cena: Control=load("res://laboratorio_combate.tscn").instantiate();root.add_child(cena)
 var r: Dictionary=cena.executar()
 assert(r["iv_total"]==173 and r["power_fixture"]==8 and r["hp_fixture"]==24)
 assert(r["atributos_fixture"]=={"hp":1,"atk":1,"def":2,"spAtk":1,"spDef":1,"speed":1})
 assert(r["previsto_local"]["tackle_causado"]==2 and r["previsto_legado"]["tackle_causado"]==1 and r["observado_original"]["tackle_causado"]==2)
 assert(not r["fidelidade_comprovada"])
 assert(is_equal_approx(r["hipoteses_temporais"]["intervalo1_5_tick200ms"][1],1.6))
 assert(is_equal_approx(r["hipoteses_temporais"]["intervalo2_tick200ms"][1],2.0))
 assert(antes==[p.id_persistente,p.especie,p.nivel,p.experiencia_total,p.obter_vida_atual(),p.obter_total_ivs(),estado.nivel_treinador,estado.experiencia_treinador_acumulada])
 cena._exportar()
 assert(FileAccess.file_exists("user://diagnosticos_combate/laboratorio_geodude.json"))
 print("LABORATORIO COMBATE: 8 verificações; 0 falhas")
 quit()
