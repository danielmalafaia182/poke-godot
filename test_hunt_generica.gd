extends SceneTree
func _initialize() -> void: call_deferred("executar")
func executar() -> void:
 var estado: Node=root.get_node("EstadoJogo")
 estado.especie_caca=load("res://dados/especies/larvitar.tres")
 estado.auto_catch=true
 estado.auto_catch_names=""
 estado.auto_catch_ball_id=1
 estado.curar_time()
 var caca: Node=load("res://Caca.tscn").instantiate()
 root.add_child(caca)
 caca.set_process(false)
 caca.set_physics_process(false)
 await process_frame
 assert(caca.selvagens.size()==15)
 var encontro: EncontroSelvagem=caca.selvagens[0]
 assert(encontro.pokemon.especie.nome=="Larvitar")
 assert(encontro.imagem.recortes.size()==16)
 assert(encontro.imagem.quadros_por_direcao==4)
 assert(encontro.vida_maxima>0)
 caca.encontro_atual=encontro
 encontro.vida=0
 caca.batalha_encerrada=true
 caca._recompensar_derrota()
 var antes: int=estado.pokemons_capturados.size()
 caca.capturar()
 assert(estado.pokemons_capturados.size()==antes+1)
 assert(estado.pokemons_capturados.back().especie.nome=="Larvitar")
 print("HUNT GENERICA: 7 verificações; 0 falhas")
 quit()
