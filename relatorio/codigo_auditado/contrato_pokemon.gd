extends RefCounted

# Evolução: valida entradas antes de alterar TEAM/BOX. Limites acompanham
# o formato de save atual; não são uma nova regra de atributos do original.
const CAMPOS_IV: Array[String] = ["iv_hp","iv_atk","iv_def","iv_sp_atk","iv_sp_def","iv_spd"]
static var ESPECIES: Dictionary:
	get: return preload("res://especies_importadas.gd").obter_especies()

static func validar(pokemon: DadosPokemon) -> String:
	if pokemon == null or pokemon.especie == null:
		return "Pokémon ou espécie indisponível."
	if not ESPECIES.has(pokemon.especie.nome):
		return "Espécie ainda não suportada pelo progresso local."
	if not pokemon.id_persistente.is_empty():
		if pokemon.id_persistente.length()!=32:
			return "Identificador do Pokémon inválido."
		for caractere in pokemon.id_persistente:
			if not "0123456789abcdef".contains(caractere):
				return "Identificador do Pokémon inválido."
	if pokemon.nivel < 1 or pokemon.nivel > 100000:
		return "Nível fora do limite do progresso local."
	if not is_finite(pokemon.qualidade) or pokemon.qualidade < 0.001 or pokemon.qualidade > 1000.0:
		return "Quality inválida."
	for campo in CAMPOS_IV:
		var valor: int = int(pokemon.get(campo))
		if valor < 1 or valor > 32:
			return "IV inválido: " + campo
	if pokemon.vida_atual < -1 or pokemon.vida_atual > 1000000000:
		return "HP inválido."
	var teto: int = preload("res://regras_pokemon.gd").xp_total_para_nivel(100001)-1
	if pokemon.experiencia_total < -1 or pokemon.experiencia_total > teto:
		return "XP total inválido."
	if not is_finite(pokemon.experiencia_percentual) or pokemon.experiencia_percentual < 0 or pokemon.experiencia_percentual > 100:
		return "Porcentagem de XP inválida."
	if pokemon.versao_atributos < 0 or pokemon.versao_atributos > 1:
		return "Versão de atributos inválida."
	return ""
