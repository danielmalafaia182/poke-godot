extends SceneTree
## XP/h e mortes em hunts de Orre e da Outland (ciclo 5: piso de XP de Orre; ciclo 6: time + itens, com e sem o piso).
## Sim pura, Hyper Potion, sem penalidade de entrada.
## Sem --time: líder = o Golem da campanha (testes/campanha.gd, semente 1) no nível pedido, reservas de nível ~40.
## Com --time <saida da campanha.json>: o time final da campanha (time_final) com os helds e TMs dela (itens_uso); em cada
## hunt lidera o membro de maior Power × vantagem de tipo (como a campanha escolhe), o resto de reserva.
## Uso: testes/rodar.sh res://testes/medir_orre.gd [--nivel 527] [--minutos 60] [--sementes 2] [--slugs a,b] [--vip 1]
##      [--time saida_testes/campanha_c6_time.json] [--sem_piso 1] [--sem_itens 1]

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")
const NovoJogo := preload("res://sim/servico_novo_jogo.gd")
const Metas := preload("res://sim/metas.gd")

var args := {"nivel": 527, "minutos": 60.0, "sementes": 2, "vip": 1, "time": "", "sem_piso": 0, "sem_itens": 0, "nivel_lider": 0,
	"slugs": "electrike,taillow,aron,poochyena,riolu,meditite,ralts,wingull,numel,enraged_typhlosion,ancient_pinsir,furious_scyther"}
var dados


func _vantagem(sid: int, slug: String) -> float:
	var meus := Regras.tipos_de(dados.especie(sid))
	var at := 0.0
	var de := 0.0
	var n := 0
	for x in dados.hunts[slug].get("spawns", []):
		var ts := Regras.tipos_de(dados.especie(int(x.get("pokeId", 0))))
		var a := 0.0
		for t in meus:
			if String(t) != "":
				a = maxf(a, Regras.efetividade_amplificada(Regras.efetividade_bruta(String(t), String(ts[0]), String(ts[1]))))
		var d := 0.0
		for t in ts:
			if String(t) != "":
				d = maxf(d, Regras.efetividade_amplificada(Regras.efetividade_bruta(String(t), String(meus[0]), String(meus[1]))))
		at += a
		de += d
		n += 1
	return 1.0 if n == 0 else (at / n) / maxf(0.2, de / n)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		var k := String(a[i]).trim_prefix("--")
		if args.has(k) and i + 1 < a.size():
			args[k] = type_convert(a[i + 1], typeof(args[k]))
	dados = DadosJogo.carregar()
	var equipe: Array = []
	var helds := {}
	var tms := {}
	var treinador := Regras.xp_total_para_nivel(int(args["nivel"]))
	if String(args["time"]) != "":
		var c: Dictionary = Fontes.ler_json(String(args["time"]))
		for pk in c.get("time_final", []):
			equipe.append({"id": String(pk["id"]), "nome": String(pk["nome"]), "xp": int(pk["xp"]), "ivs": pk["ivs"], "quality": float(pk["quality"]), "hp": -1})
		if int(args["sem_itens"]) == 0:
			helds = c.get("itens_uso", {}).get("held", {})
			tms = c.get("itens_uso", {}).get("tms", {})
		treinador = Regras.xp_total_para_nivel(int(c.get("treinador_final", args["nivel"])))
		if int(args["nivel_lider"]) > 0:
			# --nivel_lider: o carregador (o de mais XP) e o treinador no nível pedido (ex.: 527, o acesso a Orre)
			var mx := 0
			for i in equipe.size():
				if int(equipe[i]["xp"]) > int(equipe[mx]["xp"]):
					mx = i
			equipe[mx]["xp"] = Regras.xp_total_para_nivel(int(args["nivel_lider"]))
			treinador = Regras.xp_total_para_nivel(int(args["nivel_lider"]) + 5)
		print("time: ", c.get("time_final", []).map(func(x): return "%s %d" % [x["nome"], int(x["nivel"])]), " helds ", helds, " tms ", tms)
	else:
		var ini: Dictionary = NovoJogo.criar(NovoJogo.INICIAL_CAMPANHA, 1, "Campanha", "campanha")["inicial"]
		equipe = [{"id": "golem", "nome": "Golem", "xp": Regras.xp_total_para_nivel(int(args["nivel"])), "ivs": ini["ivs"], "quality": float(ini["quality"]), "hp": -1}]
		var rng = preload("res://sim/rng.gd").new(9173)
		for par in [["Sunflora", 41], ["Quilava", 41], ["Krabby", 40], ["Ariados", 41], ["Nidorina", 40]]:
			equipe.append({"id": String(par[0]), "nome": String(par[0]), "xp": Regras.xp_total_para_nivel(int(par[1])), "ivs": Regras.sortear_ivs(rng),
				"quality": Regras.sortear_qualidade(rng), "hp": -1})
	print("slug\tnivel\tarea\tmult\tlider\tmin\tabates_min\txp_h\tmortes")
	for slug in String(args["slugs"]).split(","):
		var mapa = MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao())
		# líder: o de maior Power × vantagem de tipo nesta hunt
		var ordem := equipe.duplicate(true)
		ordem.sort_custom(func(x, y):
			var px := float(Metas.poder_lider(dados, {"speciesId": CenarioJogo.id_especie(dados, String(x["nome"])), "xp": int(x["xp"]), "ivs": x["ivs"], "quality": float(x["quality"])})) * _vantagem(CenarioJogo.id_especie(dados, String(x["nome"])), slug)
			var py := float(Metas.poder_lider(dados, {"speciesId": CenarioJogo.id_especie(dados, String(y["nome"])), "xp": int(y["xp"]), "ivs": y["ivs"], "quality": float(y["quality"])})) * _vantagem(CenarioJogo.id_especie(dados, String(y["nome"])), slug)
			return px > py)
		var mins := 0.0
		var xp := 0
		var abates := 0
		var mortes := 0
		var mult := 1.0
		for s in int(args["sementes"]):
			var jogo := {"slug": slug, "hunt": slug, "equipe": ordem.duplicate(true), "lider": 0, "vip": int(args["vip"]) == 1,
				"penalizar": false, "auto_potion": true, "inventario": [{"itemId": 203, "quantity": 5000}], "treinador_xp": treinador,
				"helds": helds, "tms": tms}
			var cfg := CenarioJogo.configurar(jogo, dados, 11 + s, 0)
			if int(args["sem_piso"]) == 1:
				cfg["parametros"]["xp_regiao_piso"] = {}
			var sim = Simulacao.new(cfg, dados, mapa)
			mult = sim.multiplicador_regiao()
			sim.iniciar()
			var xp0 := int(sim.treinador["xp"])
			var n := int(float(args["minutos"]) * 300.0)
			var t := 0
			while t < n:
				for reg in sim.passo():
					var m: Dictionary = reg.get("msg", reg)
					if String(m.get("type", "")) == "field-kill":
						abates += 1
				t += 1
				if sim.encerrada:
					mortes += 1
					break
			mins += t / 300.0
			xp += int(sim.treinador["xp"]) - xp0
		print("%s\t%d\t%s\t%.1f\t%s\t%.1f\t%.2f\t%d\t%d" % [slug, int(dados.hunts[slug]["nivel"]), String(dados.hunts[slug]["area"]), mult,
			String(ordem[0]["nome"]), mins, abates / maxf(0.1, mins), int(xp / maxf(0.1, mins) * 60.0), mortes])
	quit(0)
