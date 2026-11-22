extends SceneTree
## Nível recomendado por hunt de Orre (ciclo 7). Para cada hunt de Orre, o menor nível do carregador em que o time da
## campanha do ciclo 6 (time_final + helds e TMs; reservas como ficaram) passa `--minutos` (60) sem morrer, por busca
## binária entre o nível da hunt e `--teto` (1100). Treinador = carregador + 5. Sim pura, VIP, Hyper Potion, sem penalidade.
## F (não validado; não há gravação de Orre): a dificuldade depende do dano dos selvagens de nível alto da sim.
## Saída: dados/gerados/orre_nivel_recomendado.json {slug: {nivel_hunt, nivel_lider, nivel_treinador}} (nivel_lider -1 = não
## jogável até o teto). Uso: testes/rodar.sh res://testes/nivel_orre.gd [--time saida.json] [--minutos 60] [--teto 1100]

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")
const Metas := preload("res://sim/metas.gd")

var args := {"time": "saida_testes/campanha_c6_time.json", "minutos": 60.0, "teto": 1100, "saida": "dados/gerados/orre_nivel_recomendado.json", "slugs": ""}
var dados
var base_time: Array = []
var helds := {}
var tms := {}


func _sobrevive(slug: String, mapa, nivel: int) -> bool:
	var eq := base_time.duplicate(true)
	var mx := 0
	for i in eq.size():
		if int(eq[i]["xp"]) > int(eq[mx]["xp"]):
			mx = i
	eq[mx]["xp"] = Regras.xp_total_para_nivel(nivel)
	# líder: o de maior Power × vantagem (a mesma escolha da campanha), com o carregador no nível testado
	var melhor := 0
	var mv := -1.0
	for i in eq.size():
		var sid := CenarioJogo.id_especie(dados, String(eq[i]["nome"]))
		var v := float(Metas.poder_lider(dados, {"speciesId": sid, "xp": int(eq[i]["xp"]), "ivs": eq[i]["ivs"], "quality": float(eq[i]["quality"])}))
		if v > mv:
			mv = v
			melhor = i
	var lider: Dictionary = eq[melhor]
	eq.remove_at(melhor)
	eq.push_front(lider)
	var jogo := {"slug": slug, "hunt": slug, "equipe": eq, "lider": 0, "vip": true, "penalizar": false, "auto_potion": true,
		"inventario": [{"itemId": 203, "quantity": 9000}], "treinador_xp": Regras.xp_total_para_nivel(nivel + 5), "helds": helds, "tms": tms}
	var sim = Simulacao.new(CenarioJogo.configurar(jogo, dados, 21, 0), dados, mapa)
	sim.iniciar()
	for t in int(float(args["minutos"]) * 300.0):
		sim.passo()
		if sim.encerrada:
			return false
	return true


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		var k := String(a[i]).trim_prefix("--")
		if args.has(k) and i + 1 < a.size():
			args[k] = type_convert(a[i + 1], typeof(args[k]))
	dados = DadosJogo.carregar()
	var c: Dictionary = Fontes.ler_json(String(args["time"]))
	for pk in c.get("time_final", []):
		base_time.append({"id": String(pk["id"]), "nome": String(pk["nome"]), "xp": int(pk["xp"]), "ivs": pk["ivs"], "quality": float(pk["quality"]), "hp": -1})
	helds = c.get("itens_uso", {}).get("held", {})
	tms = c.get("itens_uso", {}).get("tms", {})
	var slugs: Array = []
	for s in dados.hunts:
		if String(dados.hunts[s].get("area", "")).to_lower() == "orre" and (String(args["slugs"]) == "" or s in String(args["slugs"]).split(",")):
			slugs.append(s)
	slugs.sort_custom(func(x, y): return int(dados.hunts[x]["nivel"]) < int(dados.hunts[y]["nivel"]) or (int(dados.hunts[x]["nivel"]) == int(dados.hunts[y]["nivel"]) and x < y))
	var saida := {"_fonte": "F (não validado: não há gravação de Orre): testes/nivel_orre.gd, time da campanha do ciclo 6 (helds e TMs), 1 h sem morrer, VIP", "hunts": {}}
	for s in slugs:
		var mapa = MapaHunt.carregar(s, Fontes.ler_mapa(s), Fontes.ler_colisao())
		var lo := int(dados.hunts[s]["nivel"])
		var hi := int(args["teto"])
		var nivel := -1
		if _sobrevive(s, mapa, lo):
			nivel = lo
		elif _sobrevive(s, mapa, hi):
			while hi - lo > 10:
				var mid := (lo + hi) / 2
				if _sobrevive(s, mapa, mid):
					hi = mid
				else:
					lo = mid
			nivel = hi
		saida["hunts"][s] = {"nivel_hunt": int(dados.hunts[s]["nivel"]), "nivel_lider": nivel, "nivel_treinador": nivel + 5 if nivel > 0 else -1}
		print("ORRE ", s, " ", dados.hunts[s]["nivel"], " -> ", nivel)
	var f := FileAccess.open(String(args["saida"]), FileAccess.WRITE)
	f.store_string(JSON.stringify(saida, "  "))
	f.close()
	quit(0)
