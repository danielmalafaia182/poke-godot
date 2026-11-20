extends SceneTree
## Selvagem bloqueado contorna (ciclo 4, item 4; A: ferramentas/fase4/medir_contorno.py — nas gravações, com todas as
## casas que aproximam ocupadas, o original dá o passo lateral em vez de esperar o vizinho morrer). Cenário montado na
## hunt rattata, numa área aberta: herói H parado; três selvagens ocupam as 3 casas entre P e H; P está a 2 casas.
## Com `mob_contorna_bloqueio` ligado, P chega ao lado do herói por outra casa em poucos passos e sem nenhum vizinho
## morrer; desligado, P fica parado (era o caso do Pidgey). O herói fica sem alvo (não ataca, não anda).
## Rodar: testes/rodar.sh res://testes/test_sim_contorno.gd

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func aberto(mapa, c: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if not mapa.passavel(c.y + dy, c.x + dx):
				return false
	return true


func rodar(dados, mapa, contorna: bool) -> Dictionary:
	var jogo := {"slug": "rattata", "hunt": "Rattata", "equipe": [{"id": "b", "nome": "Bulbasaur", "xp": 100,
		"ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}, "quality": 1.0, "hp": -1}],
		"auto_catch": false, "auto_potion": false, "penalizar": false, "bolas": {1: 10}, "inventario": []}
	var cfg := CenarioJogo.configurar(jogo, dados, 7, 0)
	cfg["parametros"] = cfg.get("parametros", {})
	cfg["parametros"]["mob_contorna_bloqueio"] = contorna
	var sim = Simulacao.new(cfg, dados, mapa)
	sim.iniciar()
	# área aberta 5×5 perto do início
	var h: Vector2i = sim.heroi["pos"]
	var achou := false
	for raio in range(0, 80):
		for dy in range(-raio, raio + 1):
			for dx in range(-raio, raio + 1):
				if not achou and aberto(mapa, h + Vector2i(dx, dy), 2):
					h = h + Vector2i(dx, dy)
					achou = true
	sim.heroi["pos"] = h
	sim.heroi["de"] = h
	var lugares := [Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)]   # 3 bloqueiam, o 4º é P
	var vivos: Array = []
	for m in sim.mobs:
		if vivos.size() < 4:
			vivos.append(m)
		else:
			m["dead"] = true
			m["morte_tick"] = sim.tick + 100000   # fora do jogo durante o teste
	for i in 4:
		var m: Dictionary = vivos[i]
		m["pos"] = h + lugares[i]
		m["de"] = m["pos"]
		m["hp"] = 999999
		m["max_hp"] = 999999
		m["ultimo_passo_tick"] = sim.tick
		m.erase("plano")
	var p: Dictionary = vivos[3]
	var ticks := 0
	var mortes := 0
	if OS.get_environment("DEPURAR") != "":
		print("h ", h, " p ", p["pos"], " param ", sim.p.get("mob_contorna_bloqueio"), " vivos ", vivos.map(func(m): return m["pos"]))
	while ticks < 120 and sim._cheb(p["pos"], h) > 1:
		if OS.get_environment("DEPURAR") != "" and ticks % 6 == 0:
			print("t", ticks, " p ", p["pos"], " h ", sim.heroi["pos"], " outros ", vivos.slice(0, 3).map(func(m): return m["pos"]), " dead ", vivos.map(func(m): return m["dead"]))
		sim.heroi["alvo"] = -1
		sim.heroi["pos"] = h
		for reg in sim.passo():
			if String(reg.get("msg", reg).get("type", "")) == "field-kill":
				mortes += 1
		ticks += 1
	if OS.get_environment("DEPURAR") != "":
		var cx: Rect2i = sim._campo_mob_caixa
		for y in range(h.y - 2, h.y + 4):
			var l := ""
			for x in range(h.x - 2, h.x + 4):
				var v: int = sim._campo_mob[(y - cx.position.y) * cx.size.x + (x - cx.position.x)]
				l += ("%6d" % v) if v < 1000000 else "   INF"
			print("campo y", y, l)
		var pode := func(n): return sim._livre(n) and n != h and not sim._ocupado_por_mob(n, int(p["slot"]))
		print("pode 38,52 ", pode.call(Vector2i(h.x + 1, h.y + 2)), " livre ", sim._livre(Vector2i(h.x + 1, h.y + 2)), " escolhe ", sim._escolher_passo(p["pos"], h, sim._campo_mob, cx, sim._custos(int(sim.p.mob_step_ms)), pode, sim.p.desempate_mob), " na_visao ", sim._na_visao(p["pos"]), " ocup por ", sim.mobs.filter(func(m): return not m["dead"] and m["pos"] == Vector2i(h.x + 1, h.y + 2)).map(func(m): return m["slot"]))
		print("plano ", p.get("plano"), " ultimo ", p["ultimo_passo_tick"], " tick ", sim.tick)
	return {"chegou": sim._cheb(p["pos"], h) <= 1, "ticks": ticks, "mortes": mortes, "achou": achou}


func _init() -> void:
	var dados = DadosJogo.carregar()
	var mapa = MapaHunt.carregar("rattata", Fontes.ler_mapa("rattata"), Fontes.ler_colisao())
	var com := rodar(dados, mapa, true)
	var sem := rodar(dados, mapa, false)
	checar(bool(com["achou"]), "área aberta 5×5 achada no mapa da rattata")
	checar(bool(com["chegou"]) and int(com["mortes"]) == 0, "bloqueado, o selvagem contorna e chega ao lado do herói sem ninguém morrer",
		"%d ticks" % int(com["ticks"]))
	checar(not bool(sem["chegou"]), "sem a regra ele ficava parado (o caso do Pidgey)", "%d ticks" % int(sem["ticks"]))
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
