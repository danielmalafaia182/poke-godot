extends SceneTree
## Game Master (rodar com testes/rodar.sh: user:// isolado). Para cada um dos 22 Resources de regras, muda um valor num
## perfil de teste em user:// e confere que o comportamento esperado muda; depois restaura e confere que a sim volta ao
## byte a byte do perfil original. Também: o original não se edita e as alterações de tabela (AlteracoesTabelas) valem.

const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Regras := preload("res://sim/regras.gd")
const RJ := preload("res://sim/regras_jogo.gd")
const Ref := preload("res://testes/regras_referencia.gd")

var falhas := 0
var total := 0
var dados


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _sim_orre() -> String:
	var j := {"slug": "electrike", "hunt": "electrike", "vip": true, "penalizar": true, "auto_catch": true, "bola_auto_catch": 3, "bolas": {3: 500},
		"equipe": [{"id": "g", "nome": "Golem", "xp": Regras.xp_total_para_nivel(560), "ivs": {"hp": 20, "atk": 20, "def": 20, "spAtk": 20, "spDef": 20, "speed": 20},
		"quality": 1.3, "hp": -1}], "auto_potion": true, "inventario": [{"itemId": 204, "quantity": 500}]}
	var cfg := CenarioJogo.configurar(j, dados, 9, 0)
	cfg["streak"] = {"exp": 5}
	return Ref.rodar(cfg, dados, "electrike", 2.0).md5_text()


