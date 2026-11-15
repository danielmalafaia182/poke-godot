extends SceneTree
## Fase 4, lote 3 (começo): Rare Candy e berries (sim/servico_itens.gd) e o efeito das berries no combate
## (simulacao_hunt.gd). Puro, sem save. Rodar: testes/rodar.sh res://testes/test_sim_itens.gd

const Servico := preload("res://sim/servico_itens.gd")
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


static func tipo(msgs: Array, t: String) -> Dictionary:
	for m in msgs:
		if String(m.get("type", "")) == t:
			return m
	return {}


func rodar(dados, mapa, extra: Dictionary, segundos: int) -> Dictionary:
	var cfg := Cenario.de_estado(Sim.caminho_absoluto(ESTADO), dados, 5)
	for k in extra:
		cfg[k] = extra[k]
	var s = Simulacao.new(cfg, dados, mapa)
	s.iniciar()
	var rec := 0
	var nrec := 0
	var curas: Array = []
	var linhas: Array = []
	for t in segundos * 5:
		for reg in s.passo():
			var m: Dictionary = reg.get("msg", reg)
			linhas.append(JSON.stringify(m))
			if String(m.get("type", "")) == "field":
				for h in m.get("hits", []):
					if int(h["slot"]) < 0:
						rec += int(h["amount"])
						nrec += 1
			if String(m.get("type", "")) == "auto-heal":
				curas.append(int(m["heal"]))
	return {"rec": float(rec) / maxf(1.0, nrec), "n": nrec, "curas": curas, "texto": "\n".join(linhas), "id": String(s.equipe[0].get("id", ""))}


