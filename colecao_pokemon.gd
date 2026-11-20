class_name ColecaoPokemon
extends RefCounted

# TEAM/BOX são as mesmas instâncias vistas pelas cenas e pelo salvamento.
signal depot_alterado
signal lider_alterado
signal pokemon_alterado
signal individuo_alterado(pokemon: DadosPokemon)
signal alterado
const LIMITE_TIME: int = 6
# Evolução: contrato de entrada, antes de normalização e emissão de sinais.
const CONTRATO: Script = preload("res://contrato_pokemon.gd")
var time_pokemon: Array[DadosPokemon] = []
var pokemons_capturados: Array[DadosPokemon] = []
var pokemon_inicial: DadosPokemon
var pokemon_lider: DadosPokemon

func obter_lider() -> DadosPokemon:
	iniciar_depot()
	if pokemon_lider != null and time_pokemon.has(pokemon_lider):
		return pokemon_lider
	return pokemon_inicial

func selecionar_lider(pokemon: DadosPokemon) -> bool:
	if pokemon == null or pokemon.especie == null or not time_pokemon.has(pokemon):
		return false
	# Novo: rejeita espécies ainda sem animação, em vez de mostrar um sprite errado.
	if preload("res://visual_pokemon.gd").obter(pokemon.especie.nome).is_empty():
		return false
	if obter_lider() == pokemon:
		return true
	# A (vídeo do usuário, ciclo 5): o novo líder sobe para o 1º lugar do time e o antigo vai para o lugar dele.
	var i_novo := time_pokemon.find(pokemon)
	var i_lider := time_pokemon.find(pokemon_lider)
	if i_novo >= 0 and i_lider >= 0:
		time_pokemon[i_novo] = pokemon_lider
		time_pokemon[i_lider] = pokemon
	pokemon_lider = pokemon
	lider_alterado.emit()
	alterado.emit()
	return true

func iniciar_depot() -> void:
	if pokemon_inicial != null:
		return
	pokemon_inicial = (load("res://dados/pokemons/larvitar_inicial.tres") as DadosPokemon).duplicate() as DadosPokemon
	pokemon_inicial.normalizar_atributos()
	time_pokemon.append(pokemon_inicial)
	pokemon_lider = pokemon_inicial

func mover_pokemon_depot(pokemon: DadosPokemon, guardar: bool) -> String:
	iniciar_depot()
	var erro: String = CONTRATO.validar(pokemon)
	if not erro.is_empty():
		return erro
	if guardar:
		if pokemon == pokemon_inicial:
			return "O Pokémon inicial permanece no time e não pode ser depositado."
		if not time_pokemon.has(pokemon) or pokemons_capturados.has(pokemon):
			return "Este Pokémon não está no time."
		# Novo: depositar o líder devolve a liderança ao inicial protegido.
		if obter_lider() == pokemon:
			pokemon_lider = pokemon_inicial
			lider_alterado.emit()
		time_pokemon.erase(pokemon)
		pokemons_capturados.append(pokemon)
	else:
		if not pokemons_capturados.has(pokemon) or time_pokemon.has(pokemon):
			return "Este Pokémon não está na BOX."
		if time_pokemon.size() >= LIMITE_TIME:
			return "Time cheio: máximo de 6 Pokémon."
		pokemons_capturados.erase(pokemon)
		time_pokemon.append(pokemon)
	depot_alterado.emit()
	return ""

# Evolução: consulta sem mutações, compartilhada pelo registro e pela captura.
func validar_nova_captura(pokemon: DadosPokemon) -> String:
	var erro: String = CONTRATO.validar(pokemon)
	if not erro.is_empty():
		return erro
	if pokemons_capturados.has(pokemon) or time_pokemon.has(pokemon):
		return "Pokémon já pertence à coleção."
	for existente in time_pokemon + pokemons_capturados:
		if not pokemon.id_persistente.is_empty() and existente.id_persistente == pokemon.id_persistente:
			return "Identificador já pertence a outro Pokémon."
	return ""

func registrar_captura(pokemon: DadosPokemon) -> bool:
	if not validar_nova_captura(pokemon).is_empty():
		return false
	if pokemon.id_persistente.is_empty():
		pokemon.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
	pokemon.normalizar_atributos()
	pokemons_capturados.append(pokemon)
	depot_alterado.emit()
	return true

func registrar_vida_pokemon(pokemon: DadosPokemon, vida: int) -> void:
	if pokemon == null or pokemon.especie == null:
		return
	pokemon.normalizar_atributos()
	vida = clampi(vida,0,pokemon.obter_vida_maxima())
	if pokemon.vida_atual == vida:
		return
	pokemon.vida_atual = vida
	individuo_alterado.emit(pokemon)
	pokemon_alterado.emit()
	alterado.emit()

func conceder_experiencia(pokemon: DadosPokemon, quantidade: int) -> bool:
	if quantidade <= 0 or not time_pokemon.has(pokemon):
		return false
	pokemon.adicionar_experiencia(quantidade)
	individuo_alterado.emit(pokemon)
	pokemon_alterado.emit()
	alterado.emit()
	return true

func curar_time() -> Dictionary:
	var quantidade: int = 0
	var restaurado: int = 0
	for pokemon in time_pokemon:
		pokemon.normalizar_atributos()
		var faltante: int = pokemon.obter_vida_maxima()-pokemon.obter_vida_atual()
		if faltante <= 0:
			continue
		pokemon.vida_atual = pokemon.obter_vida_maxima()
		individuo_alterado.emit(pokemon)
		quantidade += 1
		restaurado += faltante
	if quantidade > 0:
		pokemon_alterado.emit()
		alterado.emit()
	return {"quantidade":quantidade,"hp":restaurado}

# Migração restrita ao inicial do protótipo; não modifica capturados com IVs legítimos.
func corrigir_inicial_prototipo() -> bool:
	if pokemon_inicial==null or pokemon_inicial.especie.nome!="Larvitar" or pokemon_inicial.obter_total_ivs()!=6: return false
	var p: DadosPokemon=pokemon_inicial
	var hp: int=p.obter_vida_atual()
	var maximo: int=p.obter_vida_maxima()
	var modelo: DadosPokemon=load("res://dados/pokemons/larvitar_inicial.tres")
	for campo in ["iv_hp","iv_atk","iv_def","iv_sp_atk","iv_sp_def","iv_spd"]: p.set(campo,modelo.get(campo))
	p.especie=modelo.especie
	p.vida_atual=0 if hp==0 else clampi(roundi(float(hp)/maxi(1,maximo)*p.obter_vida_maxima()),1,p.obter_vida_maxima())
	return true
