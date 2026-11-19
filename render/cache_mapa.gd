extends RefCounted
## Cache binário do desenho de um mapa (fase 2b): o resultado de RegrasDesenho.montar() já em ordem de desenho
## (ordenação estável por zIndex, por andar), em arrays compactados, com o índice de chunks 8×8 e os tiles com chão.
## Montar o maior mapa (nightmare_steelix, 301.712 sprites) leva ~5 s em GDScript; ler o cache, ~0,1 s.
##
## Arquivo: res://cache/mapas/<slug>.bin, comprimido com zstd (pasta fora do git e do scan do Godot). Validade: hash MD5 do mapa, do
## draworder, do offsets, da colisão e da versão do atlas + VERSAO das regras; qualquer mudança refaz o cache.
## Conteúdo (Dictionary, gravado com store_var):
##   versao, chave, ground_z, min_z, max_z, paginas (PackedInt32Array, todas as usadas)
##   andares: {z: {id, quadro, x, y, tx, ty (PackedInt32Array), zi (PackedFloat64Array), anim (PackedByteArray)}}
##            — já ordenados: o índice é o posto (draw_index = 2·i)
##   chunks: {"z|cx,cy": PackedInt32Array de índices do andar}
##   paginas_chunk: {"z|cx,cy": PackedInt32Array de páginas do atlas}
##   chao: PackedStringArray "x,y,z" dos tiles com chão (computeFirstVisibleFloor)

const Fontes := preload("res://sim/fontes.gd")

const VERSAO := 2          # subir quando mudar regras_desenho.gd ou este formato (2: zstd)
const PASTA := "res://cache/mapas"   # do código-fonte; no jogo exportado, user://cache/mapas (pasta_abs)


static func pasta_abs() -> String:
	var r := ProjectSettings.globalize_path("res://").trim_suffix("/")
	if r != "" and FileAccess.file_exists(r + "/project.godot"):
		return ProjectSettings.globalize_path(PASTA)
	return ProjectSettings.globalize_path("user://cache/mapas")
const CHUNK := 8


static func _md5(caminho: String) -> String:
	return FileAccess.get_md5(caminho) if FileAccess.file_exists(caminho) else "-"


static func chave(slug: String, dados: RefCounted) -> String:
	var g := Fontes.pasta_snapshot() + "/game"
	return "%d|%s|%s|%s|%s|%s|%s" % [VERSAO, _md5(g + "/maps/%s.json" % slug), _md5(g + "/draworder.json"),
		_md5(g + "/offsets.json"), _md5(g + "/collision.json"), String(dados.versao), slug]


static func caminho(slug: String) -> String:
	return pasta_abs() + "/" + slug + ".bin"


static func ler(slug: String, dados: RefCounted) -> Dictionary:
	var c := caminho(slug)
	if not FileAccess.file_exists(c):
		return {}
	var f := FileAccess.open_compressed(c, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	var d = f.get_var()
	if not d is Dictionary or int(d.get("versao", -1)) != VERSAO or String(d.get("chave", "")) != chave(slug, dados):
		return {}
	return d


static func montar(slug: String, dados: RefCounted, mapa: Dictionary) -> Dictionary:
	## Monta (lento) e grava o cache. `mapa` é o JSON do mapa já lido.
	var regras = dados.regras_para(mapa)
	var meta: Dictionary = mapa.get("_meta", {})
	var gz := int(meta.get("groundZ", (meta.get("range", [0, 0, 0, 0, 7]) as Array)[4]))
	var por_andar: Dictionary = regras.montar(mapa["tiles"])
	var andares := {}
	var chunks := {}
	var paginas_chunk := {}
	var todas := {}
	for z in por_andar:
		var col: Array = por_andar[z]
		var idx := range(col.size())
		idx.sort_custom(func(a, b):
			var za: float = col[a][4]
			var zb: float = col[b][4]
			return za < zb or (za == zb and a < b))
		var n := col.size()
		var ids := PackedInt32Array(); ids.resize(n)
		var qs := PackedInt32Array(); qs.resize(n)
		var xs := PackedInt32Array(); xs.resize(n)
		var ys := PackedInt32Array(); ys.resize(n)
		var txs := PackedInt32Array(); txs.resize(n)
		var tys := PackedInt32Array(); tys.resize(n)
		var zis := PackedFloat64Array(); zis.resize(n)
		var an := PackedByteArray(); an.resize(n)
		var ch := {}
		var pch := {}
		for r in n:
			var c: Array = col[idx[r]]
			ids[r] = int(c[0]); qs[r] = int(c[1]); xs[r] = int(c[2]); ys[r] = int(c[3])
			zis[r] = float(c[4]); an[r] = 1 if bool(c[5]) else 0; txs[r] = int(c[6]); tys[r] = int(c[7])
			var k := "%d|%d,%d" % [int(z), floori(float(c[6]) / CHUNK), floori(float(c[7]) / CHUNK)]
			if not ch.has(k):
				ch[k] = []
				pch[k] = {}
			ch[k].append(r)
			for fr in regras.assets[int(c[0])]["frames"]:
				pch[k][int(fr["page"])] = true
				todas[int(fr["page"])] = true
		andares[int(z)] = {"id": ids, "quadro": qs, "x": xs, "y": ys, "tx": txs, "ty": tys, "zi": zis, "anim": an}
		for k in ch:
			chunks[k] = PackedInt32Array(ch[k])
			paginas_chunk[k] = PackedInt32Array(pch[k].keys())
	var chao := PackedStringArray()
	var mn := 1 << 30
	var mx := -(1 << 30)
	for t in mapa["tiles"]:
		if int(t[3]) != 0:
			chao.append("%d,%d,%d" % [int(t[0]), int(t[1]), int(t[2])])
		mn = mini(mn, int(t[2]))
		mx = maxi(mx, int(t[2]))
	var pags := todas.keys()
	pags.sort()
	var d := {"versao": VERSAO, "chave": chave(slug, dados), "ground_z": gz, "min_z": mn, "max_z": mx,
		"paginas": PackedInt32Array(pags), "andares": andares, "chunks": chunks, "paginas_chunk": paginas_chunk, "chao": chao}
	DirAccess.make_dir_recursive_absolute(pasta_abs())
	var f := FileAccess.open_compressed(caminho(slug), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f != null:
		f.store_var(d)
		f.close()
	return d


static func obter(slug: String, dados: RefCounted) -> Dictionary:
	var d := ler(slug, dados)
	if not d.is_empty():
		d["origem"] = "cache"
		return d
	d = montar(slug, dados, Fontes.ler_mapa(slug))
	d["origem"] = "montado"
	return d
