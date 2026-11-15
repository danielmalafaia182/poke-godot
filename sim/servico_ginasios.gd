extends RefCounted
## Fase 4, lote 4 (começo): ginásios (insígnias) e catálogo de bosses. Puro e determinístico ("agora" no comando, em
## segundos unix). tratar(estado, cmd) → mensagens.
##
## O que tem fonte e entrou:
##   - Insígnias (C, janela Gym Rewards): "A badge LASTS 48h — beat the leader again to renew it. Each ACTIVE badge grants
##     +1% XP and +1% chance of an extra drop roll"; 18 ginásios ("Defeat all 18 gyms — Kanto and Johto"); a janela conta
##     8 em Kanto e 10 na outra região (C: `total: "kanto" === e ? 8 : 10`). O efeito na hunt está na simulação
##     (cfg.insignias → parcela `gym` e rolagem extra; PARAMETROS insignia_pct_*).
##   - Ginásios conhecidos (A, mensagens gym-global gravadas): spikemuth DARK (NPC Piers), cerulean WATER, mahogany ICE
##     (NPC Pryce), pewter ROCK.
##   - Bosses (A, snapshot game/bossCatalog.json): 87, com nome, categoria, nível e nomes dos drops (sem HP, golpes nem
##     chances); os drops ganham o id pelo nome no catálogo de itens.
## O que NÃO entrou (vem do servidor, não gravado): a lista dos 18 líderes com times, a luta de ginásio, a disputa de
## liderança e o pagamento diário (online), a luta de boss (HP, golpes, rounds), as fichas de entrada e as chances de drop.
## Enquanto a luta não existe, a insígnia entra pelo comando `insignia-ganha` (E: é o resultado de vencer o líder).
##
## Estado: ginasios: {insignias: {"<gymId>": until_ms}}
## Comandos: ginasios-get {agora}, insignia-ganha {gymId, agora}, bosses-get

const PARAMETROS := {
	"insignia_duracao_s": 48 * 3600,   # C: "A badge LASTS 48h"
	"ginasios_total": 18,              # C
	"ginasios_por_regiao": {"kanto": 8, "outra": 10},   # C (a 2ª região é Johto no texto; a lista vem do servidor)
	"ginasios_conhecidos": {"spikemuth": {"tipo": "DARK", "lider_npc": "Piers"}, "cerulean": {"tipo": "WATER"},
		"mahogany": {"tipo": "ICE", "lider_npc": "Pryce"}, "pewter": {"tipo": "ROCK"}},   # A: gym-global
}

var p: Dictionary = PARAMETROS.duplicate(true)
var dados
var bosses: Array = []


func _init(dados_jogo, catalogo_bosses: Array = [], parametros: Dictionary = {}) -> void:
	dados = dados_jogo
	for k in parametros:
		p[k] = parametros[k]
	var por_nome := {}
	if dados != null:
		for id in dados.itens:
			por_nome[String(dados.itens[id].get("nome", "")).to_lower()] = int(id)
	for b in catalogo_bosses:
		var drops: Array = []
		for n in b.get("drops", []):
			drops.append({"name": String(n), "itemId": int(por_nome.get(String(n).to_lower(), -1))})
		bosses.append({"key": String(b.get("key", "")), "name": String(b.get("name", "")), "category": String(b.get("category", "")),
			"level": int(b.get("level", 0)), "drops": drops})


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	if not estado.has("ginasios"):
		estado["ginasios"] = {}
	if not estado["ginasios"].has("insignias"):
		estado["ginasios"]["insignias"] = {}
	var agora := int(cmd.get("agora", 0))
	match String(cmd.get("type", "")):
		"ginasios-get":
			return [msg_ginasios(estado, agora)]
		"insignia-ganha":
			var id := String(cmd.get("gymId", ""))
			if id.is_empty():
				return [_erro("Ginásio inválido.")]
			estado["ginasios"]["insignias"][id] = (agora + int(p.insignia_duracao_s)) * 1000   # C: vencer de novo renova
			return [msg_ginasios(estado, agora)]
		"bosses-get":
			return [{"type": "bosses", "bosses": bosses}]
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


func ativas(estado: Dictionary, agora: int) -> int:
	var n := 0
	for id in estado.get("ginasios", {}).get("insignias", {}):
		if int(estado["ginasios"]["insignias"][id]) > agora * 1000:
			n += 1
	return mini(n, int(p.ginasios_total))


func msg_ginasios(estado: Dictionary, agora: int) -> Dictionary:
	## E (formato próprio; o original manda `/api/game/gyms` com {gyms, details, regions}, não gravado).
	var lista: Array = []
	for id in estado["ginasios"]["insignias"]:
		var ate := int(estado["ginasios"]["insignias"][id])
		lista.append({"gymId": String(id), "until": ate, "active": ate > agora * 1000})
	var n := ativas(estado, agora)
	return {"type": "ginasios", "badges": lista, "active": n, "max": int(p.ginasios_total), "xpPct": n, "dropPct": n,
		"conhecidos": p.ginasios_conhecidos}
