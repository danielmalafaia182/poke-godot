extends RefCounted
## Fase 4, lote 4 (começo): calendário da invasão da Equipe Rocket. Puro ("agora" em ms). Só o horário e o formato das
## mensagens; a luta da invasão não foi gravada (fica para a gravação IV1).
##
## A (8 invasões gravadas, 09/11 a 15/11): a cada 2 h, nas horas UTC ÍMPARES; a entrada fecha às hh:10 (`entryUntil`) e a
## invasão termina às hh:30 (`endsAt`), 20 min depois. `invasion-state {live, entryOpen, entryUntil, endsAt}` e
## `invasion-energy {energy, max: 10, live, entryOpen, entryUntil, endsAt}`; anúncio `invasion-announce {text, until}` com
## "ATENÇÃO A CIDADE DE CERULEAN ESTÁ SENDO INVADIDA POR MEMBROS DA EQUIPE ROCKET, A POLÍCIA DE CERULEAN PEDE SEU
## AUXÍLIO, {nome}!".
## A, parcial: entrada vista aberta às hh−1:58:48, hh−1:59:23 e hh:00:11; fechada a partir de hh:08:48. `live` já falso às
## hh:28:48 e hh:28:56. F: abre às hh−0:02 (`abre_antes_s`), fecha 90 s antes do entryUntil (`fecha_antes_s`) e `live`
## acaba 75 s antes do endsAt (`termina_antes_s`).
## E: a cidade do anúncio é sempre Cerulean (a única gravada; o jogo offline só tem Cerulean como cidade jogável).

const PARAMETROS := {
	"periodo_s": 7200,           # A: a cada 2 h
	"fase_s": 3600,              # A: horas ímpares (hh:10 de 01, 03, …, 23 UTC)
	"entrada_min": 10,           # A: entryUntil = hh:10
	"duracao_s": 1200,           # A: endsAt − entryUntil = 20 min
	"abre_antes_s": 120,         # F
	"fecha_antes_s": 90,         # F
	"termina_antes_s": 75,       # F (A: live já falso 71,1 s antes do endsAt)
	"energia_max": 10,           # A
	"anuncio": "ATENÇÃO A CIDADE DE CERULEAN ESTÁ SENDO INVADIDA POR MEMBROS DA EQUIPE ROCKET, A POLÍCIA DE CERULEAN PEDE SEU AUXÍLIO, {nome}!",
}

var p: Dictionary = PARAMETROS.duplicate(true)


func _init(parametros: Dictionary = {}) -> void:
	for k in parametros:
		p[k] = parametros[k]


func janela(agora_ms: int) -> Dictionary:
	## A janela corrente ou a próxima: {entryUntil, endsAt} (ms).
	var t := agora_ms / 1000
	var per := int(p.periodo_s)
	var base := int(floor(float(t - int(p.fase_s)) / per)) * per + int(p.fase_s)   # início da hora ímpar ≤ agora
	var entrada := base + int(p.entrada_min) * 60
	var fim := entrada + int(p.duracao_s)
	if t >= fim:
		entrada += per
		fim += per
	return {"entryUntil": entrada * 1000, "endsAt": fim * 1000}


func estado(agora_ms: int) -> Dictionary:
	var j := janela(agora_ms)
	var abre := int(j["entryUntil"]) - (int(p.entrada_min) * 60 + int(p.abre_antes_s)) * 1000
	var live := agora_ms >= abre and agora_ms < int(j["endsAt"]) - int(p.termina_antes_s) * 1000
	var aberta := live and agora_ms < int(j["entryUntil"]) - int(p.fecha_antes_s) * 1000
	return {"type": "invasion-state", "live": live, "entryOpen": aberta, "entryUntil": int(j["entryUntil"]), "endsAt": int(j["endsAt"])}


func energia(agora_ms: int, energia_atual: int) -> Dictionary:
	var e := estado(agora_ms)
	return {"type": "invasion-energy", "energy": clampi(energia_atual, 0, int(p.energia_max)), "max": int(p.energia_max),
		"live": e["live"], "entryOpen": e["entryOpen"], "entryUntil": e["entryUntil"], "endsAt": e["endsAt"]}


func anuncio(agora_ms: int) -> Dictionary:
	## A: o texto vem com "{nome}" literal (o cliente troca pelo nome do jogador); until gravado 17:00:29 para a entrada das
	## 17:10 → F: until = entryUntil − 10 min.
	var e := estado(agora_ms)
	return {"type": "invasion-announce", "text": String(p.anuncio), "until": int(e["entryUntil"]) - int(p.entrada_min) * 60000}