func _comportamentos() -> Dictionary:
	## Um efeito observável por Resource (função → valor comparável).
	var d = dados
	return {
		"RegrasCombate": ["stab", 3.0, func(): return _sim_orre()],
		"RegrasMovimento": ["hero_step_ms", 250, func(): return _sim_orre()],
		"RegrasXP": ["xp_regiao", {"orre": 3.0}, func(): return _sim_orre()],
		"RegrasCaptura": ["captura_c", 1000.0, func(): return _sim_orre()],
		"RegrasLoot": ["pack_chance_abate", 1.0, func(): return _sim_orre()],
		"RegrasSessao": ["penalidade_fator", 1.0, func(): return _sim_orre()],
		"RegrasEventos": ["streak_pct_por_ponto", 0.5, func(): return _sim_orre()],
		"RegrasVIP": ["vip_fracao", 0.9, func(): return _sim_orre()],
		"RegrasEconomia": ["qtd_max_por_compra", 1.0, func():
			var s = load("res://sim/servico_cidade.gd").new(d)
			var e := {"gold": 100000, "itens": {}, "bolas": {}, "cidade": "cerulean", "pokes": []}
			return JSON.stringify(s.tratar(e, {"type": "shop-buy", "itemId": 200, "qty": 5}))],
		"RegrasDiarias": ["kill_min_nivel", 999, func():
			var s = load("res://sim/servico_diarias.gd").new(d)
			var e := {"nivel": 100}
			return bool(s.tratar(e, {"type": "daily-kill-get", "agora": 1795000000})[0].get("locked", false))],
		"RegrasJogador": ["streak_custo_base", 1, func():
			return int(load("res://sim/servico_jogador.gd").new().msg_streak({"streak": {"abates": 5000}})["nextCost"])],
		"RegrasGinasios": ["fator_dano_lider", 100.0, func():
			var s = load("res://sim/servico_ginasios.gd").new(d)
			var e := {}
			var t := [{"speciesId": 74, "xp": Regras.xp_total_para_nivel(15), "ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}, "quality": 1.0}]
			return bool(s.tratar(e, {"type": "ginasio-desafiar", "gymId": "pewter", "agora": 1795000000, "nivel": 200, "time": t, "semente": 3})[0].get("venceu", false))],
		"RegrasBosses": ["historico_max", 1, func():
			var s = load("res://sim/servico_bosses.gd").new(d)
			var e := {"itens": {}, "gold": 0}
			var t := [{"speciesId": 76, "xp": Regras.xp_total_para_nivel(600), "ivs": {"hp": 32, "atk": 32, "def": 32, "spAtk": 32, "spDef": 32, "speed": 32}, "quality": 1.5}]
			var b := String(s.p.lista[0]["key"])
			for i in 2:
				s.tratar(e, {"type": "boss-desafiar", "key": b, "time": t, "agora": 1795000000 + i * 100000, "nivel": 3000, "semente": i})
			return (e.get("bosses", {}).get("historico", []) as Array).size()],
		"RegrasCards": ["pesos_raridade", {"classic_collection": 1.0}, func():
			return JSON.stringify(load("res://sim/servico_cards.gd").new().p["pesos_raridade"])],
		"RegrasItens": ["candy_max_por_pokemon", 0, func():
			var s = load("res://sim/servico_itens.gd").new(d)
			var e := {"pokes": [{"id": "a", "speciesId": 1, "xp": 0, "team": true}], "itens": {"90124": 1}}
			return String(s.tratar(e, {"type": "use-candy", "pokeId": "a"})[0]["type"])],
		"RegrasProfissoes": ["captura_pct_rank", 10.0, func():
			var s = load("res://sim/servico_profissoes.gd").new(d)
			var e := {}
			s.tratar(e, {"type": "prof-escolher", "prof": "botanist"})
			return s.bonus_captura(e)],
		"RegrasBreeding": ["slots", 0, func():
			var s = load("res://sim/servico_breeding.gd").new(d)
			var e := {"pokes": [{"id": "a", "speciesId": 76, "ivs": {"hp": 1, "atk": 1, "def": 1, "spAtk": 1, "spDef": 1, "speed": 1}, "quality": 1.0, "team": false},
				{"id": "b", "speciesId": 76, "ivs": {"hp": 1, "atk": 1, "def": 1, "spAtk": 1, "spDef": 1, "speed": 1}, "quality": 1.0, "team": false}], "itens": {"109": 9}}
			return String(s.tratar(e, {"type": "breed", "paiA": "a", "paiB": "b"})[0]["type"])],
		"RegrasGoldenStars": ["duracao_s", 60, func():
			var s = load("res://sim/servico_golden_stars.gd").new(d)
			var e := {"gold": 0, "itens": {}}
			s.tratar(e, {"type": "gs-roll", "agora": 1000, "nivel": 100, "semente": 1})
			var st: Dictionary = s.tratar(e, {"type": "gs-pick", "slot": 0, "agora": 1000, "semente": 1})[0]["star"]
			return int(st["expiresAt"]) - int(st["startedAt"])],
		"RegrasPesca": ["peixes_por_nivel", 10, func(): return load("res://sim/servico_pesca.gd").new(d).for_next(4)],
		"RegrasDitto": ["duracao_s", 60, func():
			var s = load("res://sim/servico_ditto.gd").new(d)
			return int(s.tratar({}, {"type": "ditto-transformar", "pokeId": "x", "speciesId": 6, "lider": true, "agora": 0})[0].get("ate", -1))],
		"RegrasInterface": ["cartoes_por_instancia", 0.0, func():
			var a = load("res://sim/regras_apresentacao.gd").new()
			a.nova_instancia("k")
			return a.mostrar_cartao({"shiny": false}, 0)],
		"RegrasJogoNovo": ["ouro_inicial", 777, func():
			return int(load("res://sim/servico_novo_jogo.gd").criar(1, 1, "T")["ouro"])],
	}


func _init() -> void:
	dados = DadosJogo.carregar()
	var base: Dictionary = Ref.cenarios(dados)
	checar(RJ.perfil() == "original" and RJ.gravar_valor("RegrasCombate", "stab", 9.0) != "", "o perfil original não se edita")
	checar(RJ.criar_perfil("teste") == "", "perfil de teste criado em user://")
	RJ.definir_perfil("teste")
	var comp := _comportamentos()
	checar(comp.size() == RJ.recursos().size(), "um teste por Resource (%d)" % comp.size(), str(RJ.recursos()))
	for rec in comp:
		var c: Array = comp[rec]
		var antes = (c[2] as Callable).call()
		var erro := RJ.gravar_valor(rec, String(c[0]), c[1])
		var depois = (c[2] as Callable).call()
		RJ.restaurar(rec)
		var volta = (c[2] as Callable).call()
		checar(erro == "" and str(antes) != str(depois) and str(volta) == str(antes), "%s.%s muda o comportamento e o restaurar volta" % [rec, String(c[0])],
			"%s → %s → %s" % [str(antes).left(16), str(depois).left(16), str(volta).left(16)])
	# restaurar um campo só (não o arquivo inteiro)
	RJ.gravar_valor("RegrasCombate", "stab", 2.0)
	RJ.gravar_valor("RegrasCombate", "piso_aliado", 9)
	RJ.restaurar("RegrasCombate", "stab")
	checar(float(RJ.valores("RegrasCombate")["stab"]) == float(RJ.original("RegrasCombate", "stab")) and int(RJ.valores("RegrasCombate")["piso_aliado"]) == 9,
		"restaurar original por campo (stab volta, piso_aliado fica)")
	RJ.restaurar("RegrasCombate")
	# alterações de tabela
	var alt = preload("res://dados/regras/scripts/alteracoes_tabelas.gd").new()
	alt.especies.append({"id": 246, "campo": "xpAbate", "valor": 99999})
	DirAccess.make_dir_recursive_absolute("user://regras/teste")
	ResourceSaver.save(alt, "user://regras/teste/alteracoes.tres")
	RJ.recarregar()
	checar(int(DadosJogo.carregar().especie(246)["xpAbate"]) == 99999, "AlteracoesTabelas: XP do Larvitar mudado por cima da tabela importada")
	DirAccess.remove_absolute("user://regras/teste/alteracoes.tres")
	# build exportado: um .tres em user://regras/original/ sobrepõe o original empacotado (que fica intacto)
	RJ.definir_perfil("original")
	var rc: Resource = load("res://dados/regras/original/RegrasCombate.tres").duplicate()
	rc.set("stab", 2.5)
	DirAccess.make_dir_recursive_absolute("user://regras/original")
	ResourceSaver.save(rc, "user://regras/original/RegrasCombate.tres")
	RJ.recarregar()
	var sob := float(RJ.valores("RegrasCombate")["stab"])
	DirAccess.remove_absolute("user://regras/original/RegrasCombate.tres")
	RJ.recarregar()
	checar(sob == 2.5 and float(RJ.valores("RegrasCombate")["stab"]) == 1.5 and float(load("res://dados/regras/original/RegrasCombate.tres").get("stab")) == 1.5,
		"user://regras/original/ sobrepõe o original sem tocar no pacote")
	RJ.recarregar()
	dados = DadosJogo.carregar()
	var depois: Dictionary = Ref.cenarios(dados)
	var igual := true
	for k in base:
		igual = igual and String(base[k]) == String(depois[k])
	checar(igual, "tudo restaurado: a sim volta ao byte a byte do original (3 cenários)")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
