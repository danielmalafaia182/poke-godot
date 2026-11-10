extends SceneTree
## Caminho de tempo mínimo da simulação (sim/simulacao_hunt.gd) num chão aberto sintético (21×21), sem selvagens.
## Confere que os passos escolhidos são os ótimos para os custos medidos (A): herói reto 3 ticks, diagonal 5;
## selvagem reto 5, diagonal 10. Rodar: testes/rodar.sh res://testes/test_sim_caminho.gd

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func classe(d: Vector2i, delta: Vector2i) -> String:
	if d.x != 0 and d.y != 0:
		return "diagonal"
	var maior_x := absi(delta.x) > absi(delta.y)
	var maior_y := absi(delta.y) > absi(delta.x)
	return "maior" if (d.x != 0 and maior_x) or (d.y != 0 and maior_y) else "menor"


func contar(sim, origem: Vector2i, delta: Vector2i, n: int) -> Dictionary:
	var r := {}
	sim.heroi["pos"] = origem
	for i in n:
		var t: Vector2i = sim._proximo_tile_heroi(origem + delta)
		var c := classe(t - origem, delta) if t != origem else "parado"
		r[c] = int(r.get(c, 0)) + 1
	return r


func contar_mob(sim, origem: Vector2i, heroi_pos: Vector2i, n: int) -> Dictionary:
	var r := {}
	sim.heroi["pos"] = heroi_pos
	var caixa: Rect2i = sim._caixa(heroi_pos, heroi_pos, 19, 13)
	var custos: Vector2i = sim._custos(int(sim.p.mob_step_ms))
	var campo: PackedInt32Array = sim._campo_tempo(heroi_pos, caixa, custos, {})
	for i in n:
		var t: Vector2i = sim._escolher_passo(origem, heroi_pos, campo, caixa, custos,
			func(q): return sim._livre(q) and q != heroi_pos, sim.p.desempate_mob)
		var c := classe(t - origem, heroi_pos - origem) if t != origem else "parado"
		r[c] = int(r.get(c, 0)) + 1
	return r


func _init() -> void:
	var dados = DadosJogo.carregar()
	var cfg := Cenario.de_estado(Fontes.raiz_projeto() + "/dados/testes/estado_rhydon_venusaur.json", dados, 7)
	var mapa = MapaHunt.carregar(cfg["slug"], Fontes.ler_mapa(cfg["slug"]), Fontes.ler_colisao())
	var sim = Simulacao.new(cfg, dados, mapa)
	for m in sim.mobs:
		m["dead"] = true
	# chão aberto sintético: a grade real do Rhydon não tem área livre grande o bastante; libera um quadrado 21×21
	var c := Vector2i(mapa.cols / 2, mapa.rows / 2)
	for y in range(c.y - 10, c.y + 11):
		for x in range(c.x - 10, c.x + 11):
			mapa.grade[y][x] = true
	sim.atualizar_grade()   # a sim guarda cópias derivadas da grade (plana e ilhas)
	checar(mapa.passavel(c.y + 10, c.x + 10), "chão aberto sintético no centro do mapa", str(c))

	var r := contar(sim, c, Vector2i(2, 5), 400)
	checar(not r.has("menor") and not r.has("parado") and r.has("maior") and r.has("diagonal"),
		"herói, alvo a (5 linhas, 2 colunas): só eixo maior ou diagonal (empate em tempo)", str(r))
	var frac := float(r.get("maior", 0)) / 400.0
	checar(absf(frac - 475.0 / 621.0) < 0.08, "herói: desempate eixo maior/diagonal segue os pesos medidos (~0,76)", "%.3f" % frac)
	r = contar(sim, c, Vector2i(1, 5), 50)
	checar(r.keys() == ["maior"], "herói, alvo a (5, 1): só eixo maior (diagonal e eixo menor custam mais)", str(r))
	r = contar(sim, c, Vector2i(4, 4), 50)
	checar(r.keys() == ["diagonal"], "herói, alvo na diagonal exata (4, 4): só diagonal (5 ticks < 2 retos)", str(r))
	r = contar(sim, c, Vector2i(0, 6), 50)
	checar(r.keys() == ["maior"], "herói, alvo alinhado (6, 0): só reto", str(r))

	r = contar_mob(sim, c + Vector2i(2, 5), c, 600)
	checar(r.has("maior") and r.has("diagonal") and r.has("menor") and not r.has("parado"),
		"selvagem a (5, 2) do herói: os três passos empatam (diagonal 10 = 2 retos)", str(r))
	r = contar_mob(sim, c + Vector2i(4, 4), c, 300)
	checar(not r.has("parado") and r.has("diagonal"), "selvagem na diagonal exata: diagonal ou reto (empatam)", str(r))

	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
