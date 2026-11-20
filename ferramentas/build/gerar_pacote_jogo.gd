extends SceneTree
## Pacote de execução do build (ciclo 3): só o que o jogo lê em tempo de execução, tirado do snapshot.
##   jogo/game/maps/<slug>.json.zst   os mapas das hunts (zstd; Fontes.ler_json lê direto)
##   jogo/game/{collision,offsets,draworder}.json, jogo/game/corpses/, jogo/game/asset-packs/ (atlas, outfits)
##   jogo/api/hunt-config/<slug>.json, jogo/api/city-npcs/cerulean.json, jogo/assets/ (ícones)
##   jogo/cache/mapas/<slug>.bin   o cache de desenho de cada mapa (ciclo 4)
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
	slugs["cerulean_novo"] = true   # ciclo 4: a cidade usa o mapa do servidor (cenario_cidade.gd)
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
	# Ciclo 4 (entrada na hunt ≤ 1 s): o cache de desenho de cada mapa vai pronto (montar custa 1–8 s por mapa). A chave
	# usa o MD5 do JSON descomprimido, então o cache montado aqui vale para o .json.zst do pacote. O atlas por mapa
	# (~3,8 MB cada) não vai: o jogo o monta em segundo plano na cidade (EstadoJogo.pre_aquecer_atlas).
	var CacheMapa := load("res://render/cache_mapa.gd")
	var dd = load("res://render/dados_desenho.gd").carregar()
	DirAccess.make_dir_recursive_absolute(saida + "/cache/mapas")
	var caches := 0
	var montados := 0
	for slug in slugs:
		if not FileAccess.file_exists(snap + "/game/maps/" + slug + ".json"):
			continue
		if CacheMapa.ler(slug, dd).is_empty():
			CacheMapa.montar(slug, dd, Fontes.ler_mapa(slug))
			montados += 1
		_copiar(CacheMapa.caminho(slug), saida + "/cache/mapas/" + slug + ".bin")
		CacheMapa.mapa_hunt(slug, dd)   # grade da sim (monta e grava se faltar)
		load("res://render/atlas_mapa.gd").gravar_quadros(slug, dd, CacheMapa.ler(slug, dd), saida + "/cache/mapas/" + slug + ".quadros.bin")
		_copiar(CacheMapa.caminho_grade(slug), saida + "/cache/mapas/" + slug + ".grade.bin")
		caches += 1
	print("caches de mapa: %d (%d montados agora)" % [caches, montados])
	_copiar_pasta(snap + "/game/corpses", saida + "/game/corpses")
	_copiar_pasta(snap + "/game/asset-packs", saida + "/game/asset-packs")
	for slug in slugs:
		var c: String = snap + "/api/hunt-config/" + slug + ".json"
		if FileAccess.file_exists(c):
			_copiar(c, saida + "/api/hunt-config/" + slug + ".json")
	_copiar_pasta(snap + "/assets", saida + "/assets")
	_copiar(snap + "/api/city-npcs/cerulean.json", saida + "/api/city-npcs/cerulean.json")   # NPCs da cidade (A)
	# páginas de cadáver que faltam no snapshot (A: corpses-g-00, corpses-h-00): as do poke-local, mesmo caminho
	var cj = Fontes.ler_json(snap + "/game/corpses/corpses.json")
	if cj is Dictionary:
		for pg in cj.get("pages", []):
			if not FileAccess.file_exists(snap + String(pg)) and FileAccess.file_exists(raiz + "/poke-local/public" + String(pg)):
				_copiar(raiz + "/poke-local/public" + String(pg), saida + String(pg))
	print("PACOTE %s: %d mapas (%.1f MB → %.1f MB), %d arquivos copiados, %.0f s" % [saida, mapas, antes / 1e6, depois / 1e6, copiados, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
