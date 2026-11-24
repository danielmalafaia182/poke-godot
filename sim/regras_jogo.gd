extends RefCounted
## Regras do jogo (Game Master). Lê os Resources de dados/regras/ e entrega dicionários puros à sim e aos serviços.
## A sim não lê nó nem cena: recebe o dicionário pronto (via sim/balanceamento.gd, que delega para cá).
##
## Perfis: cada perfil é uma pasta de .tres com só o que muda; o padrão de cada campo (no script do Resource) é o valor
## original do jogo, então o perfil "original" fica intacto por construção. Ordem de leitura de um Resource:
##   1. user://regras/<perfil>/<Recurso>.tres   (sobrescreve no jogo exportado, sem tocar no pacote)
##   2. res://dados/regras/<perfil>/<Recurso>.tres
##   3. res://dados/regras/original/<Recurso>.tres
## Perfil ativo: user://regras/perfil.txt, senão res://dados/regras/perfil.txt, senão "original".
## Tabelas grandes (espécies, itens, hunts, loot): Resource AlteracoesTabelas (alteracoes.tres no perfil), aplicado por
## cima dos dados importados em sim/dados_jogo.gd.

const BASE := "res://dados/regras"
const USUARIO := "user://regras"
const SECOES := {
	"combate": ["RegrasCombate", "RegrasMovimento", "RegrasXP", "RegrasCaptura", "RegrasLoot", "RegrasSessao", "RegrasEventos", "RegrasVIP"],
	"cidade": ["RegrasEconomia"], "diarias": ["RegrasDiarias"], "jogador": ["RegrasJogador"], "ginasios": ["RegrasGinasios"],
	"bosses": ["RegrasBosses"], "cards": ["RegrasCards"], "itens": ["RegrasItens"], "profissoes": ["RegrasProfissoes"],
	"breeding": ["RegrasBreeding"], "golden_stars": ["RegrasGoldenStars"], "pesca": ["RegrasPesca"], "ditto": ["RegrasDitto"],
	"metas": ["RegrasInterface"], "apresentacao": ["RegrasInterface"], "jogo_novo": ["RegrasJogoNovo"],
}

const Validador := preload("res://sim/validacao_regras.gd")
const Arquivo := preload("res://infra/arquivo_atomico.gd")
const Leitor := preload("res://infra/recurso_dados.gd")
const Alteracoes := preload("res://dados/regras/scripts/alteracoes_tabelas.gd")

static var _cache: Dictionary = {}
static var _perfil := ""
static var _avisos: PackedStringArray = []


static func recursos() -> Array:
	var r: Array = []
	for s in SECOES:
		for n in SECOES[s]:
			if not n in r:
				r.append(n)
	r.sort()
	return r


static func perfil() -> String:
	if _perfil == "":
		_perfil = "original"
		var fontes := [BASE + "/perfil.txt"] if Engine.is_editor_hint() else [USUARIO + "/perfil.txt", BASE + "/perfil.txt"]
		for f in fontes:
			if FileAccess.file_exists(f):
				var t := FileAccess.get_file_as_string(f).strip_edges()
				if Validador.nome_perfil(t):
					_perfil = t
					break
	return _perfil


static func definir_perfil(nome: String, em_usuario: bool = true) -> String:
	## Grava o perfil ativo (user:// no jogo; res:// pelo editor) e recarrega.
	if not Validador.nome_perfil(nome):
		return "Nome de perfil inválido: use letras, números, _ e - (até 64 caracteres)."
	var pasta := USUARIO if em_usuario else BASE
	var erro := Arquivo.texto(pasta + "/perfil.txt", nome)
	if erro != OK:
		return "Não foi possível ativar o perfil (%s)." % error_string(erro)
	recarregar()
	return ""


static func perfis() -> Array:
	var r: Array = ["original"]
	var pastas := [BASE] if Engine.is_editor_hint() else [BASE, USUARIO]
	for pasta in pastas:
		var d := DirAccess.open(pasta)
		if d == null:
			continue
		for n in d.get_directories():
			if Validador.nome_perfil(n) and not n in r:
				r.append(n)
	r.sort()
	return r