func _init() -> void:
	var dados = DadosJogo.carregar()
	var sv = Servico.new(dados)

	# ---------------------------------------------------------------- berries: efeito pela descrição (A)
	var reconhecidas := 0
	var berries := 0
	var rocha := -1
	var cura_id := -1
	for id in dados.itens:
		if String(dados.itens[id].get("categoria", "")) == "berry":
			berries += 1
			var ef: Dictionary = sv.efeito_berry(int(id))
			if not ef.is_empty():
				reconhecidas += 1
				if String(ef["efeito"]) == "ROCK" and int(ef["pct"]) == 10:
					rocha = int(id)
				if String(ef["efeito"]) == "heal" and int(ef["pct"]) == 80:
					cura_id = int(id)
	checar(berries == 40 and reconhecidas == 40, "40/40 berries com efeito lido da descrição do items.json (A)", "%d/%d" % [reconhecidas, berries])
	checar(cura_id == 44457, "Wild Rovia Berry = +80% de cura das poções (A)")

	# ---------------------------------------------------------------- Rare Candy (C + A)
	var e := {"itens": {"90124": 12, str(rocha): 2, "44457": 1}, "pokes": [
		{"id": "a", "speciesId": 246, "xp": Regras.xp_total_para_nivel(5) + 37, "team": true},
		{"id": "b", "speciesId": 246, "xp": Regras.xp_total_para_nivel(5), "team": false},
		{"id": "c", "speciesId": 246, "xp": Regras.xp_total_para_nivel(101), "team": true}]}
	var r: Array = sv.tratar(e, {"type": "use-candy", "pokeId": "a"})
	var cu: Dictionary = tipo(r, "candy-used")
	checar(int(cu.get("level", 0)) == 6 and int(e["pokes"][0]["xp"]) == Regras.xp_total_para_nivel(6) and int(e["itens"]["90124"]) == 11,
		"Rare Candy: exatamente o XP que falta para o próximo nível (A), +1 nível (C)", JSON.stringify(cu))
	checar(tipo(sv.tratar(e, {"type": "use-candy", "pokeId": "b"}), "error").size() > 0, "Pokémon fora do time: recusa (A/C)")
	checar(tipo(sv.tratar(e, {"type": "use-candy", "pokeId": "c"}), "error").size() > 0, "acima do nível 100: recusa (C)")
	for i in 9:
		sv.tratar(e, {"type": "use-candy", "pokeId": "a"})
	checar(Regras.nivel_por_xp(int(e["pokes"][0]["xp"])) == 15 and tipo(sv.tratar(e, {"type": "use-candy", "pokeId": "a"}), "error").size() > 0
		and int(e["itens"]["90124"]) == 2, "10 Rare Candies por Pokémon; o 11º é recusado (C)")
	var vazio := {"itens": {}, "pokes": [{"id": "x", "speciesId": 246, "xp": 0, "team": true}]}
	checar(tipo(sv.tratar(vazio, {"type": "use-candy", "pokeId": "x"}), "error").size() > 0, "sem Rare Candy: recusa")

	# ---------------------------------------------------------------- berries: uso (C)
	r = sv.tratar(e, {"type": "use-berry", "itemId": rocha, "pokeId": "a", "agora": AGORA})
	var bu: Dictionary = tipo(r, "berry-used")
	checar(int(bu.get("until", 0)) == (AGORA + 1800) * 1000 and String(bu["efeito"]) == "ROCK" and int(e["itens"][str(rocha)]) == 1,
		"berry consumida na hora, efeito por 30 min (C)")
	checar(String(tipo(sv.tratar(e, {"type": "use-berry", "itemId": rocha, "pokeId": "a", "agora": AGORA + 60}), "error").get("message", "")).begins_with("Já ativa (29"),
		"a mesma berry não acumula: 'já ativa (29 min)' (C)")
	checar(tipo(sv.tratar(e, {"type": "use-berry", "itemId": 44457, "pokeId": "a", "agora": AGORA}), "berry-used").size() > 0, "outra berry no mesmo Pokémon: aceita (E)")
	checar(tipo(sv.tratar(e, {"type": "use-berry", "itemId": rocha, "pokeId": "b", "agora": AGORA}), "error").size() > 0, "berry só no time (C)")
	var at: Dictionary = sv.berries_ativas(e, AGORA + 100)
	checar(at.has("a") and (at["a"] as Array).size() == 2 and sv.berries_ativas(e, AGORA + 1801).is_empty(), "berries ativas para a sim; somem depois de 30 min")
	checar(tipo(sv.tratar(e, {"type": "use-berry", "itemId": rocha, "pokeId": "a", "agora": AGORA + 1801}), "berry-used").size() > 0, "vencida, pode comer de novo")
	checar(tipo(sv.tratar(e, {"type": "use-berry", "itemId": 90124, "pokeId": "a", "agora": AGORA}), "error").size() > 0, "Rare Candy não é berry")

	# ---------------------------------------------------------------- efeito no combate (Venusaur × Rhydon: Stone Edge, ROCK)
	var cfg0 := Cenario.de_estado(Sim.caminho_absoluto(ESTADO), dados, 5)
	var mapa = MapaHunt.carregar(cfg0["slug"], Fontes.ler_mapa(cfg0["slug"]), Fontes.ler_colisao())
	var base := rodar(dados, mapa, {}, 240)
	var id := String(base["id"])
	var vazio_b := rodar(dados, mapa, {"berries": {}}, 240)
	checar(vazio_b["texto"] == base["texto"], "sem berry ativa: saída da sim idêntica")
	var fim := int(cfg0["inicio_ms"]) + 3600 * 1000
	var com := rodar(dados, mapa, {"berries": {id: [{"efeito": "ROCK", "pct": 10, "until": fim}]}}, 240)
	var razao := float(com["rec"]) / float(base["rec"])
	checar(razao > 0.85 and razao < 0.95, "berry de Pedra 10%: dano recebido médio ~0,9× (Stone Edge)", "%.1f × %.1f (%.3f)" % [com["rec"], base["rec"], razao])
	var cura := rodar(dados, mapa, {"berries": {id: [{"efeito": "heal", "pct": 80, "until": fim}]}}, 240)
	var max_c := 0
	for c in cura["curas"]:
		max_c = maxi(max_c, int(c))
	var max_b := 0
	for c in base["curas"]:
		max_b = maxi(max_b, int(c))
	checar(max_b <= 1000 and max_c > 1000, "berry de cura +80%: a Hyper Potion passa de 1000 (limitada ao que falta)", "máx %d × %d" % [max_c, max_b])
	var vencida := rodar(dados, mapa, {"berries": {id: [{"efeito": "ROCK", "pct": 10, "until": int(cfg0["inicio_ms"]) - 1}]}}, 240)
	checar(vencida["texto"] == base["texto"], "berry vencida não pesa")

	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
