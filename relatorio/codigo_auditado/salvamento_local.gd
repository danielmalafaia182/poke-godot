extends RefCounted

# Formato explícito de dados; não carrega scripts nem caminhos vindos do JSON.
const VERSAO: int = 1
const FORMATO: String = "poke-idle-progresso"
var ESPECIES: Dictionary:
	get: return preload("res://especies_importadas.gd").obter_especies()
const CAMPOS_IV: Array[String] = ["iv_hp", "iv_atk", "iv_def", "iv_sp_atk", "iv_sp_def", "iv_spd"]
const BOLAS: Array[int] = [1, 2, 3, 4, 5, 6, 7]
const POCOES: Array[int] = [200, 201, 202, 203, 204]
const MAX_BYTES: int = 8 * 1024 * 1024
var caminho: String = "user://progresso_v1.json"
var bloqueado: bool = false
var aviso: String = ""
var erro: String = ""
var encontrado: bool = false
var ultimo_valido: String = ""

func _inteiro(valor: Variant, minimo: int, maximo: int) -> bool:
	return (valor is int or valor is float) and is_finite(float(valor)) and float(valor) == floor(float(valor)) and float(valor) >= minimo and float(valor) <= maximo

func _numero(valor: Variant, minimo: float, maximo: float) -> bool:
	return (valor is int or valor is float) and is_finite(float(valor)) and float(valor) >= minimo and float(valor) <= maximo

func _id_valido(valor: Variant) -> bool:
	if not valor is String or valor.length() != 32:
		return false
	for letra in valor:
		if not "0123456789abcdef".contains(letra):
			return false
	return true

func _estoque_valido(dados: Variant, ids: Array[int], completo: bool) -> bool:
	if not dados is Dictionary or (completo and dados.size() != ids.size()):
		return false
	for chave in dados:
		if not chave is String or not chave.is_valid_int() or str(int(chave)) != chave or not ids.has(int(chave)):
			return false
		if not _inteiro(dados[chave], 0, 2147483647) or (not completo and int(dados[chave]) == 0):
			return false
	return true

