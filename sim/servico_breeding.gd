extends RefCounted
## Breeding (ciclo 6, backlog). Puro e determinístico; tratar(estado, cmd) → mensagens.
##
## Do cliente (C, textos window.breeding.*): dois pais da box viram um ovo e são CONSUMIDOS; Ditto não cruza; Quality do
## filho = melhor pai + Δ; caminho com feromônio dá o Δ cheio (+0,15 a +0,30), o caminho livre um Δ ~20× menor (só sem pai
## shiny); por stat, N% copia o IV do MELHOR pai, senão re-rola 1..32; gastar o dobro de pedras dá 5% de +1 num stat
## (sobre o IV do pai de maior quality); um pai shiny → o filho SEMPRE nasce shiny; dois pais normais nunca geram shiny;
## os ovos chocam com derrotas nas hunts; incubadora com slots.
## Classe 3 (balanceamento.json "breeding", padrões abaixo): mesma espécie, filho no estágio base e nível 1, chance de
## herdar, abates para chocar, slots, pedras do tipo principal por ovo, 1 Strange Pheromone (item 44417, A: existe no
## catálogo e cai nas hunts) no caminho cheio, Quality máxima 1,8 (C: a maior faixa do rollQuality).
##
## Estado: breeding {ovos: [{speciesId, ivs, quality, shiny, faltam}], criados}. pokes como em ponte_cidade.estado_de.
## Comandos: breed {paiA, paiB, caminho: "feromonio"|"livre", dobro: bool, semente}; breeding-get.
## chocar(estado, abates) → pokes novos (o chamador põe na box).

const Regras := preload("res://sim/regras.gd")
const Balanceamento := preload("res://sim/balanceamento.gd")
const Rng := preload("res://sim/rng.gd")

var p := {
	"herdar_pct": 50.0,
	"abates_chocar": 500,
	"slots": 2,
	"pedras_por_ovo": 2,
	"feromonio_id": 44417,
	"delta": [0.15, 0.30],
	"delta_livre_div": 20.0,
	"quality_max": 1.8,
	"iv_mais1_pct": 5.0,
}
var dados


func _init(dados_jogo) -> void:
	dados = dados_jogo
	var b: Dictionary = Balanceamento.secao("breeding")
	for k in b:
		p[k] = b[k]


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


func _est(estado: Dictionary) -> Dictionary:
	if not estado.has("breeding"):
		estado["breeding"] = {}
	var e: Dictionary = estado["breeding"]
	if not e.has("ovos"):
		e["ovos"] = []
	if not e.has("criados"):
		e["criados"] = 0
	return e


func estagio_base(sid: int) -> int:
	## A espécie que evolui para `sid`, recursivamente (o filho nasce no começo da linha, classe 3).
	var atual := sid
	for _i in 4:
		var achou := -1
		for k in dados.especies:
			var ev = dados.especies[k].get("evolui")
			if ev is Dictionary and int(ev.get("para", -1)) == atual:
				achou = int(k)
				break
		if achou < 0:
			break
		atual = achou
	return atual


func pedra_do_tipo(sid: int) -> int:
	var t := String(Regras.tipos_de(dados.especie(sid))[0]).to_lower()
	for id in dados.itens:
		var it: Dictionary = dados.itens[id]
		if String(it.get("categoria", "")) == "stone" and String(it.get("nome", "")).to_lower().begins_with(t):
			return int(id)
	return -1


func _poke(estado: Dictionary, id: String) -> Dictionary:
	for pk in estado.get("pokes", []):
		if String(pk.get("id", "")) == id:
			return pk
	return {}


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	var e := _est(estado)
	match String(cmd.get("type", "")):
		"breeding-get":
			return [{"type": "breeding", "ovos": e["ovos"].duplicate(true), "slots": int(p.slots)}]
		"breed":
			return _breed(estado, e, cmd)
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


