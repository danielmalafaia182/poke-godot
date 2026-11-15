extends SceneTree
## Fase 4, lote 4 (começo): insígnias de ginásio (+ efeito na hunt), catálogo de bosses e calendário da invasão.
## Puro, sem save. Rodar: testes/rodar.sh res://testes/test_sim_mundo.gd

const Ginasios := preload("res://sim/servico_ginasios.gd")
const Invasao := preload("res://sim/servico_invasao.gd")
const Regras := preload("res://sim/regras.gd")
const Sim := preload("res://testes/rodar_sim.gd")
const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const ESTADO := "dados/testes/estado_rhydon_venusaur_1h.json"
const AGORA := 1794750000

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func rodar(dados, mapa, extra: Dictionary, segundos: int) -> Dictionary:
	var cfg := Cenario.de_estado(Sim.caminho_absoluto(ESTADO), dados, 5)
	for k in extra:
		cfg[k] = extra[k]
	var s = Simulacao.new(cfg, dados, mapa)
	s.iniciar()
	var kills: Array = []
	var linhas: Array = []
	for t in segundos * 5:
		for reg in s.passo():
			var m: Dictionary = reg.get("msg", reg)
			linhas.append(JSON.stringify(m))
			if String(m.get("type", "")) == "field-kill":
				kills.append(m)
	return {"kills": kills, "texto": "\n".join(linhas)}


func _init() -> void:
	var dados = DadosJogo.carregar()
	var cat: Variant = Fontes.ler_json(Fontes.pasta_snapshot() + "/game/bossCatalog.json")
	var g = Ginasios.new(dados, cat if cat is Array else [])
	# ---------------------------------------------------------------- insígnias (C)
	var e := {}
	checar(int(g.tratar(e, {"type": "ginasios-get", "agora": AGORA})[0]["active"]) == 0, "sem insígnias: 0 ativas")
	g.tratar(e, {"type": "insignia-ganha", "gymId": "pewter", "agora": AGORA})
	var m: Dictionary = g.tratar(e, {"type": "insignia-ganha", "gymId": "cerulean", "agora": AGORA})[0]
	checar(int(m["active"]) == 2 and int(m["xpPct"]) == 2 and int(m["dropPct"]) == 2 and int(m["max"]) == 18, "2 insígnias: +2% XP e +2% de rolagem extra (C)")
	checar(int(e["ginasios"]["insignias"]["pewter"]) == (AGORA + 172800) * 1000, "insígnia dura 48 h (C)")
	checar(g.ativas(e, AGORA + 172800) == 0, "depois de 48 h, vencida")
	g.tratar(e, {"type": "insignia-ganha", "gymId": "pewter", "agora": AGORA + 100000})
	checar(g.ativas(e, AGORA + 172800) == 1, "vencer de novo renova (C)")
	# ---------------------------------------------------------------- bosses (A: snapshot)
	var b: Array = g.tratar(e, {"type": "bosses-get"})[0]["bosses"]
	var com_id := 0
	var drops := 0
	for x in b:
		for d in x["drops"]:
			drops += 1
			if int(d["itemId"]) >= 0:
				com_id += 1
	checar(b.size() == 87, "catálogo de bosses: 87 (A)", str(b.size()))
	print("  drops com id no catálogo de itens: %d de %d" % [com_id, drops])
	checar(com_id > 0, "drops dos bosses ligados aos itens pelo nome")
	# ---------------------------------------------------------------- efeito na hunt
	var cfg0 := Cenario.de_estado(Sim.caminho_absoluto(ESTADO), dados, 5)
	var mapa = MapaHunt.carregar(cfg0["slug"], Fontes.ler_mapa(cfg0["slug"]), Fontes.ler_colisao())
	var base := rodar(dados, mapa, {}, 120)
	checar(rodar(dados, mapa, {"insignias": 0}, 120)["texto"] == base["texto"], "0 insígnias: saída da sim idêntica")
	var com := rodar(dados, mapa, {"insignias": 5}, 120)
	var k0: Dictionary = com["kills"][com["kills"].size() - 1]
	var bx := int(k0["xpParts"]["base"])
	checar(int(k0["xpParts"]["gym"]) == int(floor(bx * 0.05 + 1e-9)) and int(k0["pokeXp"]["parts"]["gym"]) == int(k0["xpParts"]["gym"]),
		"5 insígnias: parcela gym = floor(5% da base) no treinador e no Pokémon (C/F)", JSON.stringify(k0["xpParts"]))
	# ---------------------------------------------------------------- invasão (A: horários gravados)
	var iv = Invasao.new()
	var janelas := [["2026-11-09T03:10:00", "2026-11-09T03:30:00"], ["2026-11-09T17:10:00", "2026-11-09T17:30:00"],
		["2026-11-10T19:10:00", "2026-11-10T19:30:00"], ["2026-11-13T15:10:00", "2026-11-13T15:30:00"], ["2026-11-15T13:10:00", "2026-11-15T13:30:00"]]
	var ok_j := true
	for j in janelas:
		var ent := Time.get_unix_time_from_datetime_string(j[0]) * 1000
		var fim := Time.get_unix_time_from_datetime_string(j[1]) * 1000
		var st: Dictionary = iv.estado(ent - 5 * 60000)
		ok_j = ok_j and int(st["entryUntil"]) == ent and int(st["endsAt"]) == fim
	checar(ok_j, "5 janelas gravadas: entrada até hh:10, fim hh:30, horas UTC ímpares (A)")
	var e17 := Time.get_unix_time_from_datetime_string("2026-11-09T17:10:00") * 1000
	var obs := [[-671472, true, true], [-71419, true, false], [1128915, false, false]]   # 16:58:48 aberta; 17:08:48 fechada; 17:28:48 acabou (A)
	var ok_o := true
	for o in obs:
		var st2: Dictionary = iv.estado(e17 + int(o[0]))
		ok_o = ok_o and bool(st2["live"]) == bool(o[1]) and bool(st2["entryOpen"]) == bool(o[2])
	checar(ok_o, "live/entryOpen nos instantes gravados da rhydon-1h (A)")
	checar(not bool(iv.estado(Time.get_unix_time_from_datetime_string("2026-11-09T18:15:00") * 1000)["live"]), "hora par: sem invasão")
	var an: Dictionary = iv.anuncio(e17 - 15 * 60000)
	checar(String(an["text"]).contains("{nome}") and String(an["text"]).begins_with("ATENÇÃO A CIDADE DE CERULEAN"), "anúncio com o texto gravado e {nome} literal (A)")
	checar(int(iv.energia(e17, 12)["energy"]) == 10 and int(iv.energia(e17, 12)["max"]) == 10, "energia máxima 10 (A)")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
