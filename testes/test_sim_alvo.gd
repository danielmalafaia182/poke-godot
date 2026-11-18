extends SceneTree
## Alvo por tempo de caminho (A, medir_alvo.py) em hunts-labirinto: nightmare_elekid e nightmare_snorunt com o time da
## varredura 2b.6 (Venusaur IV 32, Q 1,8, nível pela hunt), 60 s, 20 sementes cada. Com o alvo em linha reta (Chebyshev),
## 13/20 sementes do elekid não abatiam nada (o herói ia atrás de um selvagem a > 60 s de caminho). Saída: uma linha por
## semente e RESULTADO. Rodar: testes/rodar.sh res://testes/test_sim_alvo.gd [--criterio=chebyshev]
const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")

func _init() -> void:
	var criterio := "caminho"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--criterio="): criterio = a.substr(11)
	var dados = DadosJogo.carregar()
	var falhas := 0
	var total := 0
	for slug in ["nightmare_elekid", "nightmare_snorunt"]:
		var sem_abate := 0
		total += 1
		_rodar(slug, criterio, dados)
		sem_abate = _sem_abate
		var ok := sem_abate == 0
		if not ok: falhas += 1
		print(("OK    " if ok else "FALHA ") + "%s: toda semente abate em 60 s (%d/20 sem abate)" % [slug, sem_abate])
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)


var _sem_abate := 0


func _rodar(slug: String, criterio: String, dados) -> void:
	_sem_abate = 0
	var mapa = MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao())
	var nivel_hunt := 2000
	var xp := Regras.xp_total_para_nivel(mini(100000, nivel_hunt * 3 + 50))
	var jogo := {"slug": slug, "hunt": slug, "equipe": [{"id": "v", "nome": "Venusaur", "xp": xp,
		"ivs": {"hp": 32, "atk": 32, "def": 32, "spAtk": 32, "spDef": 32, "speed": 32}, "quality": 1.8, "hp": -1}],
		"auto_potion": true, "penalizar": false, "inventario": [{"itemId": 203, "quantity": 999}, {"itemId": 204, "quantity": 999}]}
	for s in range(1, 21):
		var cfg := CenarioJogo.configurar(jogo, dados, s * 7919, 0)
		var sim = Simulacao.new(cfg, dados, mapa)
		sim.p["alvo_criterio"] = criterio
		sim.iniciar()
		var primeiro_kill := -1
		var lutando := 0
		var alvo_nulo := 0
		var dist_min := 999
		for t in 300:
			for reg in sim.passo():
				var m: Dictionary = reg.get("msg", reg)
				var ty := String(m.get("type", ""))
				if ty == "field-kill" and primeiro_kill < 0: primeiro_kill = t
				if ty == "field":
					if bool(m.get("fighting", false)): lutando += 1
					if m.get("targetSlot") == null: alvo_nulo += 1
					var h: Dictionary = m["hero"]
					for mb in m["mobs"]:
						if not bool(mb["dead"]):
							dist_min = mini(dist_min, maxi(absi(int(mb["row"]) - int(h["row"])), absi(int(mb["col"]) - int(h["col"]))))
		if int(sim.estatisticas["abates"]) == 0: _sem_abate += 1
		print("  %s semente %d: abates %d, 1º no tick %d, fields lutando %d, alvo nulo %d, dist mín %d, hits %d" % [slug, s, sim.estatisticas["abates"], primeiro_kill, lutando, alvo_nulo, dist_min, sim.estatisticas["hits_aliado"]])