func _breed(estado: Dictionary, e: Dictionary, cmd: Dictionary) -> Array:
	var a := _poke(estado, String(cmd.get("paiA", "")))
	var b := _poke(estado, String(cmd.get("paiB", "")))
	if a.is_empty() or b.is_empty() or a == b:
		return [_erro("Escolha os 2 pais.")]
	if bool(a.get("team", false)) or bool(b.get("team", false)):
		return [_erro("Os pais saem da box.")]
	for x in [a, b]:
		if String(dados.especie(int(x["speciesId"])).get("nome", "")) == "Ditto":
			return [_erro("Ditto não pode breedar.")]   # C: reasonDitto
	if int(a["speciesId"]) != int(b["speciesId"]):
		return [_erro("Os pais precisam ser da mesma espécie.")]
	if (e["ovos"] as Array).size() >= int(p.slots):
		return [_erro("Incubadora cheia — choque um ovo primeiro.")]   # C: slotsFullHint
	var shiny := bool(a.get("shiny", false)) or bool(b.get("shiny", false))
	var caminho := String(cmd.get("caminho", "livre"))
	if caminho == "livre" and shiny:
		return [_erro("O caminho livre é só para breeds sem pai shiny.")]   # C: freePathHint
	var dobro := bool(cmd.get("dobro", false))
	var pedra := pedra_do_tipo(int(a["speciesId"]))
	var n_pedras := int(p.pedras_por_ovo) * (2 if dobro else 1)
	var custo := {}
	if pedra > 0:
		custo[str(pedra)] = n_pedras
	if caminho == "feromonio":
		custo[str(int(p.feromonio_id))] = int(custo.get(str(int(p.feromonio_id)), 0)) + 1
	for k in custo:
		if int(estado.get("itens", {}).get(k, 0)) < int(custo[k]):
			return [_erro("Recursos insuficientes")]   # C: notEnough
	for k in custo:
		estado["itens"][k] = int(estado["itens"][k]) - int(custo[k])
		if int(estado["itens"][k]) <= 0:
			estado["itens"].erase(k)
	var rng = Rng.new(int(cmd.get("semente", 1)))
	var melhor: Dictionary = a if float(a["quality"]) >= float(b["quality"]) else b
	var d: Array = p.delta
	var delta := float(d[0]) + rng.randf() * (float(d[1]) - float(d[0]))
	if caminho != "feromonio":
		delta /= float(p.delta_livre_div)
	var ivs := {}
	for k in Regras.CHAVES_STATS:
		ivs[k] = int(melhor["ivs"][k]) if rng.randf() * 100.0 < float(p.herdar_pct) else 1 + int(floor(32.0 * rng.randf()))
	if dobro and rng.randf() * 100.0 < float(p.iv_mais1_pct):
		var k: String = Regras.CHAVES_STATS[int(rng.randf() * Regras.CHAVES_STATS.size()) % Regras.CHAVES_STATS.size()]
		ivs[k] = mini(32, int(ivs[k]) + 1)
	var ovo := {"speciesId": estagio_base(int(a["speciesId"])), "ivs": ivs, "quality": minf(float(p.quality_max), snappedf(float(melhor["quality"]) + delta, 0.001)),
		"shiny": shiny, "faltam": int(p.abates_chocar)}
	estado["pokes"].erase(a)
	estado["pokes"].erase(b)
	e["ovos"].append(ovo)
	e["criados"] = int(e["criados"]) + 1
	return [{"type": "breed-egg", "ovo": ovo.duplicate(true), "consumidos": [String(a["id"]), String(b["id"])], "custo": custo}]


func chocar(estado: Dictionary, abates: int) -> Array:
	## C: "Os ovos chocam com derrotas nas hunts". Devolve os filhos {speciesId, ivs, quality, shiny, xp} que nasceram.
	var e := _est(estado)
	var nasc: Array = []
	for ovo in (e["ovos"] as Array).duplicate():
		ovo["faltam"] = int(ovo["faltam"]) - abates
		if int(ovo["faltam"]) <= 0:
			e["ovos"].erase(ovo)
			nasc.append({"speciesId": int(ovo["speciesId"]), "ivs": ovo["ivs"], "quality": float(ovo["quality"]), "shiny": bool(ovo["shiny"]),
				"xp": Regras.xp_total_para_nivel(1)})
	return nasc
