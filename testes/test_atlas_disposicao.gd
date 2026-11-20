extends SceneTree
## Atlas por mapa com a disposição pronta (ciclo 4, item 4). Confere em rattata e nightmare_steelix: a disposição gravada
## (como o build leva em jogo/cache/mapas/<slug>.quadros.bin) é igual à calculada; montar com ela dá o mesmo atlas
## (retângulos e pixels) que o arquivo que a gravação em segundo plano deixa no disco; o atlas recém-montado fica em
## memória (origem "memória"); cada quadro usado pelo mapa está no atlas. (Em 20/11, conferido também contra os arquivos
## montados pelo código anterior: retângulos e pixels idênticos nos dois mapas.)
## Rodar: testes/rodar.sh res://testes/test_atlas_disposicao.gd

const CacheMapa := preload("res://render/cache_mapa.gd")
const AtlasMapa := preload("res://render/atlas_mapa.gd")
const DadosDesenho := preload("res://render/dados_desenho.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _init() -> void:
	var d = DadosDesenho.carregar()
	for slug in ["rattata", "nightmare_steelix"]:
		var c: Dictionary = CacheMapa.ler(slug, d)
		var tmp := ProjectSettings.globalize_path("user://" + slug + ".quadros.bin")
		AtlasMapa.gravar_quadros(slug, d, c, tmp)
		var f := FileAccess.open_compressed(tmp, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		var gravada: Dictionary = f.get_var()
		f.close()
		var calc: Dictionary = AtlasMapa._disposicao(AtlasMapa.quadros_usados(c, d.manifest["assets"]), d.manifest["assets"])
		checar(gravada["o"] == calc["o"] and gravada["p"] == calc["p"] and gravada["q"] == calc["q"] and int(gravada["largura"]) == int(calc["largura"]),
			"%s: disposição gravada = calculada" % slug, "%d quadros" % ((calc["q"] as PackedInt32Array).size() / 2))
		var novo: Dictionary = AtlasMapa.montar(slug, d, c)
		AtlasMapa.esperar_gravacoes()
		var disco: Dictionary = AtlasMapa.ler(slug, d)
		checar(not disco.is_empty() and disco["rects"] == novo["rects"] and (disco["imagem"] as Image).get_data() == (novo["imagem"] as Image).get_data(),
			"%s: atlas montado = o gravado em segundo plano" % slug)
		checar(String(AtlasMapa.obter(slug, d, c).get("origem", "")) == "memória", "%s: o recém-montado vem da memória" % slug)
		checar((novo["rects"] as PackedInt32Array).size() == (calc["q"] as PackedInt32Array).size() * 2, "%s: todo quadro usado está no atlas" % slug)
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
