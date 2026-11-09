class_name PerfilTreinador
extends RefCounted

signal perfil_alterado
var nome_treinador: String = "Treinador"
var nivel_treinador: int = 1
var experiencia_treinador_acumulada: int = 0
# Curva local provisória: reutiliza a curva já extraída para Pokémon.
const CURVA=preload("res://regras_pokemon.gd")
var experiencia_base_migracao: int = 0
var progressao_inicializada: bool = false
func normalizar_progressao() -> void:
	if not progressao_inicializada:
		experiencia_base_migracao=maxi(0,CURVA.xp_total_para_nivel(nivel_treinador)-experiencia_treinador_acumulada)
		progressao_inicializada=true
	nivel_treinador=mini(100000,int(obter_progresso()["nivel"]))
func obter_progresso() -> Dictionary:
	var base: int=experiencia_base_migracao if progressao_inicializada else maxi(0,CURVA.xp_total_para_nivel(nivel_treinador)-experiencia_treinador_acumulada)
	var total: int=clampi(experiencia_treinador_acumulada+base,0,CURVA.xp_total_para_nivel(100001)-1)
	return CURVA.progresso(total)


func definir_perfil_treinador(nome: String, nivel: int) -> bool:
	nome = nome.strip_edges()
	if nome.is_empty() or nome.length() > 32 or nivel < 1 or nivel > 100000:
		return false
	normalizar_progressao()
	if nivel!=nivel_treinador:
		experiencia_base_migracao=CURVA.xp_total_para_nivel(nivel)-experiencia_treinador_acumulada
	nome_treinador = nome
	nivel_treinador = nivel
	perfil_alterado.emit()
	return true

func registrar_recompensa_treinador(quantidade: int) -> void:
	if quantidade <= 0:
		return
	normalizar_progressao()
	experiencia_treinador_acumulada += mini(quantidade,maxi(0,9007199254740991-experiencia_treinador_acumulada))
	normalizar_progressao()
	perfil_alterado.emit()
