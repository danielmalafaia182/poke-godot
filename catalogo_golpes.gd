extends RefCounted

# Novo: consulta somente os dados recuperados; Power não é tratado como dano.
# attacks: creatures.json; efetividade: typeEffectiveness do módulo 251037 do cliente.
static var especies: Dictionary = {}
static var tipos: Dictionary = {}

static func _carregar() -> void:
	if especies.is_empty():
		especies = JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/golpes_originais.json"))
	if tipos.is_empty():
		tipos = JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/efetividade_original.json"))

static func obter(nome: String) -> Dictionary:
	_carregar()
	return especies.get(nome,{}).duplicate(true)

static func listar(nome: String, nivel: int, somente_disponiveis: bool = false) -> Array[Dictionary]:
	var dados: Dictionary = obter(nome)
	var resultado: Array[Dictionary] = []
	for registro in dados.get("attacks",[]):
		var golpe: Dictionary = registro.duplicate(true)
		# Observação do usuário no jogo original: Togepi Lv1 usa Last Resort.
		# Preserva o catálogo bruto e explicita a divergência do combate observado.
		if nome == "Togepi" and str(golpe["name"]) == "Last Resort":
			golpe["learnLevelCatalogo"] = int(golpe["learnLevel"])
			golpe["learnLevel"] = 1
			golpe["origemDisponibilidade"] = "observacao_usuario_original_lv1"
		if somente_disponiveis and int(golpe["learnLevel"]) > nivel:
			continue
		golpe["disponivel"] = nivel >= int(golpe["learnLevel"])
		resultado.append(golpe)
	resultado.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if int(a["learnLevel"]) == int(b["learnLevel"]):
			return str(a["name"]) < str(b["name"])
		return int(a["learnLevel"]) < int(b["learnLevel"])
	)
	return resultado

static func efetividade(tipo_golpe: String, primeiro: String, segundo: String = "") -> float:
	_carregar()
	var tabela: Dictionary = tipos.get(tipo_golpe.to_upper(),{})
	var a: String = primeiro.to_upper()
	var b: String = segundo.to_upper()
	var fator: float = float(tabela.get(a,1.0))
	if not b.is_empty() and b != a:
		fator *= float(tabela.get(b,1.0))
	return fator
