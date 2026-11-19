extends SceneTree
var falhas: int = 0
var checks: int = 0
func checar(ok: bool, descricao: String) -> void:
	checks += 1
	if not ok:
		falhas += 1
		push_error(descricao)
func _initialize() -> void:
	call_deferred("executar")
func executar() -> void:
	var e: Node = root.get_node("EstadoJogo")
	var s: RefCounted = load("res://salvamento_local.gd").new()
	var anterior: Dictionary = s.decodificar(FileAccess.get_file_as_string("user://fixture_anterior.json"))["dados"]
	var atual: Dictionary = JSON.parse_string(JSON.stringify(s.construir_dados(e)))
	anterior.erase("salvo_em_unix")
	atual.erase("salvo_em_unix")
	checar(atual.get("materiais",{}).is_empty(),"save anterior inicia materiais vazios")
	atual.erase("materiais")
	checar(atual.has("experiencia_base_migracao"),"migração registra base sem alterar XP histórica")
	atual.erase("experiencia_base_migracao")
	# Campos opcionais das fases 3 e 4: um save anterior carrega com os padrões (medidor vazio, sem última hunt, ouro 0, VIP off).
	checar((atual.get("captura_medidor",{}) as Dictionary).is_empty() and String(atual.get("ultima_hunt","")) == "" and int(atual.get("ouro",0)) == 0 and not bool(atual.get("vip",false)),
		"campos novos (medidor, última hunt, ouro, VIP) entram com o padrão")
	# Fase 4, lote 2: Streak e soneca entram zerados num save anterior.
	checar(int((atual.get("streak",{}) as Dictionary).get("totalKills",0)) == 0 and ((atual.get("streak",{}) as Dictionary).get("spent",{}) as Dictionary).is_empty() and (atual.get("soneca",{}) as Dictionary).is_empty(),
		"campos do lote 2 (Streak, soneca) entram zerados")
	# Fase 4, item 3: diárias e boosts entram vazios num save anterior.
	checar((atual.get("diarias",{}) as Dictionary).is_empty() and (atual.get("boosts",[]) as Array).is_empty(), "campos do item 3 (diárias, boosts) entram vazios")
	checar((atual.get("itens_uso",{}) as Dictionary).is_empty(), "campo do lote 3 (itens de uso) entra vazio")
	checar((atual.get("ginasios",{}) as Dictionary).is_empty(), "campo do lote 4 (insígnias) entra vazio")
	checar(String(atual.get("hunt_ao_fechar","")) == "", "campo hunt ao fechar entra vazio")
	# Ciclo 2: garantia de pedra, log de capturas, tempo em caça e capturas totais entram vazios; Auto-Catch Shiny ligado
	# por padrão (decisão do usuário), bola 0 = a melhor que tiver.
	checar((atual.get("garantia_pedras",{}) as Dictionary).is_empty() and (atual.get("log_capturas",[]) as Array).is_empty()
		and int(atual.get("tempo_caca_s",0)) == 0 and int(atual.get("capturas_total",0)) == 0 and String(atual.get("tutorial","")) == "fim", "campos do ciclo 2 (garantia de pedra, log, tempo, capturas) entram vazios; tutorial dado como visto")
	var cfg_atual: Dictionary = atual.get("configuracoes",{})
	checar(bool(cfg_atual.get("auto_catch_shiny",false)) and int(cfg_atual.get("auto_catch_shiny_ball_id",-1)) == 0, "Auto-Catch Shiny entra ligado (ciclo 2)")
	cfg_atual.erase("auto_catch_shiny")
	cfg_atual.erase("auto_catch_shiny_ball_id")
	for campo in ["captura_medidor","ultima_hunt","ouro","vip","streak","soneca","diarias","boosts","itens_uso","ginasios","hunt_ao_fechar","garantia_pedras","log_capturas","tempo_caca_s","capturas_total","tutorial"]:
		atual.erase(campo)
	var esperado: Dictionary=anterior.duplicate(true)
	for registro in esperado["team"]:
		if registro["id"]!=esperado["inicial_id"]: continue
		var antigo_p: DadosPokemon=s._criar_pokemon(registro)
		if antigo_p.obter_total_ivs()!=6: continue
		var hp: int=antigo_p.obter_vida_atual()
		var maximo: int=antigo_p.obter_vida_maxima()
		var modelo: DadosPokemon=load("res://dados/pokemons/larvitar_inicial.tres")
		for campo in s.CAMPOS_IV:
			registro[campo]=modelo.get(campo)
			antigo_p.set(campo,modelo.get(campo))
		registro["vida_atual"]=0 if hp==0 else clampi(roundi(float(hp)/maxi(1,maximo)*antigo_p.obter_vida_maxima()),1,antigo_p.obter_vida_maxima())
	# Fase 4, item 2 (A, G4): bolas não ficam no depot; as do save anterior voltam para a BAG ao carregar.
	for chave in esperado.get("depot",{}).keys():
		if int(chave) in s.BOLAS:
			esperado["bolas"][chave]=int(esperado["bolas"].get(chave,0))+int(esperado["depot"][chave])
			esperado["depot"].erase(chave)
	# JSON representa todos os números da mesma forma na comparação estrutural.
	esperado=JSON.parse_string(JSON.stringify(esperado))
	for k in atual.keys() + esperado.keys():
		if JSON.stringify(atual.get(k)) != JSON.stringify(esperado.get(k)):
			print("  difere: ", k, "  atual=", JSON.stringify(atual.get(k)).left(200), "  esperado=", JSON.stringify(esperado.get(k)).left(200))
	checar(esperado==atual,"save preservado exceto IVs/HP do inicial migrado")
	checar(e.time_pokemon.size()==3 and e.pokemons_capturados.size()==2,"TEAM/BOX anteriores")
	checar(e.obter_lider()==e.time_pokemon[1],"identidade do líder anterior")
	checar(e.salvar_agora(),"grava com módulos novos")
	var id: String = e.obter_lider().id_persistente
	checar(s.carregar(e) and s.carregar(e),"recarrega duas vezes")
	checar(e.time_pokemon.size()==3 and e.pokemons_capturados.size()==2 and e.obter_lider().id_persistente==id,"não duplica e mantém líder")
	# Corrupção: principal quebrado, backup válido.
	var arquivo: FileAccess = FileAccess.open(s.caminho,FileAccess.WRITE)
	arquivo.store_string("corrompido")
	arquivo.close()
	var recuperador: RefCounted = load("res://salvamento_local.gd").new()
	checar(recuperador.carregar(e) and not recuperador.aviso.is_empty(),"recupera backup")
	checar(recuperador.salvar(e),"repara principal")
	# Campos opcionais de versões mais antigas ainda são aceitos.
	var antigo: Dictionary = anterior.duplicate(true)
	antigo.erase("lider_id")
	antigo.erase("perfil")
	antigo.erase("experiencia_treinador_acumulada")
	for grupo in ["team","box"]:
		for p in antigo[grupo]:
			for campo in ["vida_atual","experiencia_total","experiencia_percentual","versao_atributos"]:
				p.erase(campo)
	checar(s._validar(antigo)=="","campos opcionais preservados")
	s._restaurar(e,antigo)
	checar(e.obter_lider()==e.pokemon_inicial and e.time_pokemon.size()==3,"migração usa inicial sem perder coleção")
	# Duas cópias inválidas: não sobrescrever nenhuma.
	var invalido: RefCounted = load("res://salvamento_local.gd").new()
	invalido.caminho = "user://invalido.json"
	for sufixo in ["", ".bak"]:
		arquivo = FileAccess.open(invalido.caminho+sufixo,FileAccess.WRITE)
		arquivo.store_string("preservar")
		arquivo.close()
	checar(not invalido.carregar(e) and invalido.bloqueado and not invalido.salvar(e),"corrupção total suspende gravação")
	checar(FileAccess.get_file_as_string(invalido.caminho)=="preservar","bytes inválidos preservados")
	# I/O negado: não fingir sucesso.
	var io: RefCounted = load("res://salvamento_local.gd").new()
	io.caminho = "user://pasta_inexistente/progresso.json"
	checar(not io.salvar(e) and not io.erro.is_empty(),"falha de I/O reportada")
	# Validação da mesma identidade em recursos distintos.
	var duplicado: Dictionary = anterior.duplicate(true)
	duplicado["box"][0]["id"] = duplicado["team"][0]["id"]
	checar(not s._validar(duplicado).is_empty(),"save duplicado rejeitado")
	print("COMPATIBILIDADE: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
