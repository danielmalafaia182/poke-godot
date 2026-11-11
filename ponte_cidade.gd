extends RefCounted
## Cliente dos serviços da cidade (fase 4, lote 1). A regra mora em sim/servico_cidade.gd; aqui só:
##   1. montar o estado do jogador no formato do serviço a partir do EstadoJogo (ids originais do servidor),
##   2. mandar o comando (offline: chamada direta, como a hunt; online: o mesmo comando iria pela ponte),
##   3. aplicar as mensagens de volta no EstadoJogo (como o cliente original aplica poke-delta/inventory/balls).
## Toda mensagem aplicada vem do serviço: este arquivo não decide preço, pedra, limite nem cura.

const Servico := preload("res://sim/servico_cidade.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const LOOT := preload("res://regras_loot.gd")
const ESPECIES := preload("res://especies_importadas.gd")
const POCOES := [200, 201, 202, 203, 204]

static var _dados = null
static var _servico = null
var ultimas_mensagens: Array = []


static func dados():
	if _dados == null:
		_dados = DadosJogo.carregar()
	return _dados


static func servico():
	if _servico == null:
		_servico = Servico.new(dados())
	return _servico


static func id_especie(nome: String) -> int:
	for id in dados().especies:
		if String(dados().especies[id].get("nome", "")) == nome:
			return int(id)
	return -1


static func _ivs(pk: DadosPokemon) -> Dictionary:
	return {"hp": pk.iv_hp, "atk": pk.iv_atk, "def": pk.iv_def, "spAtk": pk.iv_sp_atk, "spDef": pk.iv_sp_def, "speed": pk.iv_spd}


static func estado_de(ej: Node, cidade: String) -> Dictionary:
	ej.iniciar_depot()
	var pokes: Array = []
	var lider: DadosPokemon = ej.obter_lider()
	var i := 0
	for pk in ej.time_pokemon:
		pk.normalizar_atributos()
		pokes.append({"id": pk.id_persistente, "speciesId": id_especie(pk.especie.nome), "xp": pk.experiencia_total, "ivs": _ivs(pk),
			"quality": pk.qualidade, "hp": pk.vida_atual, "team": true, "slot": i, "leader": pk == lider, "starter": pk == ej.pokemon_inicial})
		i += 1
	for pk in ej.pokemons_capturados:
		pk.normalizar_atributos()
		if pk.id_persistente.is_empty():
			pk.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
		pokes.append({"id": pk.id_persistente, "speciesId": id_especie(pk.especie.nome), "xp": pk.experiencia_total, "ivs": _ivs(pk),
			"quality": pk.qualidade, "hp": pk.vida_atual, "team": false, "slot": -1, "leader": false, "starter": false})
	var itens := {}
	for id in POCOES:
		if int(ej.estoque_pocoes.get(id, 0)) > 0:
			itens[str(id)] = int(ej.estoque_pocoes[id])
	for id in ej.inventario.estoque_materiais:
		if int(ej.inventario.estoque_materiais[id]) > 0:
			itens[str(LOOT.id_original(int(id)))] = int(ej.inventario.estoque_materiais[id])
	var bolas := {}
	for id in ej.estoque_bolas:
		bolas[str(int(id))] = int(ej.estoque_bolas[id])
	var dep := {"itens": {}, "bolas": {}}
	for id in ej.itens_depot:
		var q := int(ej.itens_depot[id])
		if q <= 0:
			continue
		if not LOOT.obter(int(id)).is_empty():
			dep["itens"][str(LOOT.id_original(int(id)))] = q
		elif int(id) >= 200:
			dep["itens"][str(int(id))] = q
		else:
			dep["bolas"][str(int(id))] = q
	return {"gold": int(ej.ouro), "cidade": cidade, "vip": bool(ej.vip), "bola_selecionada": int(ej.bola_selecionada),
		"pokes": pokes, "itens": itens, "bolas": bolas, "depot": dep}


static func enviar(ej: Node, cidade: String, cmd: Dictionary) -> Array:
	var estado := estado_de(ej, cidade)
	var msgs: Array = servico().tratar(estado, cmd)
	aplicar(ej, msgs)
	return msgs


static func primeiro_erro(msgs: Array) -> String:
	for m in msgs:
		if String(m.get("type", "")) == "error":
			return String(m.get("message", "Erro."))
	return ""


# ============================================================================== aplicar mensagens

static func especie_por_id(id: int) -> DadosEspecie:
	var nome := String(dados().especie(id).get("nome", ""))
	return ESPECIES.obter_todas().get(nome)


static func aplicar(ej: Node, msgs: Array) -> void:
	var mudou_bolas := false
	var mudou_pocoes := false
	var mudou_depot := false
	var mudou_poke := false
	var mudou_lider := false
	var mudou_ouro := false
	var alterados: Array = []
	for m in msgs:
		match String(m.get("type", "")):
			"currency", "shop-bought", "shop-sold", "pokemon-sold":
				if m.has("gold") and int(m["gold"]) != int(ej.ouro):
					ej.ouro = int(m["gold"])
					mudou_ouro = true
			"balls":
				ej.ouro = int(m.get("gold", ej.ouro))
				for k in m.get("counts", {}):
					ej.estoque_bolas[int(k)] = int(m["counts"][k])
				mudou_bolas = true
			"inventory":
				var novos := {}
				for it in m.get("items", []):
					novos[int(it["itemId"])] = int(it["quantity"])
				for id in POCOES:
					ej.estoque_pocoes[id] = int(novos.get(id, 0))
				ej.inventario.estoque_materiais.clear()
				for id in novos:
					if not (int(id) in POCOES):
						ej.inventario.estoque_materiais[LOOT.id_interno(int(id))] = int(novos[id])
				mudou_pocoes = true
				mudou_depot = true
			"depot":
				ej.itens_depot.clear()
				for it in m.get("depot", []):
					var id := int(it["id"])
					ej.itens_depot[id if id in POCOES else LOOT.id_interno(id)] = int(it["quantity"])
				for b in m.get("balls", []):
					ej.itens_depot[int(b["ballId"])] = int(b["quantity"])
				mudou_depot = true
			"poke-delta":
				var r := _aplicar_poke(ej, m["poke"])
				if r != null:
					alterados.append(r)
					mudou_poke = true
					mudou_depot = true
					if bool(m["poke"].get("leader", false)) and ej.pokemon_lider != r:
						ej.pokemon_lider = r
						mudou_lider = true
			"pokes-removed":
				for id in m.get("ids", []):
					for pk in ej.pokemons_capturados.duplicate():
						if pk.id_persistente == String(id):
							ej.pokemons_capturados.erase(pk)
				mudou_depot = true
	# o líder precisa estar no time (o serviço já moveu a liderança ao depositar)
	if ej.pokemon_lider != null and not ej.time_pokemon.has(ej.pokemon_lider):
		ej.pokemon_lider = ej.pokemon_inicial
		mudou_lider = true
	for pk in alterados:
		ej.individuo_alterado.emit(pk)
	if mudou_bolas:
		ej.estoque_bolas_alterado.emit()
	if mudou_pocoes:
		ej.estoque_pocoes_alterado.emit()
	if mudou_lider:
		ej.lider_alterado.emit()
	if mudou_poke:
		ej.pokemon_alterado.emit()
	if mudou_ouro or mudou_bolas:
		ej.ouro_alterado.emit()
	if mudou_depot:
		ej.depot_alterado.emit()
	if mudou_ouro or mudou_poke or mudou_pocoes or mudou_bolas or mudou_depot or mudou_lider:
		ej.solicitar_salvamento()


static func _aplicar_poke(ej: Node, poke: Dictionary) -> DadosPokemon:
	var alvo: DadosPokemon = null
	for pk in ej.time_pokemon + ej.pokemons_capturados:
		if pk.id_persistente == String(poke["id"]):
			alvo = pk
	if alvo == null:
		return null
	var esp := especie_por_id(int(poke["speciesId"]))
	if esp != null and esp != alvo.especie:
		alvo.especie = esp
	alvo.experiencia_total = int(poke["xp"])
	alvo.sincronizar_experiencia()
	var hp := int(poke["hp"])
	alvo.vida_atual = -1 if hp >= alvo.obter_vida_maxima() else hp
	var no_time: bool = ej.time_pokemon.has(alvo)
	if bool(poke.get("team", false)) and not no_time:
		ej.pokemons_capturados.erase(alvo)
		ej.time_pokemon.insert(clampi(int(poke.get("slot", 99)), 0, ej.time_pokemon.size()), alvo)
	elif not bool(poke.get("team", false)) and no_time:
		ej.time_pokemon.erase(alvo)
		ej.pokemons_capturados.append(alvo)
	return alvo
