extends RefCounted
## Contratos de configuração, independentes de UI e disco. Limites de integridade
## não mudam o balanceamento; impedem tipos inválidos, divisões por zero e NaN.

const POSITIVOS := ["tick_ms", "ticks_por_field", "hero_step_ms", "mob_step_ms",
	"trainer_step_ms", "fator_diagonal_passo", "streak_abates_por_ponto", "soneca_amostra_s",
	"peixes_por_nivel", "skill_max"]
const OPCOES := {
	"formula_dano": ["atual", "sem_piso_divisor", "classica", "mais2_fim"],
	"arredondamento_dano": ["round", "floor"],
	"stats_dano_aliado": ["inteiro", "continuo"],
	"stats_dano_selvagem": ["inteiro", "continuo"],
	"alvo_criterio": ["caminho", "chebyshev"],
	"captura_valor_bola": ["ouro", "eficiencia"],
	"penalidade_loot": ["chance", "quantidade"],
	"craft_cura_rank": ["E", "D", "C", "B", "A", "S"],
	"craft_neutra_rank": ["E", "D", "C", "B", "A", "S"],
}
const CAMPOS_TABELAS := {
	"especies": ["xpAbate", "precoNpc", "valorVenda", "raridade", "nivelHunt"],
	"loot": ["chanceBruta", "min", "max"],
	"hunts": ["nivel"],
	"itens": ["precoNpc", "precoGold", "cura"],
}


static func nome_perfil(nome: String) -> bool:
	if nome.is_empty() or nome.length() > 64 or nome.to_lower() == "scripts":
		return false
	for letra in nome:
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-".contains(letra):
			return false
	var reservado := nome.to_upper()
	if reservado in ["CON", "PRN", "AUX", "NUL", "CLOCK$"]:
		return false
	if reservado.length() == 4 and reservado.left(3) in ["COM", "LPT"] and reservado[3] in "123456789":
		return false
	return true


static func dados_puros(valor: Variant, nivel: int = 0) -> bool:
	if nivel > 16:
		return false
	if valor is float:
		return is_finite(valor)
	if valor == null or valor is bool or valor is int or valor is String:
		return true
	if valor is Array or valor is Dictionary:
		if valor.size() > 10000:
			return false
		for chave in valor:
			if valor is Dictionary:
				if not (chave is String or chave is int) or not dados_puros(valor[chave], nivel + 1):
					return false
			elif not dados_puros(chave, nivel + 1):
				return false
		return true
	return false


static func _tipo(valor: Variant, tipo: int) -> bool:
	if tipo in [TYPE_INT, TYPE_FLOAT]:
		return (valor is int or valor is float) and is_finite(float(valor)) and (tipo != TYPE_INT or float(valor) == floor(float(valor)))
	return typeof(valor) == tipo


static func campo(recurso: Resource, chave: String, valor: Variant) -> String:
	var prop := {}
	for p in recurso.get_property_list():
		if p.name == chave and int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(p.usage) & PROPERTY_USAGE_STORAGE:
			prop = p
			break
	if prop.is_empty():
		return "Campo desconhecido: " + chave
	if not dados_puros(valor) or not _tipo(valor, int(prop.type)):
		return "Tipo inválido em %s; esperado %s, sem objetos ou números não finitos." % [chave, type_string(int(prop.type))]
	if int(prop.hint) == PROPERTY_HINT_RANGE:
		var faixa := String(prop.hint_string).split(",")
		if faixa.size() >= 2:
			if not "or_less" in faixa and float(valor) < float(faixa[0]):
				return "%s deve ser pelo menos %s." % [chave, faixa[0]]
			if not "or_greater" in faixa and float(valor) > float(faixa[1]):
				return "%s deve ser no máximo %s." % [chave, faixa[1]]
	if chave in POSITIVOS and float(valor) <= 0.0:
		return chave + " deve ser maior que zero."
	if OPCOES.has(chave) and not valor in OPCOES[chave]:
		return "Opção inválida para " + chave
	# Mantém os tipos internos conhecidos, permitindo mapas parciais por região/id.
	var padrao = recurso.get_script().get_property_default_value(chave)
	if padrao is Array and padrao.is_typed() and valor is Array:
		for item in valor:
			if not _tipo(item, padrao.get_typed_builtin()):
				return "Tipo inválido dentro de " + chave
	if valor is Dictionary and padrao is Dictionary:
		for k in valor:
			if padrao.has(k) and not _tipo(valor[k], typeof(padrao[k])):
				return "Tipo inválido em %s.%s." % [chave, str(k)]
	return ""


static func conjunto(recurso: Resource) -> String:
	for par in [["aleatorio_min", "aleatorio_max"], ["catch_mult_min", "catch_mult_max"]]:
		var menor = recurso.get(par[0])
		var maior = recurso.get(par[1])
		if menor != null and maior != null and float(menor) > float(maior):
			return "%s não pode superar %s." % par
	return ""


static func alteracao(tabela: String, chave: Dictionary, valor: Variant) -> String:
	if not CAMPOS_TABELAS.has(tabela) or not chave.get("campo", "") in CAMPOS_TABELAS[tabela]:
		return "Tabela ou campo desconhecido."
	var ids := ["especie", "itemId"] if tabela == "loot" else ["id"]
	if chave.size() != ids.size() + 1:
		return "Chave de tabela inválida."
	for id in ids:
		var v = chave.get(id)
		if tabela == "hunts":
			if not v is String or not nome_perfil(v):
				return "Hunt inválida."
		elif not _tipo(v, TYPE_INT) or int(v) <= 0:
			return "Identificador inválido."
	if chave.campo == "raridade":
		return "" if valor is String and valor in ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC"] else "Raridade inválida."
	if not _tipo(valor, TYPE_INT) or float(valor) < 0 or float(valor) > 2147483647:
		return "Use um inteiro não negativo de até 2147483647."
	if chave.campo in ["nivel", "nivelHunt"] and int(valor) < 1:
		return "O nível deve ser pelo menos 1."
	if chave.campo == "chanceBruta" and int(valor) > 100000:
		return "Chance de loot deve ficar entre 0 e 100000."
	return ""
