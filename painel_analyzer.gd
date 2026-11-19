extends "res://janela_base.gd"
## Hunt Analyzer (C: window.huntAnalyzer; textos do pacote original). Só desenha o `registro` da cena da hunt
## (caca_sim.gd): tempo, XP, abates, capturas, loot e supply a preço de NPC (C: "Valores em preço de NPC. Os contadores
## zeram ao trocar de hunt"). "Zerar sessão" guarda o registro atual como base.

const PONTE := preload("res://ponte_cidade.gd")
const Regras := preload("res://sim/regras.gd")
var controlador: Node
var base := {}
var base_ms := 0
signal log_capturas_solicitado


func _ready() -> void:
	tamanho = Vector2(520, 560)
	super._ready()
	base_ms = Time.get_ticks_msec()


func zerar() -> void:
	base = controlador.registro.duplicate(true) if controlador != null else {}
	base_ms = Time.get_ticks_msec()


func _dif(chave: String) -> Variant:
	var r = controlador.registro.get(chave, 0)
	var b = base.get(chave, {} if r is Dictionary else 0)
	if r is Dictionary:
		var d := {}
		for k in r:
			var v := int(r[k]) - int(b.get(k, 0))
			if v != 0:
				d[k] = v
		return d
	return int(r) - int(b)


static func _id_servidor(interno: int) -> int:
	return interno - 1000000 if interno >= 1000000 else interno


func resumo() -> Dictionary:
	## Os números da janela (também para os testes).
	var dados = PONTE.dados()
	var cidade = PONTE.servico()
	var seg := maxf(1.0, (Time.get_ticks_msec() - base_ms) / 1000.0)
	var loot: Dictionary = _dif("loot")
	var valor_loot := 0
	var itens := 0
	for k in loot:
		valor_loot += cidade.preco_venda(_id_servidor(int(k))) * int(loot[k])
		itens += int(loot[k])
	var bolas: Dictionary = _dif("bolas")
	var n_bolas := 0
	var custo := 0
	for k in bolas:
		n_bolas += int(bolas[k])
		custo += int(Regras.PARAMETROS.captura_preco_bola.get(str(int(k)), 0)) * int(bolas[k])
	var pocoes: Dictionary = _dif("pocoes")
	var n_poc := 0
	for k in pocoes:
		n_poc += int(pocoes[k])
		custo += int(dados.itens.get(int(k), {}).get("precoGold", 0)) * int(pocoes[k])
	var capt := int(_dif("capturas"))
	var xp := int(_dif("xp_treinador"))
	var abates := int(_dif("abates"))
	return {"segundos": int(seg), "xp": xp, "xp_h": xp / seg * 3600.0, "abates": abates, "abates_h": abates / seg * 3600.0,
		"capturas": capt, "loot": loot, "itens": itens, "valor_loot": valor_loot, "bolas": n_bolas, "pocoes": n_poc,
		"supply": custo, "saldo": valor_loot - custo}


func montar() -> void:
	titulo.text = T.t("window.huntAnalyzer.title", {}, "Hunt Analyzer")
	if controlador == null:
		return
	var r := resumo()
	rotulo(T.t("window.huntAnalyzer.currentSession", {}, "sessão atual"), Color("c8b89a"))
	linha(T.t("window.huntAnalyzer.timeInHunt"), duracao(int(r["segundos"])))
	linha(T.t("window.huntAnalyzer.xpGained"), n(r["xp"]) + "  ·  " + T.t("window.huntAnalyzer.xpPerHour", {"value": n(r["xp_h"])}))
	linha(T.t("window.huntAnalyzer.defeated"), n(r["abates"]) + "  ·  " + T.t("window.huntAnalyzer.killsPerHour", {"value": n(r["abates_h"])}))
	linha(T.t("window.huntAnalyzer.captured"), n(r["capturas"]))
	linha(T.t("window.huntAnalyzer.loot", {"items": n(r["itens"])}), "$" + n(r["valor_loot"]), Color("9fe0a0"))
	linha(T.t("window.huntAnalyzer.supply", {"balls": n(r["bolas"]), "potions": n(r["pocoes"])}), "-$" + n(r["supply"]), Color("ff9a8a"))
	linha(T.t("window.huntAnalyzer.balance"), "$" + n(r["saldo"]), Color("9fe0a0") if int(r["saldo"]) >= 0 else Color("ff9a8a"))
	rotulo(T.t("window.huntAnalyzer.dropsHead"), Color("f0c040"))
	var loot: Dictionary = r["loot"]
	if loot.is_empty():
		rotulo(T.t("window.huntAnalyzer.dropsEmpty"), Color("c8b89a"))
	else:
		var ks := loot.keys()
		ks.sort_custom(func(a, b): return int(loot[a]) > int(loot[b]))
		var cidade = PONTE.servico()
		for k in ks:
			var it: Dictionary = PONTE.dados().itens.get(_id_servidor(int(k)), {})
			linha("%d× %s" % [int(loot[k]), String(it.get("nome", str(k)))], "$" + n(cidade.preco_venda(_id_servidor(int(k))) * int(loot[k])))
	rotulo(T.t("window.huntAnalyzer.note"), Color("8a7f6a"))
	var h := HBoxContainer.new()
	corpo.add_child(h)
	botao(T.t("window.huntAnalyzer.clearTitle", {}, "Zerar a sessão atual"), func() -> void:
		zerar()
		atualizar(), "Zerar", h)
	botao(T.t("window.huntAnalyzer.viewCaptureLog", {}, "Ver Log de Capturas"), func() -> void: log_capturas_solicitado.emit(), "VerLog", h)


func _process(_d: float) -> void:
	# ao vivo enquanto aberta (1 vez por segundo)
	if visible and Engine.get_process_frames() % 60 == 0:
		atualizar()
