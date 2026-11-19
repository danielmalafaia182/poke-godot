extends RefCounted
## Localiza os dados que a simulação lê. Sem estado global; só caminhos e leitura de JSON.
##
## Snapshot do servidor (fonte A): variável de ambiente POKE_SNAPSHOT, senão a cópia dentro do projeto
## (`poke har/extraido/snapshot_2026-11-09`, ignorada pelo git e pelo Godot via .gdignore),
## senão o caminho antigo citado no CLAUDE.md.

const SNAPSHOT_RELATIVO := "poke har/extraido/snapshot_2026-11-09"
const SNAPSHOT_ALTERNATIVO := "C:/Users/dmala/Desktop/poke har/extraido/snapshot_2026-11-09"


static func raiz_projeto() -> String:
	## Rodando do código-fonte: a pasta do projeto. Jogo exportado (exe + pck): a pasta do executável, onde ficam `dados/`
	## e o snapshot (o res:// do pck não é uma pasta do disco).
	var r := ProjectSettings.globalize_path("res://").trim_suffix("/")
	if r != "" and FileAccess.file_exists(r + "/project.godot"):
		return r
	return OS.get_executable_path().get_base_dir().replace("\\", "/")


static func pasta_snapshot() -> String:
	var env := OS.get_environment("POKE_SNAPSHOT")
	if env != "" and DirAccess.dir_exists_absolute(env):
		return env.replace("\\", "/").trim_suffix("/")
	# Jogo exportado (ciclo 3): o pacote de execução `jogo/` ao lado do executável (ferramentas/build/gerar_pacote_jogo.gd):
	# só o que o jogo lê, com os mapas comprimidos (.json.zst). O snapshot bruto não vai no build.
	var pacote := raiz_projeto() + "/jogo"
	if DirAccess.dir_exists_absolute(pacote + "/game"):
		return pacote
	var local := raiz_projeto() + "/" + SNAPSHOT_RELATIVO
	if DirAccess.dir_exists_absolute(local):
		return local
	if DirAccess.dir_exists_absolute(SNAPSHOT_ALTERNATIVO):
		return SNAPSHOT_ALTERNATIVO
	return ""


static func pasta_dados() -> String:
	return raiz_projeto() + "/dados"


static func arquivo(caminho: String) -> String:
	## O arquivo como está, ou a versão comprimida (`.zst`, pacote de execução) se só ela existe.
	if not FileAccess.file_exists(caminho) and FileAccess.file_exists(caminho + ".zst"):
		return caminho + ".zst"
	return caminho


static func existe(caminho: String) -> bool:
	return FileAccess.file_exists(caminho) or FileAccess.file_exists(caminho + ".zst")


static func ler_json(caminho: String) -> Variant:
	var texto := ""
	if not FileAccess.file_exists(caminho) and FileAccess.file_exists(caminho + ".zst"):
		var f := FileAccess.open_compressed(caminho + ".zst", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		texto = f.get_as_text() if f != null else ""
	elif not FileAccess.file_exists(caminho):
		push_error("Arquivo não encontrado: " + caminho)
		return null
	else:
		texto = FileAccess.get_file_as_string(caminho)
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