func _validar(dados: Variant) -> String:
	if not dados is Dictionary:
		return "Estrutura principal inválida."
	for campo in ["team", "box", "inicial_id", "bolas", "pocoes", "depot", "configuracoes", "cidade"]:
		if not dados.has(campo):
			return "Campo obrigatório ausente: " + campo
	if not dados["team"] is Array or dados["team"].is_empty() or dados["team"].size() > 6 or not dados["box"] is Array:
		return "Composição do time ou da BOX inválida."
	if not _id_valido(dados["inicial_id"]):
		return "Identidade do inicial inválida."
	var vistos: Dictionary = {}
	var inicial_encontrado: bool = false
	for grupo in ["team", "box"]:
		for p in dados[grupo]:
			if not p is Dictionary or not _id_valido(p.get("id")) or vistos.has(p.get("id")):
				return "Identidade ausente ou duplicada de Pokémon."
			vistos[p["id"]] = true
			if not p.get("especie") is String or not ESPECIES.has(p["especie"]):
				return "Espécie desconhecida."
			if not _inteiro(p.get("nivel"), 1, 100000) or not _numero(p.get("qualidade"), 0.001, 1000.0):
				return "Nível ou qualidade inválidos."
			# Novo: campos opcionais preservam compatibilidade com saves anteriores.
			if p.has("vida_atual") and not _inteiro(p["vida_atual"],-1,1000000000):
				return "HP atual inválido."
			if p.has("experiencia_percentual") and not _numero(p["experiencia_percentual"],0.0,100.0):
				return "Experiência percentual inválida."
			# Novo: campos opcionais para migrar os saves anteriores.
			if p.has("experiencia_total") and not _inteiro(p["experiencia_total"],-1,preload("res://regras_pokemon.gd").xp_total_para_nivel(100001)-1):
				return "XP total inválido."
			if p.has("versao_atributos") and not _inteiro(p["versao_atributos"],0,1):
				return "Versão de atributos inválida."
			for campo in CAMPOS_IV:
				if not _inteiro(p.get(campo), 1, 32):
					return "IV inválido: " + campo
			if p["id"] == dados["inicial_id"]:
				if grupo != "team" or p["especie"] not in ["Larvitar","Pupitar","Tyranitar"]:
					return "Inicial ausente do time ou com espécie incorreta."
				inicial_encontrado = true
	if not inicial_encontrado:
		return "Inicial não encontrado no time."
	# Novo: campo opcional permite carregar saves anteriores sem perder o progresso.
	if dados.has("lider_id"):
		var lider_encontrado: bool = false
		for p in dados["team"]:
			if p["id"] == dados["lider_id"]:
				lider_encontrado = true
		if not _id_valido(dados["lider_id"]) or not lider_encontrado:
			return "Líder não pertence ao time."
	# Novo: contador opcional, compatível com saves anteriores.
	if dados.has("experiencia_treinador_acumulada") and not _inteiro(dados["experiencia_treinador_acumulada"],0,9007199254740991):
		return "XP acumulado do treinador inválido."
	if dados.has("experiencia_base_migracao") and not _inteiro(dados["experiencia_base_migracao"],-9007199254740991,9007199254740991):
		return "Base de progressão inválida."
	if dados.has("perfil"):
		var perfil: Variant = dados["perfil"]
		if not perfil is Dictionary or not perfil.get("nome") is String or perfil["nome"].strip_edges().is_empty() or perfil["nome"].length()>32 or not _inteiro(perfil.get("nivel"),1,100000):
			return "Perfil local inválido."
	var ids: Array[int] = BOLAS.duplicate()
	ids.append_array(POCOES)
	ids.append_array(preload("res://regras_loot.gd").ids())
	if dados.has("materiais") and not _estoque_valido(dados["materiais"],preload("res://regras_loot.gd").ids(),false):
		return "Materiais inválidos."
	if not _estoque_valido(dados["bolas"], BOLAS, true) or not _estoque_valido(dados["pocoes"], POCOES, true) or not _estoque_valido(dados["depot"], ids, false):
		return "Estoques inválidos."
	if dados["depot"].size() > 200 or dados["depot"].has("7"):
		return "Capacidade ou item vinculado inválidos no depot."
	var config: Variant = dados["configuracoes"]
	if not config is Dictionary:
		return "Configurações inválidas."
	for campo in ["auto_catch", "auto_potion"]:
		if not config.get(campo) is bool:
			return "Ativação inválida: " + campo
	if not _inteiro(config.get("auto_catch_ball_id"), 1, 7) or int(config["auto_catch_ball_id"]) == 5:
		return "Bola automática inválida."
	if not _inteiro(config.get("bola_selecionada"), 1, 7):
		return "Bola selecionada inválida."
	if not config.get("auto_catch_names") is String or config["auto_catch_names"].length() > 4096:
		return "Filtro de nomes inválido."
	if not _inteiro(config.get("auto_potion_threshold"), 0, 100) or not [25, 40, 50, 60, 75, 90].has(int(config["auto_potion_threshold"])):
		return "Limite de cura inválido."
	if not _inteiro(config.get("auto_potion_item_id"), 0, 204) or (int(config["auto_potion_item_id"]) != 0 and not POCOES.has(int(config["auto_potion_item_id"]))):
		return "Poção selecionada inválida."
	var cidade: Variant = dados["cidade"]
	if not cidade is Dictionary or cidade.get("mapa") != "cerulean" or not cidade.get("definida") is bool:
		return "Cidade inválida."
	if not _inteiro(cidade.get("x"), -10000, 10000) or not _inteiro(cidade.get("y"), -10000, 10000) or not _inteiro(cidade.get("direcao"), 0, 3):
		return "Posição ou direção inválida."
	return ""

