extends RefCounted

# Revisão: valida o contrato local antes de indexar a grade ou dividir por tempos.
# Não executa scripts nem carrega caminhos declarados no JSON.
static func validar(dados: Variant) -> String:
	if not dados is Dictionary:
		return "A navegação deve ser um objeto JSON."
	for chave in ["rows","cols","minTx","minTy","heroStepMs","mobStepMs"]:
		var valor: Variant = dados.get(chave)
		if not (valor is int or valor is float):
			return "Campo numérico ausente ou inválido: " + chave
		if not is_finite(float(valor)) or float(valor) != floor(float(valor)):
			return "Campo inteiro inválido: " + chave
	for chave in ["rows","cols"]:
		if int(dados[chave]) < 1 or int(dados[chave]) > 512:
			return "Dimensão de grade fora do limite: " + chave
	for chave in ["heroStepMs","mobStepMs"]:
		if int(dados[chave]) < 1 or int(dados[chave]) > 60000:
			return "Tempo de movimento fora do limite: " + chave
	for chave in ["minTx","minTy"]:
		if absi(int(dados[chave])) > 1000000:
			return "Origem de grade fora do limite: " + chave
	var grid: Variant = dados.get("grid")
	if not grid is Array or grid.size() != int(dados["rows"]):
		return "Número de linhas da grade inválido."
	for linha in grid:
		if not linha is Array or linha.size() != int(dados["cols"]):
			return "Número de colunas da grade inválido."
		for celula in linha:
			if not celula is bool:
				return "As células da grade devem ser booleanas."
	return ""
