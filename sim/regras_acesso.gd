extends RefCounted
## Acesso às hunts (C: cliente 0gx72gz9qjk5j.js, janela do mapa `tA` e o clique no marcador). Puro.
##
##   - Regiões: Kanto 0, Outland 150, Orre 500, Nightmare 2000 (nível do TREINADOR; `tB[].unlock`); Johto
##     `available: false` ("em desenvolvimento"). Mensagem: "{area} desbloqueia no nível {level}. 🔒".
##   - Hunt: nível do treinador ≥ nível da hunt (`e.level > 0 && s < e.level`). Mensagem: "Você precisa ser nível
##     {level} para caçar em {name}. 🔒". `playerLevel` = `level` do field-kill = nível do treinador (C/A).
##   - Orre: se o líder não tem os TMs AoE e de elemento ativos (`leaderTmsOk` = tms contém "AOE" e outro), o cliente
##     pergunta "Para caçar adequadamente…, ainda assim, deseja entrar?" (Sim/Não) e deixa entrar. Aviso, não bloqueio.
##     O jogo ainda não tem TMs (lote 3, congelado): o aviso aparece sempre em Orre (E).
##   - Nada de item, insígnia, passagem ou custo de viagem entre regiões no cliente (C): o clique manda direto para a hunt.
##   - Não verificado: se o servidor recusa `enter-hunt` sem o nível (o cliente nunca manda). Sem gravação (F: igual ao
##     cliente). `hunt-cooldown {ms}` (C: o servidor pode adiar a entrada; o cliente reenvia depois de ms + 100) não
##     aparece em nenhuma gravação: não simulado.

const DESBLOQUEIO_AREA := {"kanto": 0, "outland": 150, "orre": 500, "nightmare": 2000}   # C
const NOMES_AREA := {"kanto": "Kanto", "outland": "Outland", "orre": "Orre", "nightmare": "Nightmare"}


static func verificar(area: String, nivel_hunt: int, nome_hunt: String, nivel_treinador: int, tms_lider_ok: bool = false) -> Dictionary:
	## {ok, motivo ("" | "area" | "nivel"), texto, confirmar (true = perguntar o aviso de TMs de Orre antes de entrar)}.
	var a := area if area != "" else "kanto"
	var desbloqueio := int(DESBLOQUEIO_AREA.get(a, 0))
	if desbloqueio > 0 and nivel_treinador < desbloqueio:
		return {"ok": false, "motivo": "area", "confirmar": false,
			"texto": "%s desbloqueia no nível %d. 🔒" % [String(NOMES_AREA.get(a, a)), desbloqueio]}
	if nivel_hunt > 0 and nivel_treinador < nivel_hunt:
		return {"ok": false, "motivo": "nivel", "confirmar": false,
			"texto": "Você precisa ser nível %d para caçar em %s. 🔒" % [nivel_hunt, nome_hunt]}
	var confirmar := a == "orre" and not tms_lider_ok
	return {"ok": true, "motivo": "", "confirmar": confirmar,
		"texto": "Para caçar adequadamente na área adequada, é necessário que seu pokemon tenha os TMs AoE e de elemento ativos. Ainda assim, deseja entrar?" if confirmar else ""}


static func hunts_liberadas(hunts: Array, nivel_treinador: int) -> Array:
	## Slugs que o treinador pode entrar (sem contar o aviso de Orre), na ordem de `hunts` (dados/gerados/hunts.json).
	var r: Array = []
	for h in hunts:
		if bool(verificar(String(h.get("area", "kanto")), int(h.get("nivel", 0)), String(h.get("nome", "")), nivel_treinador)["ok"]):
			r.append(String(h["slug"]))
	return r
