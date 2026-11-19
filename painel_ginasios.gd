extends "res://janela_base.gd"
## Ginásios (C: window.gyms — abas Ginásio e Recompensas do Ginásio, textos do pacote original; ciclo 3, classe 3: times,
## níveis e luta desenhados em balanceamento.json "ginasios", sim/servico_ginasios.gd). Só desenha e manda o desafio:
## a luta é calculada na sim (EstadoJogo.desafiar_ginasio) e aqui é repassada golpe a golpe, com as barras de HP.

const PONTE := preload("res://ponte_cidade.gd")
const NOMES_TIPO := {"ROCK": "Pedra", "WATER": "Água", "ELECTRIC": "Elétrico", "GRASS": "Planta", "POISON": "Veneno", "PSYCHIC": "Psíquico",
	"FIRE": "Fogo", "GROUND": "Terra", "FLYING": "Voador", "BUG": "Inseto", "NORMAL": "Normal", "GHOST": "Fantasma", "FIGHTING": "Lutador",
	"STEEL": "Aço", "ICE": "Gelo", "DRAGON": "Dragão", "DARK": "Sombrio", "FAIRY": "Fada"}
var luta: Dictionary = {}      # o último gym-result, enquanto é repassado
var passo := 0
var _acum := 0.0
var velocidade := 8.0          # golpes por segundo no replay


func _ready() -> void:
	tamanho = Vector2(720, 620)
	aba = "gyms"
	super._ready()


func _agora() -> int:
	return int(Time.get_unix_time_from_system())


func desafiar(gid: String) -> Dictionary:
	var r: Dictionary = get_node("/root/EstadoJogo").desafiar_ginasio(gid, _agora())
	luta = r
	passo = 0
	atualizar()
	return r


func montar() -> void:
	titulo.text = T.t("window.gyms.title", {}, "Ginásios")
	botao_aba("gyms", T.t("window.gyms.navGyms", {}, "Ginásio"))
	botao_aba("rewards", T.t("window.gyms.navRewards", {}, "Recompensas do Ginásio"))
	var info: Dictionary = get_node("/root/EstadoJogo").ginasios_info(_agora())
	if not luta.is_empty():
		_montar_luta()
		return
	if aba == "rewards":
		_montar_recompensas(info)
		return
	rotulo(T.t("window.gyms.rewards.perkNow", {"active": int(info["active"]), "max": int(info["max"]), "drop": int(info["dropPct"])}), Color("9fe0a0"))
	for g in info["gyms"]:
		var caixa := PanelContainer.new()
		caixa.name = "G_" + String(g["id"])
		corpo.add_child(caixa)
		var h := HBoxContainer.new()
		caixa.add_child(h)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(col)
		var estado := ""
		if bool(g["ativa"]):
			var resto := maxi(0, (int(g["ate"]) / 1000) - _agora())
			estado = "  🏅 %dh%02d" % [resto / 3600, (resto % 3600) / 60]
		elif bool(g["vencido"]):
			estado = "  (insígnia expirada)"
		rotulo("%s — %s  ·  %s%s" % [String(g["id"]).capitalize(), String(g["lider"]), NOMES_TIPO.get(String(g["tipo"]), String(g["tipo"])), estado],
			Color("f0c040") if bool(g["ativa"]) else Color.WHITE, 0, col)
		var nomes: Array = []
		for m in g["time"]:
			nomes.append("%s Nv.%d" % [String(PONTE.dados().especie(int(m["speciesId"])).get("nome", "?")), int(m["nivel"])])
		rotulo(", ".join(PackedStringArray(nomes)), Color("c8b89a"), 0, col)
		var b := Button.new()
		b.name = "Desafiar_" + String(g["id"])
		if not bool(g["liberado"]):
			b.text = "🔒 Nv. %d" % int(g["nivelTreinador"])
			b.disabled = true
		elif int(g["recargaS"]) > 0:
			b.text = "⏳ %d s" % int(g["recargaS"])
			b.disabled = true
		else:
			b.text = "Renovar" if bool(g["ativa"]) else "Desafiar"
			var gid := String(g["id"])
			b.pressed.connect(func() -> void: desafiar(gid))
		h.add_child(b)