static func caminho(rec: String, perfil_nome: String = "") -> String:
	var pf := perfil_nome if perfil_nome != "" else perfil()
	if not rec in recursos() or not Validador.nome_perfil(pf):
		return ""
	var fontes := [BASE + "/" + pf + "/" + rec + ".tres"]
	if not Engine.is_editor_hint():
		fontes.push_front(USUARIO + "/" + pf + "/" + rec + ".tres")
	for c in fontes:
		if pf != "original" and _existe_recurso(c):
			return c
		if pf == "original" and c.begins_with(USUARIO) and FileAccess.file_exists(c):
			return c   # sobrescrever o original pelo user:// também vale (o pacote fica intacto)
	return BASE + "/original/" + rec + ".tres"


static func _existe_recurso(c: String) -> bool:
	# O exportador converte .tres do pacote em .res + .remap. user:// continua só texto.
	return FileAccess.file_exists(c) or (c.begins_with(BASE + "/") and ResourceLoader.exists(c))


static func recurso(rec: String, perfil_nome: String = "") -> Resource:
	var c := caminho(rec, perfil_nome)
	if c == "":
		return null
	var padrao := _original_recurso(rec)
	if c == BASE + "/original/" + rec + ".tres":
		return padrao
	return _ler_recurso(c, padrao)


