extends RefCounted
## Textos do pacote de conteúdo (dados/pacotes/textos_pt.json, textos do cliente original, C). Trocável: outro pacote com
## as mesmas chaves muda todos os textos. `t("window.huntAnalyzer.title")`, com {{variáveis}} como no cliente.
## Chave ausente devolve a reserva (ou a própria chave), para o jogo nunca mostrar vazio.

const Fontes := preload("res://sim/fontes.gd")
static var _raiz: Dictionary = {}
static var _lido := false


static func _dados() -> Dictionary:
	if not _lido:
		_lido = true
		var d = Fontes.ler_json(Fontes.pasta_dados() + "/pacotes/textos_pt.json")
		_raiz = d.get("pt", {}) if d is Dictionary else {}
	return _raiz


static func tem(chave: String) -> bool:
	return _busca(chave) is String


static func _busca(chave: String):
	var no = _dados()
	for parte in chave.split("."):
		if not no is Dictionary or not (no as Dictionary).has(parte):
			return null
		no = no[parte]
	return no


static func t(chave: String, vars: Dictionary = {}, reserva: String = "") -> String:
	var v = _busca(chave)
	var s: String = v if v is String else (reserva if reserva != "" else chave)
	for k in vars:
		s = s.replace("{{%s}}" % k, str(vars[k]))
	return s


static func sem_html(s: String) -> String:
	## Os textos do cliente têm <b>…</b>; Label não interpreta: tira as marcas.
	var r := RegEx.create_from_string("<[^>]+>")
	return r.sub(s, "", true)


static func bbcode(s: String) -> String:
	## <b>x</b> → [b]x[/b] para RichTextLabel.
	return s.replace("<b>", "[b]").replace("</b>", "[/b]").replace("<br>", "\n").replace("<br/>", "\n")
