extends SceneTree
## Jogabilidade das 451 hunts na sim pura (escopo de 18/11, item 3): nenhuma pode travar — 0 abates, morte em loop ou
## alvo inalcançável. Time (E): a linha do Geodude do jogo novo (mesmos IV e Quality, semente 1) no nível da hunt
## (Geodude < 40, Graveler < 80, Golem a partir de 80), Auto-Potion com 999 da menor poção que cura ≥ 35% do HP.
## 5 min por hunt. Quem falha roda de novo com um time forte (IV 32, Q 1,8, nível = 3 × hunt + 50, como a varredura
## 2b.6): se o forte passa, a hunt é só difícil para o time igual; se o forte também falha, é trava de mecânica.
## "Travado" = maior trecho com o herói parado, sem lutar, com selvagem vivo e alvo definido (≥ 60 s conta como trava).
## Uso: testes/rodar.sh res://testes/jogabilidade_hunts.gd [--minutos 5] [--slugs a,b] [--saida caminho.json]

const Regras := preload("res://sim/regras.gd")
const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const NovoJogo := preload("res://sim/servico_novo_jogo.gd")

var dados
var args := {"minutos": 5.0, "slugs": "", "saida": "saida_testes/jogabilidade.json"}


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		var k := String(a[i]).trim_prefix("--")
		if args.has(k) and i + 1 < a.size():
			args[k] = type_convert(a[i + 1], typeof(args[k]))
	dados = DadosJogo.carregar()
	var ini: Dictionary = NovoJogo.criar(NovoJogo.INICIAL_CAMPANHA, 1, "J", "campanha")["inicial"]
	var slugs: Array = dados.hunts.keys() if String(args["slugs"]) == "" else String(args["slugs"]).split(",")
	slugs.sort()
	var res: Array = []
	var falhas_igual: Array = []
	var travas: Array = []
	for s in slugs:
		var mapa = MapaHunt.carregar(s, Fontes.ler_mapa(s), Fontes.ler_colisao())
		var nv := maxi(1, int(dados.hunts[s]["nivel"]))
		var r := _rodar(s, mapa, nv, ini["ivs"], float(ini["quality"]))
		r["time"] = "igual"
		if not bool(r["ok"]):
			falhas_igual.append(s)
			var ivs := {"hp": 32, "atk": 32, "def": 32, "spAtk": 32, "spDef": 32, "speed": 32}
			var rf := _rodar(s, mapa, mini(100000, nv * 3 + 50), ivs, 1.8)
			r["forte"] = rf
			if not bool(rf["ok"]):
				travas.append(s)
		res.append(r)
		print("HUNT ", JSON.stringify(r))
	var saida := {"minutos": args["minutos"], "hunts": res, "falham_time_igual": falhas_igual, "falham_time_forte": travas,
		"segundos_reais": (Time.get_ticks_msec() - t0) / 1000.0}
	var f := FileAccess.open(String(args["saida"]), FileAccess.WRITE)
	f.store_string(JSON.stringify(saida, "  "))
	f.close()
	print("FIM %d hunts; falham com time igual: %d %s; falham também com time forte: %d %s; %.0f s" % [res.size(), falhas_igual.size(),
		str(falhas_igual), travas.size(), str(travas), saida["segundos_reais"]])
	quit(0)


func _rodar(slug: String, mapa, nivel: int, ivs: Dictionary, q: float) -> Dictionary:
	var sp := 74 if nivel < 40 else (75 if nivel < 80 else 76)
	var esp: Dictionary = dados.especie(sp)
	var st := Regras.calcular_stats(esp["base"], ivs, nivel, q)
	var max_hp := Regras.hp_combate_aliado(int(st["hp"]))
	var pocao := 204
	for id in [200, 201, 202, 203, 204]:
		if float(dados.itens[id].get("cura", 0)) >= 0.35 * max_hp:
			pocao = id
			break
	var jogo := {"slug": slug, "hunt": String(dados.hunts[slug]["nome"]), "equipe": [{"id": "l", "nome": String(esp["nome"]),
		"xp": Regras.xp_total_para_nivel(nivel), "ivs": ivs, "quality": q, "hp": -1}], "auto_potion": true, "penalizar": false,
		"inventario": [{"itemId": pocao, "quantity": 999}]}
	var cfg := CenarioJogo.configurar(jogo, dados, 7 + slug.hash() % 1000, 0)
	var sim = Simulacao.new(cfg, dados, mapa)
	sim.iniciar()
	var r := {"slug": slug, "nivel": int(dados.hunts[slug]["nivel"]), "area": String(dados.hunts[slug]["area"]), "lider": "%s %d" % [esp["nome"], nivel],
		"abates": 0, "morte": false, "travado_max_s": 0.0, "primeiro_abate_s": -1.0, "segundos": 0.0, "curas": 0}
	var parado := 0
	var ult := Vector2i(-999, -999)
	var n := int(float(args["minutos"]) * 300)
	for t in n:
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			match String(m.get("type", "")):
				"field-kill":
					r["abates"] += 1
					if float(r["primeiro_abate_s"]) < 0:
						r["primeiro_abate_s"] = t * 0.2
				"auto-heal":
					r["curas"] += 1
				"field-none":
					r["morte"] = String(m.get("motivo", "")) == "sem-reserva"
				"field":
					var h: Dictionary = m["hero"]
					var pos := Vector2i(int(h["col"]), int(h["row"]))
					var vivo := false
					for mb in m["mobs"]:
						if not bool(mb["dead"]):
							vivo = true
							break
					if pos == ult and not bool(m.get("fighting", false)) and vivo and m.get("targetSlot") != null:
						parado += 2
					else:
						parado = 0
					ult = pos
					r["travado_max_s"] = maxf(float(r["travado_max_s"]), parado * 0.2)
		if sim.encerrada:
			r["segundos"] = (t + 1) * 0.2
			break
	if float(r["segundos"]) == 0.0:
		r["segundos"] = n * 0.2
	r["ok"] = int(r["abates"]) > 0 and not bool(r["morte"]) and float(r["travado_max_s"]) < 60.0
	return r
