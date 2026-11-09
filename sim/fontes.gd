extends RefCounted
## Localiza os dados que a simulação lê. Sem estado global; só caminhos e leitura de JSON.
##
## Snapshot do servidor (fonte A): variável de ambiente POKE_SNAPSHOT, senão a cópia dentro do projeto
## (`poke har/extraido/snapshot_2026-11-09`, ignorada pelo git e pelo Godot via .gdignore),
## senão o caminho antigo citado no CLAUDE.md.

const SNAPSHOT_RELATIVO := "poke har/extraido/snapshot_2026-11-09"
const SNAPSHOT_ALTERNATIVO := "C:/Users/dmala/Desktop/poke har/extraido/snapshot_2026-11-09"


static func raiz_projeto() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


static func pasta_snapshot() -> String:
	var env := OS.get_environment("POKE_SNAPSHOT")
	if env != "" and DirAccess.dir_exists_absolute(env):
		return env.replace("\\", "/").trim_suffix("/")
	var local := raiz_projeto() + "/" + SNAPSHOT_RELATIVO
	if DirAccess.dir_exists_absolute(local):
		return local
	if DirAccess.dir_exists_absolute(SNAPSHOT_ALTERNATIVO):
		return SNAPSHOT_ALTERNATIVO
	return ""


static func pasta_dados() -> String:
	return raiz_projeto() + "/dados"


static func ler_json(caminho: String) -> Variant:
	if not FileAccess.file_exists(caminho):
		push_error("Arquivo não encontrado: " + caminho)
		return null
	var texto := FileAccess.get_file_as_string(caminho)
	var dados: Variant = JSON.parse_string(texto)
	if dados == null:
		push_error("JSON inválido: " + caminho)
	return dados


static func ler_mapa(slug: String) -> Dictionary:
	var d: Variant = ler_json(pasta_snapshot() + "/game/maps/" + slug + ".json")
	return d if d is Dictionary else {}


static func ler_colisao() -> Dictionary:
	var d: Variant = ler_json(pasta_snapshot() + "/game/collision.json")
	return d if d is Dictionary else {}


static func ler_hunt_config(slug: String) -> Dictionary:
	var d: Variant = ler_json(pasta_snapshot() + "/api/hunt-config/" + slug + ".json")
	return d if d is Dictionary else {}
