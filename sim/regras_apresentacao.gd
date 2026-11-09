extends RefCounted
## Regras de apresentação da hunt que são decisões do usuário (E, CLAUDE.md), separadas da vista para terem teste:
##   - cartão de derrota: um por vez e sem fila — enquanto um cartão está na tela, um abate novo não abre outro, não
##     substitui nem estende o atual; no máximo 30 exibições por instância. Só limita a apresentação: XP, loot e
##     captura continuam vindo de todos os abates (eles não passam por aqui).
##   - contador "Capture": conta as capturas da instância e zera a cada nova instância de hunt; sem mensagem de texto.
## Tempos do cartão (E/F, herdados do projeto P04 em cartoes_derrota.gd): 4500 ms (7000 se shiny) + 220 ms de saída.
## Puro: o relógio vem de fora (ms).

const DURACAO_MS := 4500
const DURACAO_SHINY_MS := 7000
const SAIDA_MS := 220
const MAX_POR_INSTANCIA := 30

var hunt_key := ""
var exibidos := 0
var _livre_em := -1          # instante em que o cartão atual some (inclui a saída)
var capturas := 0


func nova_instancia(chave: String) -> void:
	## Chamar no field-init. Retomada (mesma chave) mantém os contadores; instância nova zera.
	if chave == hunt_key:
		return
	hunt_key = chave
	exibidos = 0
	_livre_em = -1
	capturas = 0


func mostrar_cartao(evento: Dictionary, agora_ms: int) -> bool:
	## field-kill → abre cartão? (true) Atualiza o estado só quando abre.
	if exibidos >= MAX_POR_INSTANCIA:
		return false
	if _livre_em >= 0 and agora_ms < _livre_em:
		return false
	exibidos += 1
	var dur := DURACAO_SHINY_MS if bool(evento.get("shiny", false)) else DURACAO_MS
	_livre_em = agora_ms + dur + SAIDA_MS
	return true


func cartao_visivel(agora_ms: int) -> bool:
	return _livre_em >= 0 and agora_ms < _livre_em


func ao_resultado_captura(msg: Dictionary) -> int:
	## catch-result → valor do contador "Capture" desta instância.
	if bool(msg.get("success", false)):
		capturas += 1
	return capturas
