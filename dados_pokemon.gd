class_name DadosPokemon
extends Resource

@export var id_persistente: String = ""
@export var especie: DadosEspecie
@export var nivel: int = 1
# Novo: HP do último estado de combate; -1 significa indivíduo ainda não inicializado.
@export var vida_atual: int = -1
# Novo: -1 migra o nível/percentual anterior; a fonte de verdade passa a ser XP total.
@export var experiencia_total: int = -1
# Novo: saves antigos usam HP do protótipo até normalizar para o máximo calculado.
@export var versao_atributos: int = 0
const REGRAS: Script = preload("res://regras_pokemon.gd")
# Revisão: percentual derivado do XP total; campo preservado para compatibilidade com saves antigos.
@export_range(0.0,100.0,0.01) var experiencia_percentual: float = 0.0

func obter_vida_atual() -> int:
	return obter_vida_maxima() if vida_atual < 0 else clampi(vida_atual,0,obter_vida_maxima())

@export var iv_hp: int = 1
@export var iv_atk: int = 1
@export var iv_def: int = 1
@export var iv_sp_atk: int = 1
@export var iv_sp_def: int = 1
@export var iv_spd: int = 1

@export var qualidade: float = 1.0

func sortear_ivs() -> void:
	iv_hp = randi_range(1, 32)
	iv_atk = randi_range(1, 32)
	iv_def = randi_range(1, 32)
	iv_sp_atk = randi_range(1, 32)
	iv_sp_def = randi_range(1, 32)
	iv_spd = randi_range(1, 32)

func obter_total_ivs() -> int:
	return (iv_hp + iv_atk + iv_def + iv_sp_atk + iv_sp_def + iv_spd)
	
func obter_classificacao() -> String:
	
	if qualidade < 1.0:
		return "Weak"
	elif qualidade < 1.1:
		return "Common"
	elif qualidade < 1.3:
		return "Uncommon"
	elif qualidade < 1.5:
		return "Rare"
	elif qualidade < 1.7:
		return "Epic"
	elif qualidade < 2.0:
		return "Legendary"
	elif qualidade < 3.0:
		return "Mythic"
	elif qualidade < 4.0:
		return "Ancient"
	else:
		return "Divine"

func sortear_qualidade() -> void:
	var sorteio: int = randi_range(1, 10_000_000)
	
	if sorteio <= 500_000:
		qualidade = randi_range(800, 899) / 1000.0
	elif sorteio <= 1_000_000:
		qualidade = randi_range(900, 999) / 1000.0
	elif sorteio <= 4_403_846:
		qualidade = randi_range(1000, 1099) / 1000.0
	elif sorteio <= 6_403_846:
		qualidade = randi_range(1100, 1199) / 1000.0
	elif sorteio <= 7_403_846:
		qualidade = randi_range(1200, 1299) / 1000.0
	elif sorteio <= 8_403_846:
		qualidade = randi_range(1300, 1399) / 1000.0
	elif sorteio <= 9_403_846:
		qualidade = randi_range(1400, 1499) / 1000.0
	elif sorteio <= 9_903_846:
		qualidade = randi_range(1500, 1599) / 1000.0
	elif sorteio <= 9_971_154:
		qualidade = randi_range(1700, 1799) / 1000.0
	else:
		qualidade = 1.8

# Novo: métodos de atributos preservam os campos e nomes anteriores do recurso.
func obter_atributos() -> Dictionary:
	return REGRAS.calcular_atributos(self)

func obter_power() -> int:
	return REGRAS.calcular_power(self)

func obter_vida_maxima(modo_alternativo: bool = false) -> int:
	var atributos: Dictionary = obter_atributos()
	return REGRAS.vida_combate(int(atributos["hp"]),modo_alternativo) if not atributos.is_empty() else especie.vida_maxima

func sincronizar_experiencia() -> void:
	if experiencia_total < 0:
		# Migração: preserva o nível e aproxima a antiga porcentagem pelo XP inteiro.
		var minimo: int = REGRAS.xp_total_para_nivel(nivel)
		var proximo: int = REGRAS.xp_total_para_nivel(nivel+1)
		experiencia_total = minimo + mini(proximo-minimo-1,roundi(float(proximo-minimo)*experiencia_percentual/100.0))
	var progresso: Dictionary = REGRAS.progresso(experiencia_total)
	nivel = int(progresso["nivel"])
	experiencia_percentual = float(progresso["percentual"])

func normalizar_atributos() -> void:
	sincronizar_experiencia()
	if versao_atributos == 0:
		# Preserva a proporção de HP dos saves antigos; não cura um Pokémon derrotado.
		if vida_atual >= 0 and especie != null:
			vida_atual = roundi(clampf(float(vida_atual)/maxf(1.0,float(especie.vida_maxima)),0,1)*obter_vida_maxima())
		versao_atributos = 1

func adicionar_experiencia(quantidade: int) -> void:
	if quantidade <= 0:
		return
	sincronizar_experiencia()
	var anterior: int = nivel
	var teto: int = REGRAS.xp_total_para_nivel(100001)-1
	experiencia_total += mini(quantidade,maxi(0,teto-experiencia_total))
	sincronizar_experiencia()
	# Subir de nível não cura; mantém o HP absoluto e respeita o novo máximo.
	if anterior != nivel and vida_atual >= 0:
		vida_atual = mini(vida_atual,obter_vida_maxima())