func _montar_recompensas(info: Dictionary) -> void:
	rotulo(T.t("window.gyms.rewards.badgesTitle"), Color("f0c040"), 16)
	rotulo(T.t("window.gyms.rewards.badgesText"), Color("c8b89a"))
	rotulo(T.t("window.gyms.rewards.perkNow", {"active": int(info["active"]), "max": int(info["max"]), "drop": int(info["dropPct"])}), Color("9fe0a0"))
	rotulo(T.t("window.gyms.rewards.champTitle"), Color("f0c040"), 16)
	rotulo(T.t("window.gyms.rewards.champText"), Color("c8b89a"))
	var vencidos := 0
	for g in info["gyms"]:
		vencidos += 1 if bool(g["vencido"]) else 0
	if bool(info["campeao"]):
		rotulo(T.t("window.gyms.rewards.champDone"), Color("9fe0a0"))
	else:
		rotulo(T.t("window.gyms.rewards.champLeft", {"got": vencidos, "all": int(info["max"]), "n": int(info["max"]) - vencidos}), Color.WHITE)
	rotulo("A disputa de liderança e a distribuição diária entre líderes são entre jogadores (online): ficam de fora.", Color("8a7f6a"))


func _montar_luta() -> void:
	if luta.has("erro"):
		rotulo(String(luta["erro"]), Color("ff9a8a"))
		botao("Voltar", func() -> void:
			luta = {}
			atualizar(), "VoltarLuta")
		return
	var log: Array = luta["log"]
	var mostrados: Array = log.slice(0, passo)
	var hp := {"a": {}, "b": {}}
	for x in mostrados:
		hp["b" if String(x["lado"]) == "a" else "a"][String(x["alvo"])] = [int(x["hp"]), int(x["max"])]
	for lado in ["a", "b"]:
		rotulo("Seu time" if lado == "a" else "Líder", Color("f0c040"))
		for m in luta["times"][lado]:
			var v: Array = hp[lado].get(String(m["nome"]), [int(m["max"]), int(m["max"])])
			var h := HBoxContainer.new()
			corpo.add_child(h)
			var n1 := rotulo("%s Nv.%d" % [String(m["nome"]), int(m["nivel"])], Color.WHITE if int(v[0]) > 0 else Color("8a7f6a"), 0, h)
			n1.custom_minimum_size.x = 200
			var barra := ProgressBar.new()
			barra.max_value = maxf(1.0, float(v[1]))
			barra.value = float(v[0])
			barra.show_percentage = false
			barra.custom_minimum_size = Vector2(260, 12)
			h.add_child(barra)
	for x in mostrados.slice(maxi(0, mostrados.size() - 6)):
		var ef := ""
		if float(x["eff"]) > 1.0:
			ef = " — é super efetivo!"
		elif float(x["eff"]) < 1.0:
			ef = " — não é muito efetivo…"
		rotulo("%s usou %s: %d de dano%s%s" % [String(x["nome"]), String(x["golpe"]), int(x["dano"]), ef, ("  · %s desmaiou!" % String(x["alvo"])) if bool(x["ko"]) else ""],
			Color("9fe0a0") if String(x["lado"]) == "a" else Color("ff9a8a"))
	if passo >= log.size():
		var ok := bool(luta["venceu"])
		rotulo("🏅 Vitória! Insígnia válida por 48 h." if ok else "Derrota. Fortaleça o time e tente de novo.",
			Color("9fe0a0") if ok else Color("ff9a8a"), 18)
		if bool(luta.get("championOutfit", false)):
			rotulo(T.t("window.gyms.rewards.champDone") + " — " + T.t("window.gyms.rewards.champTitle"), Color("ffe080"), 18)
		botao("Voltar", func() -> void:
			luta = {}
			atualizar(), "VoltarLuta")
	else:
		botao("Pular", func() -> void:
			passo = log.size()
			atualizar(), "PularLuta")


func _process(d: float) -> void:
	if not visible or luta.is_empty() or luta.has("erro"):
		return
	if passo < (luta["log"] as Array).size():
		_acum += d * velocidade
		if _acum >= 1.0:
			passo = mini((luta["log"] as Array).size(), passo + int(_acum))
			_acum = 0.0
			atualizar()
