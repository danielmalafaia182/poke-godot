extends "res://janela_base.gd"
## Profissões (ciclo 8; sim/servico_profissoes.gd). Pelo cliente (C, window.professions.*, window.craft.*, window.talents.*):
## abas das carreiras (Botânico, Prestígio; Cientista e Pesquisador "em breve"), rank e próximo rank com os requisitos,
## Bônus de Captura e Bônus de Treinador, escolher ou trocar (o rank fica salvo), Subir de Rank; no Botânico, a árvore
## (berries liberadas), Craftar N com a receita e o tempo, a fila e Coletar; no Prestígio, as Rare Pokémon Pictures.

var aviso := ""


func _ready() -> void:
	tamanho = Vector2(860, 660)
	aba = "botanist"
	super._ready()


func _ej() -> Node:
	return get_node("/root/EstadoJogo")


func _cmd(c: Dictionary) -> void:
	var r: Dictionary = _ej().prof(c)
	aviso = String(r.get("erro", ""))
	atualizar()


func montar() -> void:
	titulo.text = T.t("hud.world.menu.professions", {}, "Profissões")
	for k in ["botanist", "prestige", "scientist", "researcher"]:
		botao_aba(k, T.t("window.professions.name." + k))
	if aba in ["scientist", "researcher"]:
		rotulo(T.t("window.professions.desc." + aba), Color("c8b89a"))
		rotulo(T.t("window.professions.soonTitle"), Color("8a9bb0"))
		return
	var ej := _ej()
	var r: Dictionary = ej.prof({"type": "prof-get"})
	rotulo(T.t("window.professions.desc." + aba), Color("c8b89a"))
	var mech := "window.professions.mechBotanist" if aba == "botanist" else "window.professions.mechPrestige"
	rotulo(T.t("window.professions.mechTitle") + " " + T.t(mech), Color("9fc0e8"))
	var atual := String(r.get("atual", ""))
	if atual != aba:
		var rank_salvo := String(ej.profissao.get("ranks", {}).get(aba, ""))
		var b := Button.new()
		b.name = "Escolher"
		b.text = T.t("window.professions.chooseBtn") + ("" if rank_salvo == "" else " (rank %s salvo)" % rank_salvo)
		b.pressed.connect(func() -> void: _cmd({"type": "prof-escolher", "prof": aba}))
		corpo.add_child(b)
	else:
		rotulo("%s · rank %s · %s +%d%% · %s %d%%" % [T.t("window.professions.currentBtn"), String(r["rank"]), T.t("window.professions.catchBonusTitle"),
			int(round(float(r["bonusCaptura"]) * 100.0)), T.t("window.professions.mentorTitle"), int(r["mentorTeto"])], Color("f0c040"), 15)
		if String(r["proximo"]) != "":
			rotulo(T.t("window.professions.nextRank", {"rank": String(r["proximo"]), "name": T.t("window.professions.rankName." + String(r["proximo"]))}), Color("f0e6d2"))
			var pronto := true
			for q in r.get("requisitos", []):
				pronto = pronto and int(q["tem"]) >= int(q["precisa"])
				var nome: String = {"abates_tipo": T.t("window.professions.reqKills", {"need": int(q.get("por_tipo", 0))}), "especies": T.t("window.professions.reqSpecies"),
					"berries": T.t("window.professions.reqBerries"), "pictures": T.t("window.professions.reqPictures")}[String(q["chave"])]
				rotulo("%s %s: %d / %d" % ["✅" if int(q["tem"]) >= int(q["precisa"]) else "⬜", nome, int(q["tem"]), int(q["precisa"])], Color("c8b89a"))
			var sb := Button.new()
			sb.name = "Subir"
			sb.text = T.t("window.professions.rankUpBtn")
			sb.disabled = not pronto
			sb.tooltip_text = T.t("window.professions.rankUpReady") if pronto else T.t("window.professions.rankUpNotReady")
			sb.pressed.connect(func() -> void: _cmd({"type": "prof-subir"}))
			corpo.add_child(sb)
		else:
			rotulo(T.t("window.professions.maxRank", {"name": T.t("window.professions.name." + aba)}), Color("f0c040"))
		if aba == "botanist":
			_crafting(r)
		else:
			rotulo("%s: %d" % [T.t("window.professions.picturesCount"), int(r["pictures"])], Color("f0e6d2"))
			if int(r["pictures"]) > 0:
				var eb := Button.new()
				eb.name = "Entregar"
				eb.text = T.t("window.professions.reqPictures")
				eb.pressed.connect(func() -> void: _cmd({"type": "prof-entregar"}))
				corpo.add_child(eb)
	if aviso != "":
		rotulo(aviso, Color("f0c040"))


func _crafting(r: Dictionary) -> void:
	var ej := _ej()
	rotulo("%s · %s · %s" % [T.t("window.craft.title"), T.t("window.craft.herb.fresh", {"n": int(r["ervas"])}),
		T.t("window.craft.herb.wild", {"n": int(ej.profissao.get("ervas_wild", 0))})], Color("f0c040"), 15)
	rotulo(T.t("window.craft.hint"), Color("8a9bb0"))
	var sp = ej.servico_profissoes()
	var g := HFlowContainer.new()
	corpo.add_child(g)
	for b in sp.arvore({"profissao": ej.profissao}):
		var ef := String(b["efeito"])
		var wild := ef == "NEUTRAL" or ef == "heal"
		var custo := int(sp.p.craft_wild if wild else sp.p.craft_ervas)
		var tem := int(ej.profissao.get("ervas_wild" if wild else "ervas", 0))
		var n := mini(tem / maxi(1, custo), int(ej.ouro) / maxi(1, int(sp.p.craft_ouro)))
		var bt := Button.new()
		bt.name = "Craft_" + ef
		bt.text = "%s · %s" % [ef, T.t("window.craft.start", {"n": maxi(1, n)})]
		bt.tooltip_text = "%d %s + %d de ouro por unidade · %s" % [custo, "Wild Herbs" if wild else "Fresh Herbs", int(sp.p.craft_ouro),
			T.t("window.craft.perUnit", {"time": "%d min" % (int(sp.p.craft_s_unidade) / 60)})]
		bt.disabled = n < 1
		bt.pressed.connect(func() -> void: _cmd({"type": "craft-start", "efeito": ef, "n": maxi(1, n)}))
		g.add_child(bt)
	var fila: Array = ej.profissao.get("fila", [])
	if not fila.is_empty():
		for o in fila:
			rotulo("• %s ×%d · %d %s" % [String(o["efeito"]), int(o["n"]), int(o["coletadas"]), T.t("window.craft.produced")], Color("c8b89a"))
		var cb := Button.new()
		cb.name = "Coletar"
		cb.text = "🧺 " + T.t("window.craft.collect")
		cb.pressed.connect(func() -> void: _cmd({"type": "craft-collect"}))
		corpo.add_child(cb)