static func _original_recurso(rec: String) -> Resource:
	if not rec in recursos():
		return null
	var r := ResourceLoader.load(BASE + "/original/" + rec + ".tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	# Os defaults do script são a referência, mesmo se um .tres original foi editado no Inspector.
	return r.get_script().new() if r != null else null


static func avisos() -> PackedStringArray:
	return _avisos.duplicate()


static func registrar_aviso(caminho_arquivo: String, motivo: String) -> void:
	var mensagem := caminho_arquivo + ": " + motivo + " Valores originais mantidos."
	if not mensagem in _avisos:
		_avisos.append(mensagem)


static func _ler_recurso(arquivo: String, padrao: Resource) -> Resource:
	if padrao == null:
		return null
	var leitura: Dictionary
	if arquivo.begins_with(BASE + "/") and not FileAccess.file_exists(arquivo) and ResourceLoader.exists(arquivo):
		# Somente recursos já empacotados e confiáveis podem usar ResourceLoader.
		# Perfis externos/user:// jamais carregam scripts nem objetos.
		var empacotado := ResourceLoader.load(arquivo, "", ResourceLoader.CACHE_MODE_IGNORE)
		leitura = {"valores": valores_de(empacotado)} if empacotado != null else {"erro": "Resource empacotado ilegível."}
	else:
		leitura = Leitor.ler(arquivo)
	if leitura.has("erro"):
		registrar_aviso(arquivo, leitura.erro)
		return padrao
	var r := padrao.duplicate(true)
	for chave in leitura.valores:
		var valor = leitura.valores[chave]
		var erro := Validador.campo(r, chave, valor)
		if erro != "":
			registrar_aviso(arquivo, erro)
			return padrao
		_atribuir(r, chave, valor)
	var erro := Validador.conjunto(r)
	if r is Alteracoes:
		erro = _validar_alteracoes(r)
	if erro != "":
		registrar_aviso(arquivo, erro)
		return padrao
	return r


static func _atribuir(r: Resource, chave: String, valor: Variant) -> void:
	var atual = r.get(chave)
	if atual is Array and valor is Array:
		atual.assign(valor)
	elif atual is int:
		r.set(chave, int(valor))
	elif atual is float:
		r.set(chave, float(valor))
	else:
		r.set(chave, valor)


static func valores_de(r: Resource) -> Dictionary:
	var d := {}
	if r == null:
		return d
	for prop in r.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(prop["usage"]) & PROPERTY_USAGE_STORAGE:
			var v = r.get(prop["name"])
			d[prop["name"]] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return d


static func valores(rec: String) -> Dictionary:
	if not _cache.has(rec):
		_cache[rec] = valores_de(recurso(rec))
	return (_cache[rec] as Dictionary).duplicate(true)


static func secao(nome: String) -> Dictionary:
	var r := {}
	for rec in SECOES.get(nome, []):
		var v := valores(rec)
		for k in v:
			r[k] = v[k].duplicate(true) if (v[k] is Dictionary or v[k] is Array) else v[k]
	return r


static func alteracoes() -> Resource:
	## AlteracoesTabelas do perfil (ou null): mudanças sobre as tabelas importadas.
	var pf := perfil()
	var fontes := [BASE + "/" + pf + "/alteracoes.tres"]
	if not Engine.is_editor_hint():
		fontes.push_front(USUARIO + "/" + pf + "/alteracoes.tres")
	for c in fontes:
		if _existe_recurso(c):
			return _ler_recurso(c, Alteracoes.new())
	return null


static func recarregar() -> void:
	_cache.clear()
	_perfil = ""
	_avisos.clear()


# ------------------------------------------------------------------ edição de perfis (Game Master e painel F12)

static func _pasta(perfil_nome: String, em_usuario: bool) -> String:
	return (USUARIO if em_usuario else BASE) + "/" + perfil_nome


static func _carregar_editavel(rec: String, perfil_nome: String, em_usuario: bool) -> Resource:
	var c := _pasta(perfil_nome, em_usuario) + "/" + rec + ".tres"
	if FileAccess.file_exists(c):
		return _ler_recurso(c, _original_recurso(rec))
	var base: Resource = recurso(rec, perfil_nome)
	if base == null:
		base = _original_recurso(rec)
	return base.duplicate(true) if base != null else null


static func original(rec: String, chave: String):
	## O valor original do jogo = o padrão do campo no script do Resource.
	var r := _original_recurso(rec)
	return r.get_script().get_property_default_value(chave) if r != null else null


static func gravar_valor(rec: String, chave: String, valor, perfil_nome: String = "", em_usuario: bool = true) -> String:
	## Grava `chave` = `valor` no perfil (user:// por padrão). "" = ok; senão o motivo. O "original" não se edita.
	var pf := perfil_nome if perfil_nome != "" else perfil()
	if not Validador.nome_perfil(pf) or not rec in recursos():
		return "Perfil ou Resource inválido."
	if pf.to_lower() == "original":
		return "O perfil original fica intacto: crie ou escolha outro perfil."
	var r := _carregar_editavel(rec, pf, em_usuario)
	if r == null or not chave in valores_de(r):
		return "Campo desconhecido: %s.%s" % [rec, chave]
	var erro := Validador.campo(r, chave, valor)
	if erro != "":
		return erro
	_atribuir(r, chave, valor)
	erro = Validador.conjunto(r)
	if erro != "":
		return erro
	return _salvar_recurso(r, _pasta(pf, em_usuario) + "/" + rec + ".tres")


static func _salvar_recurso(r: Resource, c: String) -> String:
	var erro := Arquivo.recurso(c, r)
	if erro != OK:
		return "Erro ao gravar (%s). O arquivo anterior foi preservado." % error_string(erro)
	recarregar()
	return ""


static func restaurar(rec: String, chave: String = "", perfil_nome: String = "", em_usuario: bool = true) -> String:
	## Volta um campo (ou o Resource inteiro, chave "") ao valor original.
	var pf := perfil_nome if perfil_nome != "" else perfil()
	if not Validador.nome_perfil(pf) or not rec in recursos():
		return "Perfil ou Resource inválido."
	if pf.to_lower() == "original":
		return "O perfil original fica intacto: crie ou escolha outro perfil."
	var c := _pasta(pf, em_usuario) + "/" + rec + ".tres"
	if chave == "":
		# Não apagar: isso exporia um override do mesmo perfil empacotado em res://.
		return _salvar_recurso(_original_recurso(rec), c)
	return gravar_valor(rec, chave, original(rec, chave), pf, em_usuario)


static func criar_perfil(nome: String, a_partir_de: String = "original", em_usuario: bool = true) -> String:
	## Copia os .tres do perfil base para um perfil novo (o original é só referência: a cópia sai vazia de mudanças).
	if not Validador.nome_perfil(nome) or not Validador.nome_perfil(a_partir_de) or nome.to_lower() == "original":
		return "Nome de perfil inválido."
	var destino := _pasta(nome, em_usuario)
	if DirAccess.dir_exists_absolute(destino) or FileAccess.file_exists(destino):
		return "Já existe um perfil com esse nome."
	var erro := DirAccess.make_dir_recursive_absolute(destino)
	if erro != OK:
		return "Não foi possível criar o perfil (%s)." % error_string(erro)
	if a_partir_de != "original":
		for rec in recursos():
			var mensagem := _salvar_recurso(recurso(rec, a_partir_de), destino + "/" + rec + ".tres")
			if mensagem != "":
				return mensagem
		var alt := _alt_editavel(a_partir_de, em_usuario)
		if not alt.vazio():
			return _salvar_recurso(alt, destino + "/alteracoes.tres")
	return ""


static func _alt_editavel(perfil_nome: String, em_usuario: bool) -> Resource:
	var c := _pasta(perfil_nome, em_usuario) + "/alteracoes.tres"
	if FileAccess.file_exists(c):
		return _ler_recurso(c, Alteracoes.new())
	c = _pasta(perfil_nome, false) + "/alteracoes.tres"
	if em_usuario and _existe_recurso(c):
		return _ler_recurso(c, Alteracoes.new())
	return Alteracoes.new()


static func _validar_alteracoes(alt: Resource) -> String:
	for tabela in Validador.CAMPOS_TABELAS:
		for item in alt.get(tabela):
			if not item is Dictionary or not item.has("valor"):
				return "Alteração de tabela sem valor."
			var chave: Dictionary = item.duplicate()
			chave.erase("valor")
			var erro := Validador.alteracao(tabela, chave, item.valor)
			if erro != "":
				return erro
	return ""


static func _mesmo_item(a: Dictionary, chave: Dictionary) -> bool:
	for k in chave:
		if str(a.get(k, "")) != str(chave[k]):
			return false
	return true


static func gravar_alteracao(tabela: String, chave: Dictionary, valor, perfil_nome: String = "", em_usuario: bool = true) -> String:
	## tabela: "especies" | "loot" | "hunts" | "itens"; chave: {id, campo} ou {especie, itemId, campo}. "" = ok.
	var pf := perfil_nome if perfil_nome != "" else perfil()
	if not Validador.nome_perfil(pf):
		return "Perfil inválido."
	if pf.to_lower() == "original":
		return "O perfil original fica intacto: crie ou escolha outro perfil."
	var erro := Validador.alteracao(tabela, chave, valor)
	if erro != "":
		return erro
	var alt := _alt_editavel(pf, em_usuario)
	var lista: Array = alt.get(tabela)
	var novo := chave.duplicate()
	novo["valor"] = valor
	var feito := false
	for i in lista.size():
		if _mesmo_item(lista[i], chave):
			lista[i] = novo
			feito = true
	if not feito:
		lista.append(novo)
	alt.set(tabela, lista)
	erro = _validar_destinos(alt)
	if erro != "":
		return erro
	return _salvar_recurso(alt, _pasta(pf, em_usuario) + "/alteracoes.tres")


static func _validar_destinos(alt: Resource) -> String:
	# Carga sob demanda evita um ciclo de preload entre repositório de regras e catálogo.
	var catalogo: Script = load("res://sim/dados_jogo.gd")
	return catalogo.validar_alteracoes(catalogo.carregar(false), alt)


static func restaurar_alteracao(tabela: String, chave: Dictionary, perfil_nome: String = "", em_usuario: bool = true) -> String:
	var pf := perfil_nome if perfil_nome != "" else perfil()
	var c := _pasta(pf, em_usuario) + "/alteracoes.tres"
	if not Validador.nome_perfil(pf) or not tabela in Validador.CAMPOS_TABELAS or not chave.get("campo", "") in Validador.CAMPOS_TABELAS[tabela]:
		return "Perfil, tabela ou campo inválido."
	if pf.to_lower() == "original":
		return "O perfil original fica intacto: crie ou escolha outro perfil."
	var alt := _alt_editavel(pf, em_usuario)
	alt.set(tabela, (alt.get(tabela) as Array).filter(func(a): return not _mesmo_item(a, chave)))
	var erro := _validar_destinos(alt)
	if erro != "":
		return erro
	return _salvar_recurso(alt, c)
