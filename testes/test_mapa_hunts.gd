extends SceneTree
## Mapa (ciclo 4, item 4): todas as hunts acessíveis pelo mapa, como no original (A: map-markers; C: clique no marcador
## e regras de nível). Save ISOLADO. Confere, para as 451 hunts do snapshot: há um marcador; ele leva a uma hunt
## simulada (mapa e hunt-config no pacote/snapshot); na aba da região dele o marcador fica visível e dentro da imagem;
## com o nível do treinador suficiente, o clique escolhe exatamente aquele slug (Orre pergunta e entra).

var falhas := 0
var total := 0
var quadros := 0
var mapa: Node


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	mapa = load("res://mapa_mundi.tscn").instantiate()
	get_root().add_child.call_deferred(mapa)


func _process(_d: float) -> bool:
	quadros += 1
	if quadros < 4:
		return false
	var ej = get_root().get_node("EstadoJogo")
	var hunts: Array = preload("res://ponte_cidade.gd").dados().hunts.values()
	var por_slug := {}
	for reg in mapa.catalogo:
		por_slug[String(reg.get("slug", ""))] = reg
	var sem_marcador: Array = []
	var nao_simuladas: Array = []
	for h in hunts:
		var reg: Dictionary = por_slug.get(String(h["slug"]), {})
		if reg.is_empty():
			sem_marcador.append(String(h["slug"]))
		elif not bool(reg.get("simulada", false)):
			nao_simuladas.append(String(h["slug"]))
	checar(sem_marcador.is_empty(), "as %d hunts têm marcador no mapa" % hunts.size(), str(sem_marcador.slice(0, 10)))
	checar(nao_simuladas.is_empty(), "todos os marcadores levam a uma hunt simulada", str(nao_simuladas.slice(0, 10)))
	# visíveis e dentro da imagem na aba da região
	var fora: Array = []
	for regiao in ["kanto", "outland", "orre", "nightmare"]:
		mapa.selecionar_regiao(regiao)
		var lim: Vector2 = mapa.imagem_mapa.size
		for m in mapa.marcadores:
			var reg: Dictionary = mapa.marcadores[m]
			if String(reg.get("area", "kanto")) != regiao or not por_slug.has(String(reg.get("slug", ""))):
				continue
			var p: Vector2 = Vector2(float(reg["pixel"][0]), float(reg["pixel"][1])) + mapa.deslocamento_regiao.get(regiao, Vector2.ZERO)
			if not bool((m as Control).get_meta("atende_filtro", true)) or p.x < 0 or p.y < 0 or p.x > lim.x or p.y > lim.y:
				fora.append(String(reg["slug"]))
	checar(fora.is_empty(), "cada marcador entra na aba da sua região (fora da tela só esconde até arrastar), dentro da imagem", str(fora.slice(0, 10)))
	# clique com nível suficiente → aquele slug (sem trocar de cena: _viajar só é observado pelo slug escolhido)
	ej.nivel_treinador = 5000
	var errados: Array = []
	for reg in mapa.catalogo:
		var slug := String(reg.get("slug", ""))
		if not por_slug.has(slug) or String(reg.get("area", "kanto")) == "":
			continue
		var v: Dictionary = preload("res://sim/regras_acesso.gd").verificar(String(reg.get("area", "kanto")), int(reg["level"]), String(reg["name"]), 5000)
		if not bool(v["ok"]):
			errados.append(slug + ":bloqueada")
	checar(errados.is_empty(), "com nível 5000 nenhuma hunt fica bloqueada", str(errados.slice(0, 10)))
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
