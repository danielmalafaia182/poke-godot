class_name EncontroSelvagem
extends RefCounted

# Uma instância por nascimento. O slot e o Sprite podem ser reutilizados;
# identidade, HP, recompensa e captura nunca são reutilizados no respawn.
signal vida_alterada
enum Estado { VIVO, DERROTADO, RESOLVIDO }
var _id: String = Crypto.new().generate_random_bytes(16).hex_encode()
var id: String:
	get: return _id
# Evolução: respawn recebe nova agenda; trocar o alvo não reinicia cooldowns.
var agenda_golpes: RefCounted = preload("res://agenda_golpes.gd").new()
var intervalo_ataque: float=-1.0 # <=0 usa o padrão da hunt; permite ritmo individual sem novo timer.
var primeiro_ataque_preparado: bool = false
var inicio_preparo_primeiro_ataque: float = -1.0
var prazo_primeiro_ataque: float = -1.0
var slot: int = -1
var pokemon: DadosPokemon
var _pokemon_combate: DadosPokemon
var _fonte_pokemon_combate: DadosPokemon
var _perfil_combate_id: String = ""
var perfil_combate_id: String:
	get: return _perfil_combate_id if _pokemon_combate!=null and pokemon==_fonte_pokemon_combate else ""
var perfil_combate_persistente: bool:
	get: return not perfil_combate_id.is_empty()
var imagem: Sprite2D
var perfil_hp: Dictionary = {}
var vida_maxima: int = 1
var _vida: int = 1
var _estado: Estado = Estado.VIVO
var estado: Estado:
	get: return _estado
var _recompensado: bool = false
var recompensado: bool:
	get: return _recompensado
var _captura_iniciada: bool = false
var captura_iniciada: bool:
	get: return _captura_iniciada
var vida: int:
	get: return _vida
	set(valor):
		if estado == Estado.RESOLVIDO:
			return
		var anterior: int=_vida
		_vida = clampi(valor, 0, vida_maxima)
		_estado = Estado.DERROTADO if _vida == 0 else Estado.VIVO
		if _vida!=anterior: vida_alterada.emit()
var ativo: bool:
	get: return estado != Estado.RESOLVIDO
var celula: Vector2i
var tempo_respawn: float = 0.0
var movendo: bool = false
var origem_movimento: Vector2i
var destino_movimento: Vector2i
var progresso_movimento: float = 0.0
var tempo_decisao: float = 0.0
# P04: motivo consultável quando este combatente não executa um golpe.
var diagnostico_ofensivo: Dictionary = {}

func _init(indice: int = -1, dados: DadosPokemon = null, sprite: Sprite2D = null,
		posicao: Vector2i = Vector2i.ZERO, hp_maximo: int = 1) -> void:
	slot = indice
	pokemon = dados
	imagem = sprite
	celula = posicao
	origem_movimento = posicao
	destino_movimento = posicao
	vida_maxima = maxi(1, hp_maximo)
	_vida = vida_maxima

# Perfil de combate e indivíduo capturável têm ciclos de vida distintos.
# Se uma fixture/subclasse substituir pokemon diretamente, usa a nova instância.
func obter_pokemon_combate() -> DadosPokemon:
	return _pokemon_combate if _pokemon_combate!=null and pokemon==_fonte_pokemon_combate else pokemon

func definir_perfil_combate(dados: DadosPokemon, identidade: String) -> void:
	_pokemon_combate=dados
	_fonte_pokemon_combate=pokemon
	_perfil_combate_id=identidade

func reservar_recompensa() -> bool:
	if estado != Estado.DERROTADO or recompensado:
		return false
	_recompensado = true
	return true

func iniciar_captura() -> bool:
	if estado != Estado.DERROTADO or captura_iniciada:
		return false
	_captura_iniciada = true
	return true

func resolver(intervalo: float) -> void:
	if estado == Estado.RESOLVIDO:
		return
	_estado = Estado.RESOLVIDO
	movendo = false
	tempo_respawn = maxf(0.0, intervalo)
