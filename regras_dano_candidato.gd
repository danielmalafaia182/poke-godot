extends RefCounted
# Hipótese local apoiada por duas previsões físicas; não é fórmula comprovada.
# Preserva regras_dano.gd e seus consumidores V1/V2/laboratórios.
const DANO=preload("res://regras_dano.gd")
const VERSAO: String="atributos_candidato_v3_stab15_var085_100"
const MINIMO: float=0.85
const MAXIMO: float=1.0

static func tipos(p: DadosPokemon) -> Array[String]:
	var base: Dictionary=p.especie.obter_base()
	return [str(base.get("type1","")),str(base.get("type2",""))]

# Comparar golpes nunca consome RNG: usa multiplicador1, antes da variação.
static func nominal(a: DadosPokemon,d: DadosPokemon,g: Dictionary,selvagem: bool=false,nivel_formula: int=0) -> int:
	return int(_detalhar_pokemon(a,d,g,1.0,selvagem,nivel_formula)["dano"])

static func resolver(a: DadosPokemon,d: DadosPokemon,g: Dictionary,selvagem: bool,rng: RandomNumberGenerator,nivel_formula: int=0) -> Dictionary:
	var previa: Dictionary=_detalhar_pokemon(a,d,g,1.0,selvagem,nivel_formula)
	# Status/imunidade não produzem dano nem consomem a sequência de sorteios.
	if float(previa["bruto_sem_stab"])<=0:return previa
	return _detalhar_pokemon(a,d,g,rng.randf_range(MINIMO,MAXIMO),selvagem,nivel_formula)

# Substituição explícita só para selvagens; não muda Resource, IVs ou atributos.
static func _detalhar_pokemon(a: DadosPokemon,d: DadosPokemon,g: Dictionary,variacao: float,selvagem: bool,nivel_formula: int) -> Dictionary:
	var nivel_usado: int=nivel_formula if selvagem and nivel_formula>0 else a.nivel
	var resultado: Dictionary=detalhar_atributos(nivel_usado,a.obter_atributos(),d.obter_atributos(),tipos(a),g,DANO.efetividade(g,d),variacao,selvagem).duplicate()
	resultado["nivel_atributos"]=a.nivel
	resultado["nivel_formula"]=nivel_usado
	resultado["nivel_formula_substituido"]=nivel_usado!=a.nivel
	resultado["fonte_nivel_formula"]="substituicao_explicita_candidata" if selvagem and nivel_formula>0 else "nivel_pokemon"
	resultado["dano_v3_nivel_pokemon_mesma_variacao"]=detalhar_atributos(a.nivel,a.obter_atributos(),d.obter_atributos(),tipos(a),g,DANO.efetividade(g,d),variacao,selvagem)["dano"]
	resultado.make_read_only()
	return resultado

static func detalhar_atributos(nivel: int,a: Dictionary,d: Dictionary,tipos_atacante: Array[String],g: Dictionary,efetividade: float,variacao: float,selvagem: bool=false) -> Dictionary:
	var categoria: String=str(g.get("category","")).to_upper()
	var chave_a: String="spAtk" if categoria=="SPECIAL" else "atk"
	var chave_d: String="spDef" if categoria=="SPECIAL" else "def"
	var bruto: float=DANO.calcular_bruto_atributos(nivel,a,d,g,efetividade)
	var stab: float=1.0
	for tipo in tipos_atacante:
		if not tipo.is_empty() and tipo.to_upper()==str(g.get("type","")).to_upper():stab=1.5;break
	var multiplicador: float=clampf(variacao,MINIMO,MAXIMO) if is_finite(variacao) else MAXIMO
	var nominal_bruto: float=bruto*stab
	var final: float=nominal_bruto*multiplicador
	var r: Dictionary={"regra":VERSAO,"categoria":categoria,"nivel":nivel,
		"atributo_ataque":chave_a,"ataque_usado":a.get(chave_a,0),
		"atributo_defesa":chave_d,"defesa_usada":d.get(chave_d,0),
		"efetividade":efetividade,"bruto_sem_stab":bruto,"stab":stab,
		"nominal_bruto":nominal_bruto,"nominal":DANO.finalizar_dano(nominal_bruto,selvagem),
		"variacao":multiplicador,"bruto_final":final,"piso":1 if selvagem else 2,
		"dano":DANO.finalizar_dano(final,selvagem),
		"dano_v2_mesmos_atributos":DANO.finalizar_dano(bruto,selvagem),
		"fidelidade_comprovada":false}
	r.make_read_only()
	return r
