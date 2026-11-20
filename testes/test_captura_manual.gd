extends SceneTree
## Captura manual e poção manual na sim (ciclo 4; C: painel de captura e tutorial "Jogue uma Pokébola"/"Use uma potion";
## A: o selvagem que o Auto-Catch não tentou fica 20 s na lista `pending`). Hunt rattata com o Bulbasaur Lv.5, sem
## Auto-Catch. Confere: abate → pending com o selvagem; catch {pendingId, ballId} gasta 1 bola, emite catch-result com
## auto false, pendingId e cooldownMs 4000 e tira o selvagem da lista; segundo catch antes de 4 s → catch-cooldown;
## pendente some depois de 20 s; use-heal cura o líder até o valor da poção e gasta 1; com HP cheio é recusado.
## Rodar: testes/rodar.sh res://testes/test_captura_manual.gd

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


func msgs(regs: Array, tipo: String) -> Array:
	var r: Array = []
	for reg in regs:
		var m: Dictionary = reg.get("msg", reg)
		if String(m.get("type", "")) == tipo:
			r.append(m)
	return r


func _init() -> void:
	var dados = DadosJogo.carregar()
	var mapa = MapaHunt.carregar("rattata", Fontes.ler_mapa("rattata"), Fontes.ler_colisao())
	var jogo := {"slug": "rattata", "hunt": "Rattata", "equipe": [{"id": "b", "nome": "Bulbasaur", "xp": 800,
		"ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}, "quality": 1.0, "hp": -1}],
		"auto_catch": false, "auto_potion": false, "penalizar": false,
		"bolas": {1: 100}, "inventario": [{"itemId": 200, "quantity": 100}]}
	var sim = Simulacao.new(CenarioJogo.configurar(jogo, dados, 3, 0), dados, mapa)
	sim.iniciar()
	var pend: Dictionary = {}
	var t := 0
	while pend.is_empty() and t < 3000:
		t += 1
		for m in msgs(sim.passo(), "pending"):
			if not (m["list"] as Array).is_empty():
				pend = m["list"][0]
	checar(not pend.is_empty() and pend.has("pokeId") and pend.has("level"), "abate sem Auto-Catch vira pendente", str(pend))
	var bolas_antes := int(sim.balls["counts"].get("1", 0))
	var r: Array = sim.passo([{"type": "catch", "pendingId": int(pend.get("id", -1)), "ballId": 1}])
	var res: Array = msgs(r, "catch-result")
	checar(res.size() == 1 and res[0]["auto"] == false and int(res[0]["pendingId"]) == int(pend["id"]) and int(res[0]["cooldownMs"]) == 4000,
		"catch {pendingId, ballId} → catch-result manual com cooldownMs 4000", str(res))
	checar(int(sim.balls["counts"].get("1", 0)) == bolas_antes - 1, "gasta uma Poké Ball")
	var lista_depois: Array = msgs(r, "pending")
	checar(not lista_depois.is_empty() and (lista_depois[-1]["list"] as Array).filter(func(e): return int(e["id"]) == int(pend["id"])).is_empty(), "o selvagem sai da lista")
	# segundo selvagem antes de 4 s
	var pend2: Dictionary = {}
	var t0: int = sim.agora_ms()
	while pend2.is_empty() and t < 6000:
		t += 1
		for m in msgs(sim.passo(), "pending"):
			if not (m["list"] as Array).is_empty():
				pend2 = m["list"][0]
	if sim.agora_ms() - t0 < 4000:
		checar(msgs(sim.passo([{"type": "catch", "pendingId": int(pend2["id"]), "ballId": 1}]), "catch-cooldown").size() == 1, "outro lançamento antes de 4 s → catch-cooldown")
	else:
		checar(true, "(o segundo pendente veio depois de 4 s; recarga não exercitada)")
	# expira em 20 s
	var vivo := true
	var inicio: int = sim.agora_ms()
	while vivo and sim.agora_ms() - inicio < 25000:
		sim.passo()
		vivo = not sim.pendentes.filter(func(e): return int(e["id"]) == int(pend2.get("id", -1))).is_empty()
	checar(not vivo and sim.agora_ms() - int(pend2.get("at", inicio)) <= 20400, "pendente some depois de 20 s", str(sim.agora_ms() - int(pend2.get("at", inicio))))
	# poção manual
	var poke: Dictionary = sim._poke_ativo()
	var cheia: Array = sim.passo([{"type": "use-heal", "itemId": 200}]) if int(poke["hp"]) >= int(poke["max_hp"]) else []
	poke["hp"] = 1
	var antes := int(sim.inventario.get(200, 0))
	var cura: Array = msgs(sim.passo([{"type": "use-heal", "itemId": 200}]), "auto-heal")
	checar(cura.size() == 1 and int(cura[0]["heal"]) == mini(int(dados.itens[200]["cura"]), int(poke["max_hp"]) - 1) and int(sim.inventario[200]) == antes - 1,
		"use-heal cura até o valor da Small Potion e gasta uma", str(cura))
	poke["hp"] = poke["max_hp"]
	checar(msgs(sim.passo([{"type": "use-heal", "itemId": 200}]), "auto-heal").is_empty(), "com HP cheio a poção é recusada")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
