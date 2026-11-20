extends SceneTree
## XP/h e mortes de um líder em hunts de Orre e da Outland (ciclo 5, piso de XP de Orre). Sim pura, VIP, Hyper Potion,
## sem penalidade de entrada. Líder = o Golem da campanha (testes/campanha.gd, semente 1) no nível pedido, com o time de
## reservas da campanha do ciclo 5 (níveis ~40). Uso: testes/rodar.sh res://testes/medir_orre.gd [--nivel 527]
## [--minutos 60] [--sementes 2] [--slugs a,b,c] [--vip 1]

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")
const NovoJogo := preload("res://sim/servico_novo_jogo.gd")

var args := {"nivel": 527, "minutos": 60.0, "sementes": 2, "vip": 1,
	"slugs": "electrike,taillow,aron,poochyena,riolu,meditite,ralts,wingull,numel,enraged_typhlosion,ancient_pinsir,furious_scyther"}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		var k := String(a[i]).trim_prefix("--")
		if args.has(k) and i + 1 < a.size():
			args[k] = type_convert(a[i + 1], typeof(args[k]))
	var dados = DadosJogo.carregar()
	var ini: Dictionary = NovoJogo.criar(NovoJogo.INICIAL_CAMPANHA, 1, "Campanha", "campanha")["inicial"]
	var equipe := [{"id": "golem", "nome": "Golem", "xp": Regras.xp_total_para_nivel(int(args["nivel"])), "ivs": ini["ivs"], "quality": float(ini["quality"]), "hp": -1}]
	var rng = preload("res://sim/rng.gd").new(9173)
	for par in [["Sunflora", 41], ["Quilava", 41], ["Krabby", 40], ["Ariados", 41], ["Nidorina", 40]]:
		equipe.append({"id": String(par[0]), "nome": String(par[0]), "xp": Regras.xp_total_para_nivel(int(par[1])), "ivs": Regras.sortear_ivs(rng),
			"quality": Regras.sortear_qualidade(rng), "hp": -1})
	print("slug\tnivel\tarea\tmult\tmin\tabates_min\txp_h\tmortes")
	for slug in String(args["slugs"]).split(","):
		var mapa = MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao())
		var mins := 0.0
		var xp := 0
		var abates := 0
		var mortes := 0
		var mult := 1.0
		for s in int(args["sementes"]):
			var jogo := {"slug": slug, "hunt": slug, "equipe": equipe.duplicate(true), "lider": 0, "vip": int(args["vip"]) == 1,
				"penalizar": false, "auto_potion": true, "inventario": [{"itemId": 203, "quantity": 5000}], "treinador_xp": Regras.xp_total_para_nivel(int(args["nivel"]))}
			var sim = Simulacao.new(CenarioJogo.configurar(jogo, dados, 11 + s, 0), dados, mapa)
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
		print("%s\t%d\t%s\t%.1f\t%.1f\t%.2f\t%d\t%d" % [slug, int(dados.hunts[slug]["nivel"]), String(dados.hunts[slug]["area"]), mult, mins,
			abates / maxf(0.1, mins), int(xp / maxf(0.1, mins) * 60.0), mortes])
	quit(0)
