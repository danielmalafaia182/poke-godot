extends RefCounted
## Valores de classe 3 (ESTRATEGIA.md) em dados/balanceamento.json: decididos pelo design, com uma linha de motivo cada.
## Cada módulo da sim aplica a sua seção sobre os PARAMETROS dele (o código guarda só o valor de reserva, para a sim rodar
## sem o arquivo). Lido uma vez por processo; `recarregar()` para testes.

const Fontes := preload("res://sim/fontes.gd")

static var _dados: Dictionary = {}
static var _lido := false


static func dados() -> Dictionary:
	if not _lido:
		_lido = true
		var d = Fontes.ler_json(Fontes.pasta_dados() + "/balanceamento.json")
		_dados = d if d is Dictionary else {}
	return _dados


static func recarregar() -> void:
	_lido = false


static func secao(nome: String) -> Dictionary:
	## {chave: valor} da seção (sem os motivos).
	var r := {}
	var s = dados().get(nome, {})
	if s is Dictionary:
		for k in s:
			var e = s[k]
			r[k] = e.get("valor") if e is Dictionary and e.has("valor") else e
	return r


static func aplicar(p: Dictionary, nome: String) -> Dictionary:
	## Sobrepõe a seção sobre `p` (só as chaves que existem na seção) e devolve `p`.
	var s := secao(nome)
	for k in s:
		p[k] = s[k]
	return p


static func valor(nome_secao: String, chave: String, reserva = null):
	return secao(nome_secao).get(chave, reserva)
