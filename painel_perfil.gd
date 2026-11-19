extends "res://janela_base.gd"
## Perfil (C: window.profile; textos do pacote original). Só o que existe offline: nível, experiência, ouro, VIP, tempo em
## caça, capturas, abates (Streak), Pokédex (espécies diferentes capturadas sobre as do jogo) e o atalho para o Log de
## Capturas. Clã, PvP, rankings, diamantes, bless e pesca são do servidor: ficam de fora (o jogo é offline).

const PONTE := preload("res://ponte_cidade.gd")
signal log_capturas_solicitado


func _ready() -> void:
	tamanho = Vector2(480, 520)
	super._ready()


func pokedex() -> Array:
	## [capturadas, total]: espécies diferentes (normal e shiny contam uma vez) no time, na BOX e no log; total = espécies
	## que aparecem em alguma hunt (as que dá para capturar).
	var ej: Node = get_node("/root/EstadoJogo")
	var dados = PONTE.dados()
	var tem := {}
	for pk in ej.time_pokemon + ej.pokemons_capturados:
		if pk != null and pk.especie != null:
			tem[String(pk.especie.nome)] = true
	for e in ej.log_capturas:
		tem[String(e.get("especie", ""))] = true
	var todas := {}
	for h in dados.hunts.values():
		for s in h.get("spawns", []):
			todas[String(dados.especie(int(s.get("pokeId", 0))).get("nome", ""))] = true
	var c := 0
	for k in tem:
		if todas.has(k):
			c += 1
	return [c, todas.size()]


func montar() -> void:
	var ej: Node = get_node("/root/EstadoJogo")
	titulo.text = T.t("window.profile.windowTitle", {}, "Perfil")
	rotulo(String(ej.nome_treinador), Color.WHITE, 22)
	rotulo(T.t("window.profile.sectionGeneral"), Color("f0c040"))
	linha(T.t("window.profile.rowLevel"), str(int(ej.nivel_treinador)))
	linha(T.t("window.profile.rowExperience"), n(ej.experiencia_treinador_acumulada))
	linha(T.t("window.profile.rowGold"), "$" + n(ej.ouro))
	linha(T.t("window.profile.rowVip"), T.t("window.profile.vipActive") if bool(ej.vip) else "—")
	rotulo(T.t("window.profile.sectionProgression"), Color("f0c040"))
	linha(T.t("window.profile.rowHuntTime"), duracao(int(ej.tempo_caca_s)))
	linha(T.t("window.profile.rowTotalCatches"), n(ej.capturas_total))
	linha("Abates (total)", n(int(ej.streak.get("totalKills", 0))))
	var pd := pokedex()
	linha(T.t("window.profile.rowPokedex"), T.t("window.profile.pokedexChip", {"count": pd[0], "total": pd[1]}))
	botao(T.t("window.profile.captureLogBtn", {}, "Log de Capturas"), func() -> void: log_capturas_solicitado.emit(), "AbrirLog")
	rotulo(T.t("window.profile.footer", {"name": String(ej.nome_treinador)}), Color("8a7f6a"))
