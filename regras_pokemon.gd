extends RefCounted

# Novo: tradução das funções computeStats/computePower/combatHp/totalXpForLevel/
# levelProgress do chunk original 0fllz2m_ktm3s.js, módulos 465165 e 251037.
# Não contém regra de concessão de XP pelo servidor nem cálculo de dano dos golpes.
const EXPOENTES: Dictionary = {"hp":0.95,"atk":0.8,"def":0.8,"spAtk":0.8,"spDef":0.8,"speed":0.95}
const CHAVES_BASE: Dictionary = {"hp":"baseHp","atk":"baseAtk","def":"baseDef","spAtk":"baseSpAtk","spDef":"baseSpDef","speed":"baseSpeed"}
const CAMPOS_IV: Dictionary = {"hp":"iv_hp","atk":"iv_atk","def":"iv_def","spAtk":"iv_sp_atk","spDef":"iv_sp_def","speed":"iv_spd"}
static var referencias: Dictionary = {}

static func obter_base(nome: String) -> Dictionary:
	if referencias.is_empty():
		referencias = JSON.parse_string(FileAccess.get_file_as_string("res://assets/interface/hud/atributos_base.json"))
	return referencias.get(nome,{})

static func calcular_atributos(pokemon: DadosPokemon) -> Dictionary:
	var base: Dictionary = pokemon.especie.obter_base()
	if base.is_empty():
		return {}
	var resultado: Dictionary = {}
	for chave in EXPOENTES:
		# Original: Math.round(level/100 * (base + 2*iv) * quality^exponent).
		resultado[chave] = roundi(float(pokemon.nivel)/100.0 * (float(base[CHAVES_BASE[chave]]) + 2.0*float(pokemon.get(CAMPOS_IV[chave]))) * pow(pokemon.qualidade,EXPOENTES[chave]))
	return resultado

static func calcular_power(pokemon: DadosPokemon) -> int:
	var total: int = 0
	for valor in calcular_atributos(pokemon).values():
		total += int(valor)
	return roundi(float(total) * pokemon.qualidade)

static func vida_combate(hp: int, modo_alternativo: bool = false) -> int:
	return maxi(24,roundi(float(hp) * (7.0 if modo_alternativo else 12.0)))

static func _curva_cubica(nivel: int) -> int:
	if nivel <= 1:
		return 0
	var n: float = float(nivel)
	return roundi(50.0/3.0 * (pow(n,3)-6.0*pow(n,2)+17.0*n-12.0))

static func xp_total_para_nivel(nivel: int) -> int:
	if nivel <= 150:
		return _curva_cubica(nivel)
	var t: float = float(nivel-150)
	if t <= 100.0:
		var triangular: float = t*(t+1.0)/2.0
		return roundi(float(_curva_cubica(150)) + 0.5*pow(triangular,2.0) + t*(t+1.0)*(2.0*t+1.0)/6.0*197.5 + triangular*25629.0 + 1087900.0*t)
	# Mantém a ordem em ponto flutuante do JavaScript inclusive em níveis muito altos.
	return roundi(float(xp_total_para_nivel(250)) + 2.0*(float(_curva_cubica(nivel))-float(_curva_cubica(250))))

static func progresso(xp: int) -> Dictionary:
	# Novo: busca binária limitada ao teto de nível já aceito pelo save do protótipo.
	var baixo: int = 1
	var alto: int = 100000
	var nivel: int = 1
	while baixo <= alto:
		var meio: int = (baixo+alto)/2
		if xp_total_para_nivel(meio) <= xp:
			nivel = meio
			baixo = meio+1
		else:
			alto = meio-1
	var atual: int = maxi(0,xp-xp_total_para_nivel(nivel))
	var necessario: int = maxi(1,xp_total_para_nivel(nivel+1)-xp_total_para_nivel(nivel))
	return {"nivel":nivel,"atual":atual,"necessario":necessario,"percentual":clampf(float(atual)*100.0/float(necessario),0,100)}
