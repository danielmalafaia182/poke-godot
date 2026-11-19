extends SceneTree
## Pacote de execução do build (ciclo 3): só o que o jogo lê em tempo de execução, tirado do snapshot.
##   jogo/game/maps/<slug>.json.zst   os mapas das hunts (zstd; Fontes.ler_json lê direto)
##   jogo/game/{collision,offsets,draworder}.json, jogo/game/corpses/, jogo/game/asset-packs/ (atlas, outfits)
##   jogo/api/hunt-config/<slug>.json, jogo/assets/ (ícones)
##   + as 2 páginas de cadáver que só o poke-local tem (mesmo caminho relativo)
## Fica de fora: o resto do snapshot (manifests da coleta, api/city-npcs, bossCatalog e creatures, que já estão
## processados em dados/), gravações e ferramentas.
## Uso: godot --headless --path . --script res://ferramentas/build/gerar_pacote_jogo.gd -- <pasta de saída>

const Fontes := preload("res://sim/fontes.gd")
var copiados := 0
var bytes := 0


func _copiar(de: String, para: String) -> void:
	DirAccess.make_dir_recursive_absolute(para.get_base_dir())
	if DirAccess.copy_absolute(de, para) == OK:
		copiados += 1
		bytes += FileAccess.get_file_as_bytes(para).size() if para.get_extension() != "webp" else 0


func _copiar_pasta(de: String, para: String) -> void:
	var d := DirAccess.open(de)
	if d == null:
		return
	for f in d.get_files():
		_copiar(de + "/" + f, para + "/" + f)
	for s in d.get_directories():
		_copiar_pasta(de + "/" + s, para + "/" + s)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var saida: String = a[0] if a.size() > 0 else Fontes.raiz_projeto() + "/builds/pacote/jogo"
	var snap := Fontes.pasta_snapshot()
	var raiz := Fontes.raiz_projeto()
	if snap.ends_with("/jogo"):
		push_error("o pacote precisa do snapshot bruto (rode do projeto)")
		quit(1)
		return
	var t0 := Time.get_ticks_msec()
	var hunts = Fontes.ler_json(Fontes.pasta_dados() + "/gerados/hunts.json")
	var slugs := {}
	for h in (hunts if hunts is Array else (hunts as Dictionary).values()):
		slugs[String(h["slug"])] = true
	var mapas := 0
	var antes := 0
	var depois := 0
	DirAccess.make_dir_recursive_absolute(saida + "/game/maps")
	for slug in slugs:
		var c: String = snap + "/game/maps/" + slug + ".json"
		if not FileAccess.file_exists(c):
			continue
		var texto := FileAccess.get_file_as_string(c)
		var f := FileAccess.open_compressed(saida + "/game/maps/" + slug + ".json.zst", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		f.store_string(texto)
		f.close()
		antes += texto.length()
		depois += FileAccess.get_file_as_bytes(saida + "/game/maps/" + slug + ".json.zst").size()
		mapas += 1
	for n in ["collision.json", "offsets.json", "draworder.json"]:
		_copiar(snap + "/game/" + n, saida + "/game/" + n)
	_copiar_pasta(snap + "/game/corpses", saida + "/game/corpses")
	_copiar_pasta(snap + "/game/asset-packs", saida + "/game/asset-packs")
	for slug in slugs:
		var c: String = snap + "/api/hunt-config/" + slug + ".json"
		if FileAccess.file_exists(c):
			_copiar(c, saida + "/api/hunt-config/" + slug + ".json")
	_copiar_pasta(snap + "/assets", saida + "/assets")
	# páginas de cadáver que faltam no snapshot (A: corpses-g-00, corpses-h-00): as do poke-local, mesmo caminho
	var cj = Fontes.ler_json(snap + "/game/corpses/corpses.json")
	if cj is Dictionary:
		for pg in cj.get("pages", []):
			if not FileAccess.file_exists(snap + String(pg)) and FileAccess.file_exists(raiz + "/poke-local/public" + String(pg)):
				_copiar(raiz + "/poke-local/public" + String(pg), saida + String(pg))
	print("PACOTE %s: %d mapas (%.1f MB → %.1f MB), %d arquivos copiados, %.0f s" % [saida, mapas, antes / 1e6, depois / 1e6, copiados, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
