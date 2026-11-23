extends RefCounted
## Ditto (ciclo 8). Puro e determinístico; tratar(estado, cmd) → mensagens.
##
## Do cliente (C, window.ditto.* e shop.diamond.item.ditto.*): o Ditto, como líder, se transforma em quase qualquer espécie
## por 12 h; transformado tem −25% de HP, Ataque, Defesa, Sp.Atk e Sp.Def (a Velocidade fica intacta); Lendários, Megas,
## bosses de Orre e Pokémon da Outland não podem ser copiados; Ditto não aprende TM nem breeda; stats fixos IV
## 15/15/15/15/14/15 (total 89) e Quality 1,4. O Shiny Ditto (permanente, penalidade menor) só existe pela loja de
## diamantes (online): fora do offline.
## Classe 3 (balanceamento.json "ditto"): fonte offline — um Ditto ao chegar no treinador 100 (no original vem da loja de
## diamantes). F: "Outland/bosses de Orre" = as formas especiais do snapshot (id ≥ 10000).
##
## Estado: itens_uso.ditto {pokeId: {speciesId, ate}}, ditto_recebido (bool).
## Comandos: ditto-receber {nivel} → o Ditto novo (o chamador põe na equipe/box); ditto-transformar {pokeId, speciesId,
## agora, lider}; ditto-reverter {pokeId}. para_sim(estado, agora) → {pokeId: speciesId}.

const Balanceamento := preload("res://sim/balanceamento.gd")
const DITTO := 132
const IVS := {"hp": 15, "atk": 15, "def": 15, "spAtk": 15, "spDef": 14, "speed": 15}   # C
const QUALITY := 1.4                                                                     # C

var p := {"duracao_s": 43200, "nivel_recebe": 100, "debuff": 0.25}
var dados


func _init(dados_jogo) -> void:
	dados = dados_jogo
	var b: Dictionary = Balanceamento.secao("ditto")
	for k in b:
		p[k] = b[k]


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


func copiavel(sid: int) -> String:
	## "" = pode copiar; senão o motivo (C: hintNormal).
	var e: Dictionary = dados.especie(sid)
	if e.is_empty() or sid == DITTO:
		return "Espécie inválida."
	if String(e.get("raridade", "")) in ["LEGENDARY", "MYTHICAL"]:
		return "Lendários não podem ser copiados."
	if String(e.get("nome", "")).begins_with("Mega "):
		return "Megas não podem ser copiados."
	if sid >= 10000:
		return "Bosses de Orre e Pokémon da Outland não podem ser copiados."
	return ""


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	if not estado.has("itens_uso"):
		estado["itens_uso"] = {}
	if not estado["itens_uso"].has("ditto"):
		estado["itens_uso"]["ditto"] = {}
	match String(cmd.get("type", "")):
		"ditto-receber":
			if bool(estado["itens_uso"].get("ditto_recebido", false)):
				return [_erro("Você já recebeu o Ditto.")]
			if int(cmd.get("nivel", 0)) < int(p.nivel_recebe):
				return [_erro("O Ditto chega no nível %d do treinador." % int(p.nivel_recebe))]
			estado["itens_uso"]["ditto_recebido"] = true
			return [{"type": "ditto-recebido", "poke": {"speciesId": DITTO, "ivs": IVS.duplicate(), "quality": QUALITY, "nivel": 1}}]
		"ditto-transformar":
			var id := String(cmd.get("pokeId", ""))
			var sid := int(cmd.get("speciesId", 0))
			if int(cmd.get("pokeSpecies", DITTO)) != DITTO:
				return [_erro("Só o Ditto se transforma.")]
			if not bool(cmd.get("lider", false)):
				return [_erro("Coloque o Ditto como líder para transformar.")]   # C: desc
			var m := copiavel(sid)
			if m != "":
				return [_erro(m)]
			var ate := int(cmd.get("agora", 0)) + int(p.duracao_s)
			estado["itens_uso"]["ditto"][id] = {"speciesId": sid, "ate": ate}
			return [{"type": "ditto-transformado", "pokeId": id, "speciesId": sid, "name": String(dados.especie(sid).get("nome", "")), "ate": ate}]
		"ditto-reverter":
			estado["itens_uso"]["ditto"].erase(String(cmd.get("pokeId", "")))
			return [{"type": "ditto-revertido", "pokeId": String(cmd.get("pokeId", ""))}]
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


func para_sim(estado: Dictionary, agora: int) -> Dictionary:
	var r := {}
	var d: Dictionary = estado.get("itens_uso", {}).get("ditto", {})
	for id in d:
		if int(d[id]["ate"]) > agora:
			r[String(id)] = int(d[id]["speciesId"])
	return r
