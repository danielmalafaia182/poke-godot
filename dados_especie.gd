class_name DadosEspecie
extends Resource

@export var nome: String = ""
@export_storage var vida_maxima: int = 1
@export var textura: Texture2D
@export_storage var dano_base: int = 1

@export_group("Atributos base reais")
@export var base_hp: int=0
@export var base_atk: int=0
@export var base_def: int=0
@export var base_sp_atk: int=0
@export var base_sp_def: int=0
@export var base_speed: int=0
@export var tipo_primario: String=""
@export var tipo_secundario: String=""
func obter_base() -> Dictionary:
	if base_hp>0 and base_atk>0 and base_def>0 and base_sp_atk>0 and base_sp_def>0 and base_speed>0:
		return {"baseHp":base_hp,"baseAtk":base_atk,"baseDef":base_def,"baseSpAtk":base_sp_atk,"baseSpDef":base_sp_def,"baseSpeed":base_speed,"type1":tipo_primario,"type2":tipo_secundario}
	return load("res://regras_pokemon.gd").obter_base(nome)
