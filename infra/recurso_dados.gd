extends RefCounted
## Lê os valores de um .tres sem carregar seus scripts, UIDs ou sub-recursos.
## O esquema e o script vêm exclusivamente do Resource original empacotado.
## Aceita o subconjunto produzido pelo ResourceSaver para regras: escalares,
## arrays e dicionários. Construtores de objetos são recusados ANTES do parser.

const MAX_BYTES := 2 * 1024 * 1024


static func _substituir(padrao: String, texto: String, novo: String = "") -> String:
	var regex := RegEx.new()
	regex.compile(padrao)
	return regex.sub(texto, novo, true)


static func ler(caminho: String) -> Dictionary:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return {"erro": "Não foi possível abrir o arquivo."}
	if arquivo.get_length() > MAX_BYTES:
		return {"erro": "Arquivo de regras maior que 2 MiB."}
	var texto := arquivo.get_as_text()
	var marcador := "\n[resource]"
	var inicio := texto.find(marcador)
	if inicio < 0:
		return {"erro": "Resource sem seção de valores."}
	var corpo := texto.substr(inicio + marcador.length()).strip_edges()
	# A associação a script é metadado do editor; não é lida nem executada.
	corpo = _substituir('(?m)^script\\s*=\\s*ExtResource\\("[^"\\r\\n]+"\\)\\s*$', corpo)
	# Remove strings e nomes de propriedades para inspecionar SOMENTE a sintaxe.
	var sintaxe := _substituir('"(?:[^"\\\\]|\\\\.)*"', corpo, '""')
	var profundidade := 0
	for letra in sintaxe:
		if letra in "[{(":
			profundidade += 1
			if profundidade > 32:
				return {"erro": "Estrutura de regras profunda demais."}
		elif letra in "]})":
			profundidade -= 1
	sintaxe = _substituir('(?m)^[A-Za-z_][A-Za-z_0-9]*\\s*=', sintaxe)
	sintaxe = _substituir('[-+]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][-+]?[0-9]+)?', sintaxe)
	sintaxe = _substituir('\\b(?:true|false|null|Array|Dictionary|String|int|float|bool)\\b', sintaxe)
	sintaxe = _substituir('[\\s"\\[\\]{}(),:]', sintaxe)
	if not sintaxe.is_empty():
		return {"erro": "Use somente valores de dados; objetos e referências não são aceitos."}
	var config := ConfigFile.new()
	if config.parse("[valores]\n" + corpo) != OK:
		return {"erro": "Sintaxe inválida no Resource."}
	var valores := {}
	if config.has_section("valores"):
		for chave in config.get_section_keys("valores"):
			valores[chave] = config.get_value("valores", chave)
	return {"valores": valores}
