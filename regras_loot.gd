extends RefCounted
# Probabilidades do catálogo extraído. Rolagens independentes e quantidade uniforme
# são a política do protótipo offline; não afirmam reproduzir o RNG do servidor.
static var _dados: Dictionary = {}
static var _indice: Dictionary = {}
static func _carregar() -> void:
	if _dados.is_empty():
		_dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/referencias/loot_hunts.json"))
		for item in _dados["itens"]: _indice[int(item["id"])]=item

static func catalogo() -> Array[Dictionary]:
	_carregar()
	var itens: Array[Dictionary]=[]
	for item in _dados["itens"]: itens.append(item.duplicate(true))
	return itens
static func ids() -> Array[int]:
	var resultado: Array[int]=[]
	for item in catalogo(): resultado.append(int(item["id"]))
	return resultado
static func obter(id: int) -> Dictionary:
	_carregar()
	return _indice.get(id,{}).duplicate(true)
static func sortear(especie: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var resultado: Array[Dictionary]=[]
	_carregar()
	for item in _dados["especies"].get(especie,[]):
		var chance: float=clampf(float(item["chance_catalogo"])/100000.0,0,1)
		if chance<=0 or (chance<1 and rng.randf()>=chance): continue
		resultado.append({"itemId":int(item["id"]),"name":str(item["nome"]),"qty":rng.randi_range(int(item["minimo"]),int(item["maximo"])),"icon":item["icone"],"rare":item["raro"]})
	return resultado
