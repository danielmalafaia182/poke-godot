extends RefCounted
## Valores de classe 3 e todos os parâmetros editáveis do jogo. Desde o Game Master (perfis de regras) eles vêm dos
## Resources de dados/regras/ (sim/regras_jogo.gd): cada seção ("combate", "cidade", "diarias"…) é a união dos Resources
## dela. Os módulos da sim aplicam a sua seção sobre os PARAMETROS deles (o código guarda o valor de reserva, para a sim
## rodar sem os arquivos). `recarregar()` relê os .tres (testes, painel F12, editor).

const RegrasJogo := preload("res://sim/regras_jogo.gd")


static func recarregar() -> void:
	RegrasJogo.recarregar()


static func secao(nome: String) -> Dictionary:
	## {chave: valor} da seção.
	return RegrasJogo.secao(nome)


static func aplicar(p: Dictionary, nome: String) -> Dictionary:
	## Sobrepõe a seção sobre `p` e devolve `p`.
	var s := secao(nome)
	for k in s:
		p[k] = s[k]
	return p


static func valor(nome_secao: String, chave: String, reserva = null):
	return secao(nome_secao).get(chave, reserva)
