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

static var _cache: Dictionary = {}
static var _perfil := ""


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
		for f in [USUARIO + "/perfil.txt", BASE + "/perfil.txt"]:
			if FileAccess.file_exists(f):
				var t := FileAccess.get_file_as_string(f).strip_edges()
				if t != "":
					_perfil = t
					break
	return _perfil


static func definir_perfil(nome: String, em_usuario: bool = true) -> void:
	## Grava o perfil ativo (user:// no jogo; res:// pelo editor) e recarrega.
	var pasta := USUARIO if em_usuario else BASE
	DirAccess.make_dir_recursive_absolute(pasta)
	var f := FileAccess.open(pasta + "/perfil.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(nome)
		f.close()
	recarregar()


static func perfis() -> Array:
	var r: Array = ["original"]
	for pasta in [BASE, USUARIO]:
		var d := DirAccess.open(pasta)
		if d == null:
			continue
		for n in d.get_directories():
			if n != "scripts" and not n in r:
				r.append(n)
	return r


static func caminho(rec: String, perfil_nome: String = "") -> String:
	var pf := perfil_nome if perfil_nome != "" else perfil()
	for c in [USUARIO + "/" + pf + "/" + rec + ".tres", BASE + "/" + pf + "/" + rec + ".tres"]:
		if pf != "original" and FileAccess.file_exists(c):
			return c
		if pf == "original" and c.begins_with(USUARIO) and FileAccess.file_exists(c):
			return c   # sobrescrever o original pelo user:// também vale (o pacote fica intacto)
	return BASE + "/original/" + rec + ".tres"


static func recurso(rec: String, perfil_nome: String = "") -> Resource:
	var c := caminho(rec, perfil_nome)
	if ResourceLoader.exists(c) or FileAccess.file_exists(c):
		return ResourceLoader.load(c, "", ResourceLoader.CACHE_MODE_IGNORE)
	return null


static func valores_de(r: Resource) -> Dictionary:
	var d := {}
	if r == null:
		return d
	for prop in r.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v = r.get(prop["name"])
			d[prop["name"]] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return d


static func valores(rec: String) -> Dictionary:
	if not _cache.has(rec):
		_cache[rec] = valores_de(recurso(rec))
	return _cache[rec]


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
	for c in [USUARIO + "/" + pf + "/alteracoes.tres", BASE + "/" + pf + "/alteracoes.tres"]:
		if FileAccess.file_exists(c):
			return ResourceLoader.load(c, "", ResourceLoader.CACHE_MODE_IGNORE)
	return null


static func recarregar() -> void:
	_cache.clear()
	_perfil = ""


# ------------------------------------------------------------------ edição de perfis (Game Master e painel F12)

static func _pasta(perfil_nome: String, em_usuario: bool) -> String:
	return (USUARIO if em_usuario else BASE) + "/" + perfil_nome


static func _carregar_editavel(rec: String, perfil_nome: String, em_usuario: bool) -> Resource:
	var c := _pasta(perfil_nome, em_usuario) + "/" + rec + ".tres"
	if FileAccess.file_exists(c):
		return ResourceLoader.load(c, "", ResourceLoader.CACHE_MODE_IGNORE)
	var base: Resource = recurso(rec, perfil_nome)
	if base == null:
		base = ResourceLoader.load(BASE + "/original/" + rec + ".tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	return base.duplicate(true)


static func original(rec: String, chave: String):
	## O valor original do jogo = o padrão do campo no script do Resource.
	var r: Resource = ResourceLoader.load(BASE + "/original/" + rec + ".tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	return r.get_script().get_property_default_value(chave) if r != null else null


static func gravar_valor(rec: String, chave: String, valor, perfil_nome: String = "", em_usuario: bool = true) -> String:
	## Grava `chave` = `valor` no perfil (user:// por padrão). "" = ok; senão o motivo. O "original" não se edita.
	var pf := perfil_nome if perfil_nome != "" else perfil()
	if pf == "original":
		return "O perfil original fica intacto: crie ou escolha outro perfil."
	var r := _carregar_editavel(rec, pf, em_usuario)
	if r == null or not chave in valores_de(r):
		return "Campo desconhecido: %s.%s" % [rec, chave]
	r.set(chave, valor)
	DirAccess.make_dir_recursive_absolute(_pasta(pf, em_usuario))
	var err := ResourceSaver.save(r, _pasta(pf, em_usuario) + "/" + rec + ".tres")
	recarregar()
	return "" if err == OK else "Erro ao gravar (%d)." % err


static func restaurar(rec: String, chave: String = "", perfil_nome: String = "", em_usuario: bool = true) -> String:
	## Volta um campo (ou o Resource inteiro, chave "") ao valor original.
	var pf := perfil_nome if perfil_nome != "" else perfil()
	if pf == "original":
		return ""
	var c := _pasta(pf, em_usuario) + "/" + rec + ".tres"
	if not FileAccess.file_exists(c):
		return ""
	if chave == "":
		DirAccess.remove_absolute(c)
		recarregar()
		return ""
	return gravar_valor(rec, chave, original(rec, chave), pf, em_usuario)


static func criar_perfil(nome: String, a_partir_de: String = "original", em_usuario: bool = true) -> String:
	## Copia os .tres do perfil base para um perfil novo (o original é só referência: a cópia sai vazia de mudanças).
	if nome == "" or nome == "original" or nome.contains("/") or nome.contains(".."):
		return "Nome de perfil inválido."
	DirAccess.make_dir_recursive_absolute(_pasta(nome, em_usuario))
	if a_partir_de != "original":
		for pasta in [_pasta(a_partir_de, false), _pasta(a_partir_de, true)]:
			var d := DirAccess.open(pasta)
			if d == null:
				continue
			for f in d.get_files():
				if f.ends_with(".tres"):
					DirAccess.copy_absolute(pasta + "/" + f, _pasta(nome, em_usuario) + "/" + f)
	return ""


static func _alt_editavel(perfil_nome: String, em_usuario: bool) -> Resource:
	var c := _pasta(perfil_nome, em_usuario) + "/alteracoes.tres"
	if FileAccess.file_exists(c):
		return ResourceLoader.load(c, "", ResourceLoader.CACHE_MODE_IGNORE)
	return load("res://dados/regras/scripts/alteracoes_tabelas.gd").new()


static func _mesmo_item(a: Dictionary, chave: Dictionary) -> bool:
	for k in chave:
		if str(a.get(k, "")) != str(chave[k]):
			return false
	return true


static func gravar_alteracao(tabela: String, chave: Dictionary, valor, perfil_nome: String = "", em_usuario: bool = true) -> String:
	## tabela: "especies" | "loot" | "hunts" | "itens"; chave: {id, campo} ou {especie, itemId, campo}. "" = ok.
	var pf := perfil_nome if perfil_nome != "" else perfil()
	if pf == "original":
		return "O perfil original fica intacto: crie ou escolha outro perfil."
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
	DirAccess.make_dir_recursive_absolute(_pasta(pf, em_usuario))
	var err := ResourceSaver.save(alt, _pasta(pf, em_usuario) + "/alteracoes.tres")
	recarregar()
	return "" if err == OK else "Erro ao gravar (%d)." % err


static func restaurar_alteracao(tabela: String, chave: Dictionary, perfil_nome: String = "", em_usuario: bool = true) -> void:
	var pf := perfil_nome if perfil_nome != "" else perfil()
	var c := _pasta(pf, em_usuario) + "/alteracoes.tres"
	if pf == "original" or not FileAccess.file_exists(c):
		return
	var alt := _alt_editavel(pf, em_usuario)
	alt.set(tabela, (alt.get(tabela) as Array).filter(func(a): return not _mesmo_item(a, chave)))
	ResourceSaver.save(alt, c)
	recarregar()
