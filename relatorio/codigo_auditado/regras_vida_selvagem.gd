extends RefCounted
# Compatível com24 HP máximos observados de Blastoise, não regra comprovada.
const FATOR_CANDIDATO: int=35
const MINIMO: int=120
static func calcular(pokemon: DadosPokemon,candidata: bool=true) -> int:
	if not candidata:return pokemon.obter_vida_maxima()*5
	var atributos: Dictionary=pokemon.obter_atributos()
	return maxi(MINIMO,int(atributos.get("hp",0))*FATOR_CANDIDATO)

static func detalhar(pokemon: DadosPokemon,candidata: bool=true) -> Dictionary:
	var r: Dictionary={"regra":"hp_selvagem_candidato_35_min120" if candidata else "hp_aliado_x5",
		"nivel_combate_local":pokemon.nivel,"nivel_combate_original_confirmado":false,
		"atributo_hp":pokemon.obter_atributos().get("hp",0),
		"hp_aliado":pokemon.obter_vida_maxima(),"hp_maximo_calculado":calcular(pokemon,candidata),
		"fator_atributo_hp":FATOR_CANDIDATO if candidata else 60,"minimo":MINIMO,
		"fidelidade_comprovada":false}
	r.make_read_only()
	return r