func decodificar(texto: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(texto) != OK or not json.data is Dictionary:
		return {"erro": "JSON inválido."}
	var envelope: Dictionary = json.data
	if envelope.get("formato") != FORMATO or not _inteiro(envelope.get("versao"), 1, 2147483647):
		return {"erro": "Formato desconhecido."}
	if int(envelope["versao"]) != VERSAO:
		return {"erro": "Save de outra versão; arquivos preservados.", "outra_versao": true}
	if not envelope.get("conteudo") is String or not envelope.get("sha256") is String:
		return {"erro": "Envelope incompleto."}
	var conteudo: String = envelope["conteudo"]
	if conteudo.sha256_text() != envelope["sha256"]:
		return {"erro": "Verificação de integridade falhou."}
	if json.parse(conteudo) != OK:
		return {"erro": "Conteúdo inválido."}
	var validacao: String = _validar(json.data)
	if not validacao.is_empty():
		return {"erro": validacao}
	return {"dados": json.data}

func _ler(arquivo: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(arquivo, FileAccess.READ)
	if file == null:
		return {"erro": "Não foi possível abrir o arquivo."}
	if file.get_length() <= 0 or file.get_length() > MAX_BYTES:
		file.close()
		return {"erro": "Tamanho de arquivo inválido."}
	var texto: String = file.get_as_text()
	file.close()
	var resultado: Dictionary = decodificar(texto)
	resultado["texto"] = texto
	return resultado

func _criar_pokemon(dados: Dictionary) -> DadosPokemon:
	var pokemon: DadosPokemon = DadosPokemon.new()
	pokemon.id_persistente = dados["id"]
	pokemon.especie = ESPECIES[dados["especie"]] as DadosEspecie
	pokemon.nivel = int(dados["nivel"])
	pokemon.vida_atual = int(dados.get("vida_atual",-1))
	pokemon.experiencia_total = int(dados.get("experiencia_total",-1))
	pokemon.versao_atributos = int(dados.get("versao_atributos",0))
	pokemon.experiencia_percentual = float(dados.get("experiencia_percentual",0.0))
	pokemon.qualidade = float(dados["qualidade"])
	for campo in CAMPOS_IV:
		pokemon.set(campo, int(dados[campo]))
	pokemon.normalizar_atributos()
	return pokemon

func _restaurar(estado: Node, dados: Dictionary) -> void:
	# Só aplica depois de validar o documento inteiro.
	var time: Array[DadosPokemon] = []
	var box: Array[DadosPokemon] = []
	var inicial: DadosPokemon
	for registro in dados["team"]:
		var p: DadosPokemon = _criar_pokemon(registro)
		time.append(p)
		if p.id_persistente == dados["inicial_id"]:
			inicial = p
	for registro in dados["box"]:
		box.append(_criar_pokemon(registro))
	# Novo: perfil ausente em save antigo usa o padrão local, sem copiar a conta original.
	estado.experiencia_treinador_acumulada = int(dados.get("experiencia_treinador_acumulada",0))
	estado.nome_treinador = dados.get("perfil",{}).get("nome","Treinador")
	estado.nivel_treinador = int(dados.get("perfil",{}).get("nivel",1))
	estado.perfil.progressao_inicializada=dados.has("experiencia_base_migracao")
	estado.perfil.experiencia_base_migracao=int(dados.get("experiencia_base_migracao",0))
	estado.perfil.normalizar_progressao()
	estado.time_pokemon = time
	estado.pokemons_capturados = box
	estado.pokemon_inicial = inicial
	# Novo: saves antigos usam o inicial; saves novos restauram a identidade exata.
	estado.pokemon_lider = inicial
	for p in time:
		if p.id_persistente == dados.get("lider_id", dados["inicial_id"]):
			estado.pokemon_lider = p
	estado.estoque_bolas.clear()
	estado.estoque_pocoes.clear()
	estado.itens_depot.clear()
	estado.inventario.estoque_materiais.clear()
	for chave in dados.get("materiais",{}):
		estado.inventario.estoque_materiais[int(chave)]=int(dados["materiais"][chave])
	for chave in dados["bolas"]:
		estado.estoque_bolas[int(chave)] = int(dados["bolas"][chave])
	for chave in dados["pocoes"]:
		estado.estoque_pocoes[int(chave)] = int(dados["pocoes"][chave])
	for chave in dados["depot"]:
		estado.itens_depot[int(chave)] = int(dados["depot"][chave])
	for campo in dados["configuracoes"]:
		# Lista explícita; nunca atribui propriedades arbitrárias vindas do arquivo.
		if campo in ["auto_catch", "auto_catch_ball_id", "auto_catch_names", "bola_selecionada", "auto_potion", "auto_potion_threshold", "auto_potion_item_id"]:
			estado.set(campo, dados["configuracoes"][campo] if campo in ["auto_catch", "auto_potion", "auto_catch_names"] else int(dados["configuracoes"][campo]))
	estado.posicao_cidade_definida = dados["cidade"]["definida"]
	estado.celula_cidade_salva = Vector2i(int(dados["cidade"]["x"]), int(dados["cidade"]["y"]))
	estado.direcao_cidade_salva = int(dados["cidade"]["direcao"])

func carregar(estado: Node) -> bool:
	for arquivo in [caminho, caminho + ".bak", caminho + ".tmp"]:
		if not FileAccess.file_exists(arquivo):
			continue
		encontrado = true
		var resultado: Dictionary = _ler(arquivo)
		if resultado.get("outra_versao", false):
			bloqueado = true
			erro = resultado["erro"]
			return false
		if resultado.has("dados"):
			_restaurar(estado, resultado["dados"])
			ultimo_valido = resultado["texto"]
			if arquivo != caminho:
				aviso = "Progresso recuperado da cópia de segurança." if arquivo.ends_with(".bak") else "Progresso recuperado de uma gravação interrompida."
			return true
	if encontrado:
		bloqueado = true
		erro = "Não foi possível carregar o progresso nem a cópia. Arquivos preservados; salvamento suspenso."
		return false
	return true

func _serializar_pokemon(pokemon: DadosPokemon) -> Dictionary:
	pokemon.normalizar_atributos()
	if pokemon.id_persistente.is_empty():
		pokemon.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
	var dados: Dictionary = {"id": pokemon.id_persistente, "especie": pokemon.especie.nome if pokemon.especie != null else "", "nivel": pokemon.nivel, "qualidade": pokemon.qualidade, "vida_atual": pokemon.vida_atual, "experiencia_percentual": pokemon.experiencia_percentual, "experiencia_total": pokemon.experiencia_total, "versao_atributos": pokemon.versao_atributos}
	for campo in CAMPOS_IV:
		dados[campo] = pokemon.get(campo)
	return dados

func _estoque_json(dados: Dictionary) -> Dictionary:
	var resultado: Dictionary = {}
	for chave in dados:
		resultado[str(chave)] = dados[chave]
	return resultado

func construir_dados(estado: Node) -> Dictionary:
	estado.perfil.normalizar_progressao()
	var time: Array = []
	var box: Array = []
	for p in estado.time_pokemon:
		time.append(_serializar_pokemon(p))
	for p in estado.pokemons_capturados:
		box.append(_serializar_pokemon(p))
	return {
		# Novo: adição compatível ao formato v1, sem renomear campos anteriores.
		"experiencia_treinador_acumulada": estado.experiencia_treinador_acumulada,
		"experiencia_base_migracao": estado.perfil.experiencia_base_migracao,
		"perfil": {"nome": estado.nome_treinador,"nivel": estado.nivel_treinador},
		"team": time, "box": box, "inicial_id": estado.pokemon_inicial.id_persistente,
		"lider_id": estado.obter_lider().id_persistente,
		"materiais": _estoque_json(estado.inventario.estoque_materiais),
		"bolas": _estoque_json(estado.estoque_bolas), "pocoes": _estoque_json(estado.estoque_pocoes), "depot": _estoque_json(estado.itens_depot),
		"configuracoes": {"auto_catch": estado.auto_catch, "auto_catch_ball_id": estado.auto_catch_ball_id, "auto_catch_names": estado.auto_catch_names, "bola_selecionada": estado.bola_selecionada, "auto_potion": estado.auto_potion, "auto_potion_threshold": estado.auto_potion_threshold, "auto_potion_item_id": estado.auto_potion_item_id},
		"cidade": {"mapa": "cerulean", "definida": estado.posicao_cidade_definida, "x": estado.celula_cidade_salva.x, "y": estado.celula_cidade_salva.y, "direcao": estado.direcao_cidade_salva},
		"salvo_em_unix": int(Time.get_unix_time_from_system())
	}

func _escrever_temporario(arquivo: String, texto: String) -> bool:
	var file: FileAccess = FileAccess.open(arquivo, FileAccess.WRITE)
	if file == null:
		erro = "Não foi possível gravar o progresso (" + error_string(FileAccess.get_open_error()) + ")."
		return false
	file.store_string(texto)
	file.flush()
	var resultado: Error = file.get_error()
	file.close()
	if resultado != OK:
		erro = "A gravação do progresso falhou: " + error_string(resultado)
		return false
	var leitura: Dictionary = _ler(arquivo)
	if not leitura.has("dados") or leitura["texto"] != texto:
		erro = "Falha ao verificar o arquivo gravado."
		return false
	return true

func _promover(origem: String, destino: String) -> bool:
	var resultado: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(origem), ProjectSettings.globalize_path(destino))
	if resultado != OK:
		erro = "Não foi possível finalizar o salvamento: " + error_string(resultado)
		return false
	return true

func salvar(estado: Node) -> bool:
	if bloqueado:
		return false
	erro = ""
	var dados: Dictionary = construir_dados(estado)
	var validacao: String = _validar(dados)
	if not validacao.is_empty():
		erro = "Progresso não gravado: " + validacao
		return false
	var conteudo: String = JSON.stringify(dados)
	var texto: String = JSON.stringify({"formato": FORMATO, "versao": VERSAO, "sha256": conteudo.sha256_text(), "conteudo": conteudo}, "\t")
	if texto.to_utf8_buffer().size() > MAX_BYTES:
		erro = "O progresso excede o tamanho de arquivo suportado."
		return false
	if not _escrever_temporario(caminho + ".tmp", texto):
		return false
	# A cópia vem da última versão validada em memória, nunca de um principal corrompido.
	var copia: String = ultimo_valido if not ultimo_valido.is_empty() else texto
	if not _escrever_temporario(caminho + ".bak.tmp", copia) or not _promover(caminho + ".bak.tmp", caminho + ".bak"):
		return false
	if not _promover(caminho + ".tmp", caminho):
		return false
	ultimo_valido = texto
	encontrado = true
	return true
