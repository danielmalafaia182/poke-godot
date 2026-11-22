extends SceneTree
## Campanha do zero na sim pura (escopo de 18/11, item 3). Sem cena, sem autoload, sem save: só sim/.
##
## Jogador (política E, documentada no relatório):
##   - Começo = jogo novo do projeto (sim/servico_novo_jogo.gd): Geodude Lv.1, treinador 1, 100 Small Potions,
##     100 Poké Balls, ouro 0, Cerulean.
##   - Cidade a cada sessão (sim/servico_cidade.gd, os mesmos comandos do jogo): Nurse Joy (joy-heal), vende todo o loot
##     vendável (shop-sell; poções e pedras o Mark não compra, C), evolui com pedras quando dá (evolve-info/evolve
##     useStone; nunca sem pedra, que volta ao Lv.1), compra poções e Poké Balls (shop-buy).
##   - Poção: a menor que cura ≥ 35% do HP máximo (ou a maior), estoque-alvo 150. Bolas: Poké Ball, estoque-alvo 60,
##     Auto-Catch ligado com ela, capturas vão para a BOX (o time é só o líder).
##   - Escolha da hunt: entre as liberadas pelo nível do treinador (sim/regras_acesso.gd, C), as das 3 faixas de nível
##     mais altas que não passam de nível do líder + 20, mais a atual; até 5, cada uma sondada por 2 min (sem a
##     penalidade de entrada, para comparar). Fica a de maior XP/min sem desmaio. A sondagem não conta no tempo jogado.
##   - Hunt onde o líder morreu fica de fora até ele subir 10 níveis (um jogador não insiste na hunt que o derruba).
##   - Pedras: com o nível para evoluir e sem as pedras, entram nas candidatas as hunts liberadas cujas espécies dropam a
##     pedra que falta (tabela de loot do creatures.json, A); a nota soma XP/min e pedras/min, cada um dividido pelo
##     melhor das candidatas.
##   - Sessão: 60 min de sim na hunt escolhida (para antes se o time cai: field-none sem-reserva = morte). A penalidade
##     de entrada vale como no original (hunt diferente da anterior: lock de 60 s, A).
## Por hunt: minutos jogados, abates/min, mortes, XP/h do treinador, ouro/h (venda do loot daquela hunt), poções/h, e o
## maior trecho travado (herói parado, sem lutar, com selvagem vivo e alvo definido).
##
## Ciclo 2 (`--completo 1`): tudo que o offline tem ligado, com relógio de calendário (início 19/11/2026 03:00 UTC):
##   - Dia = `--horas_dia` (16) h de jogo ativo + o resto em Modo Soneca (sim/servico_jogador.gd: amostra de 5 min na
##     última hunt, sem bolas; coleta de 50% da taxa pelo tempo fora, A/C).
##   - Streak Points (C/A): abates contam; na cidade compra ponto na trilha EXP quando o ouro passa de 1,5× o custo (E).
##   - Daily Gift todo dia (boosts de 1 h vão para a sim; itens e bolas para a BAG), Daily Kill (escolhe a opção de mais XP
##     cuja espécie está numa hunt liberada que o líder aguenta; a nota da hunt soma o XP marginal da missão), Daily Catch
##     (capturas dão XP), Quests & Tasks (entrega tudo que completar, antes de vender o loot).
##   - Tipo do Dia pela rotação (sim/servico_jogador.gd), boosts ativos, VIP por `--vip 0|1`.
##   - Ginásios (ciclo 3): na cidade desafia os liberados sem insígnia ativa, só com o líder; as ativas valem na hunt.
##   - Orre ×10 de XP (balanceamento.json xp_regiao, decisão do ciclo 3). Berries e Rare Candy: lote 3 congelado, fora.
##   - Auto-Catch Shiny ligado com a melhor bola que tiver (decisão do ciclo 2).
##   - Metas visíveis (sim/metas.gd): a cada sessão registra a hunt recomendada, a próxima meta e os marcos.
##
## Ciclo 5 (`--time 1`): time de até 6 (política E, como um jogador faria):
##   - Capturas vão para a BOX como indivíduo novo de nível 1 (A: o capturado é um sorteio novo, IV 1..32 e Quality pelos
##     pesos do cliente; sim/regras.gd sortear_ivs/sortear_qualidade). BOX com no máximo 40: vende ao Mark o excesso de
##     menor Power (C: só BOX, nunca shiny).
##   - Time: na cidade, os 6 de maior Power, preferindo um tipo principal novo a cada vaga (cobertura); o resto vai para a
##     BOX. Evolui com pedra cada membro do time que puder.
##   - Líder por hunt: para cada hunt candidata, o membro do time de maior Power × vantagem de tipo (efetividade média dos
##     tipos dele contra as espécies da hunt ÷ a das espécies contra ele, sim/regras.gd); os outros vão de reserva (troca
##     automática ao desmaiar, regra E do projeto). As candidatas saem do nível do carregador (o de maior nível).
##   - Treino: 1 sessão em 4 o líder é o membro mais fraco do time, numa hunt do nível dele (o jogador sobe as reservas).
##   - XP do Pokémon só para quem está em campo (A: poke-xp só do ativo).
## Ciclo 6 (`--time 1`, decisão do usuário: revezar como um jogador, sem XP dividido):
##   - Revezamento na sessão: a cada `--rodizio_min` (10) min, lidera o membro com menos XP entre os que aguentam a hunt
##     (Power × vantagem de tipo ≥ Power da hunt, sim/metas.gd); a troca é o comando `switch` (5 s de espera, A/C).
##   - Bosses (sim/servico_bosses.gd): uma vez por dia, Auto Boss de até 50 lutas no boss Especial (sem entrada) mais
##     alto que o time vence; o boss que derrota o time fica de fora até o carregador subir 20 níveis.
##   - Itens (sim/servico_itens.gd, lote 3): Rare Candy no membro mais fraco (≤ nível 100, até 10); Held Machine (premium
##     com 50 Devoted Tokens, básica com 20 se o carregador não tem held), equipa o held novo se o tier for maior que o
##     do carregador (senão no membro sem held); com 10 peças, disco elemental do tipo do carregador e AoE TM, ensinados ao
##     carregador (estágio final) ou ao próximo membro que possa aprender. Berries: sem fonte fixa offline, fora.
##   - Profissão (sim/servico_profissoes.gd): Botânico desde o começo; cria berries com as ervas (10 + 5000 de ouro, só
##     se sobrar o dobro do custo) e sobe de rank assim que os requisitos fecham; o bônus de captura e o mentor (A) valem.
##
## Uso: testes/rodar.sh res://testes/campanha.gd [--horas N] [--nivel_alvo N] [--semente N] [--saida caminho.json]
##      [--completo 1] [--vip 1] [--horas_dia 16]   (padrão: 300 h simuladas ou treinador 2000)

const Regras := preload("res://sim/regras.gd")
const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const ServicoCidade := preload("res://sim/servico_cidade.gd")
const NovoJogo := preload("res://sim/servico_novo_jogo.gd")
const Acesso := preload("res://sim/regras_acesso.gd")
const ServicoJogador := preload("res://sim/servico_jogador.gd")
const ServicoDiarias := preload("res://sim/servico_diarias.gd")
const Metas := preload("res://sim/metas.gd")
const Ginasios := preload("res://sim/servico_ginasios.gd")

const TICKS_MIN := 300
var dados
var cidade
var mapas := {}
var hunts_lista: Array = []
var args := {"horas": 300.0, "nivel_alvo": 2000, "semente": 1, "saida": "saida_testes/campanha.json", "sessao_min": 60, "sonda_min": 2,
	"completo": 0, "vip": 0, "horas_dia": 16.0, "time": 0, "rodizio_min": 10}

# estado do jogador (formato do sim/servico_cidade.gd)
var est := {}
var treinador_xp := 0
var medidor := {}
var ultima_hunt := ""
var semente_seq := 0

var por_hunt := {}
var bloqueadas := {}   # slug -> nível do líder quando morreu ali
var pedras_obtidas := {}   # itemId -> qtd (loot de pedra na campanha)
var linha_tempo: Array = []
var minutos_jogados := 0.0
var t0 := 0
# ciclo 2
var jogador
var diarias
var gin
var agora_s := 0          # relógio de calendário (unix s)
var ativo_no_dia := 0.0   # minutos de jogo ativo no dia atual
var dia_atual := -1
var colecao := {}         # speciesId -> true (espécies capturadas)
var nome_para_id := {}
var extras := {"soneca_xp": 0, "soneca_pxp": 0, "sonecas": 0, "tarefas_xp": 0, "tarefas_ouro": 0, "tarefas": 0, "kill_xp": 0,
	"kills_diarios": 0, "catch_xp": 0, "ginasios_vitorias": 0, "ginasios_derrotas": 0, "insignias_max": 0, "gift": 0, "streak_pontos": 0, "streak_ouro": 0, "shiny_vistos": 0, "shiny_capturados": 0}
var marcos_vistos := {}
var rng_box = preload("res://sim/rng.gd").new(9173)
var itens_srv
var bosses_srv
var prof_srv
var boss_bloq := {}   # key -> nível do carregador quando o boss venceu
var n_capturados := 0
var lider_sessao := ""   # id do Pokémon que lidera a sessão (modo time)
var treino := false      # sessão de treino (líder = o membro mais fraco)
var orre := {"inicio_h": -1.0, "min": 0.0, "xp": 0, "mortes": 0, "sessoes": 0, "por_hunt": {}}
var metas_linha: Array = []


func _init() -> void:
	t0 = Time.get_ticks_msec()
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		var k := String(a[i]).trim_prefix("--")
		if args.has(k) and i + 1 < a.size():
			args[k] = type_convert(a[i + 1], typeof(args[k]))
	dados = DadosJogo.carregar()
	cidade = ServicoCidade.new(dados)
	hunts_lista = dados.hunts.values()
	jogador = ServicoJogador.new()
	diarias = ServicoDiarias.new(dados)
	gin = Ginasios.new(dados)
	itens_srv = preload("res://sim/servico_itens.gd").new(dados)
	bosses_srv = preload("res://sim/servico_bosses.gd").new(dados)
	prof_srv = preload("res://sim/servico_profissoes.gd").new(dados)
	agora_s = int(Time.get_unix_time_from_datetime_string("2026-11-19T03:00:00"))
	for id in dados.especies:
		nome_para_id[String(dados.especies[id]["nome"])] = int(id)
	_novo_jogo()
	_campanha()
	_relatorio()
	quit(0)


func _mapa(slug: String):
	if not mapas.has(slug):
		if mapas.size() > 40:
			mapas.clear()
		mapas[slug] = MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao())
	return mapas[slug]


func _novo_jogo() -> void:
	var r: Dictionary = NovoJogo.criar(NovoJogo.INICIAL_CAMPANHA, int(args["semente"]), "Campanha", "campanha")
	var ini: Dictionary = r["inicial"]
	est = {"gold": int(r["ouro"]), "cidade": "cerulean", "vip": int(args["vip"]) == 1, "streak": {}, "boosts": [], "itens": {}, "bolas": {}, "depot": {"itens": {}},
		"pokes": [{"id": "lider", "speciesId": int(ini["speciesId"]), "xp": int(ini["xp"]), "ivs": ini["ivs"],
			"quality": float(ini["quality"]), "hp": -1, "shiny": false, "team": true, "slot": 0, "leader": true, "starter": true}]}
	for k in r["pocoes"]:
		est["itens"][str(k)] = int(r["pocoes"][k])
	for k in r["bolas"]:
		est["bolas"][str(k)] = int(r["bolas"][k])
	print("INICIO Geodude Lv.1, IV %s (total %d), Q %.3f" % [str(ini["ivs"]), _soma_iv(ini["ivs"]), float(ini["quality"])])


static func _soma_iv(ivs: Dictionary) -> int:
	var s := 0
	for k in ivs:
		s += int(ivs[k])
	return s


func _lider() -> Dictionary:
	if not modo_time():
		return est["pokes"][0]
	var melhor: Dictionary = {}
	for pk in _time():
		if melhor.is_empty() or int(pk["xp"]) > int(melhor["xp"]):
			melhor = pk
	return melhor


func modo_time() -> bool:
	return int(args["time"]) == 1


func _time() -> Array:
	var t: Array = []
	for pk in est["pokes"]:
		if bool(pk.get("team", false)):
			t.append(pk)
	t.sort_custom(func(a, b): return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	return t


func _poke_id(id: String) -> Dictionary:
	for pk in est["pokes"]:
		if String(pk["id"]) == id:
			return pk
	return {}


func _nivel(pk: Dictionary) -> int:
	return Regras.nivel_por_xp(int(pk["xp"]))


func _tipos_esp(sid: int) -> Array:
	return Regras.tipos_de(dados.especie(sid))


func _vantagem(pk: Dictionary, slug: String) -> float:
	## Efetividade média dos tipos do Pokémon contra as espécies da hunt ÷ a das espécies contra ele (amplificada, A/B).
	var meus := _tipos_esp(int(pk["speciesId"]))
	var at := 0.0
	var de := 0.0
	var n := 0
	for x in dados.hunts[slug].get("spawns", []):
		var ts := _tipos_esp(int(x.get("pokeId", 0)))
		var a := 0.0
		for t in meus:
			if String(t) != "":
				a = maxf(a, Regras.efetividade_amplificada(Regras.efetividade_bruta(String(t), String(ts[0]), String(ts[1]))))
		var d := 0.0
		for t in ts:
			if String(t) != "":
				d = maxf(d, Regras.efetividade_amplificada(Regras.efetividade_bruta(String(t), String(meus[0]), String(meus[1]))))
		at += a
		de += d
		n += 1
	if n == 0:
		return 1.0
	return (at / n) / maxf(0.2, de / n)


func _melhor_membro(slug: String) -> Dictionary:
	var melhor: Dictionary = {}
	var mv := -1.0
	for pk in _time():
		var v := float(Metas.poder_lider(dados, pk)) * _vantagem(pk, slug)
		if v > mv:
			mv = v
			melhor = pk
	return melhor


func _viaveis(slug: String) -> Array:
	## ids dos membros que aguentam a hunt: Power × vantagem de tipo ≥ Power da hunt (sim/metas.gd).
	var ph := float(Metas.poder_hunt(dados, slug))
	var r: Array = []
	for pk in _time():
		if _ataca(pk) and float(Metas.poder_lider(dados, pk)) * _vantagem(pk, slug) >= ph:
			r.append(String(pk["id"]))
	return r


func _usar_itens() -> void:
	## Ciclo 6: Rare Candy, Held Machine e held, TMs (comandos do sim/servico_itens.gd sobre o mesmo `est`).
	est["nivel"] = _nivel_treinador()
	if not est.has("itens_uso"):
		est["itens_uso"] = {}
	var candy := str(int(itens_srv.p.candy_id))
	while int(est["itens"].get(candy, 0)) > 0:
		var alvo: Dictionary = {}
		for pk in _time():
			if _nivel(pk) <= 100 and int(est["itens_uso"].get("candy", {}).get(String(pk["id"]), 0)) < 10 and (alvo.is_empty() or int(pk["xp"]) < int(alvo["xp"])):
				alvo = pk
		if alvo.is_empty():
			break
		if String(itens_srv.tratar(est, {"type": "use-candy", "pokeId": String(alvo["id"])})[0]["type"]) != "candy-used":
			break
		extras["candies"] = int(extras.get("candies", 0)) + 1
	var l3: Dictionary = dados.lote3
	var tok := str(int(l3.get("held_token_id", 13115)))
	var car := _lider()
	var h_car := int(est["itens_uso"].get("held", {}).get(String(car["id"]), 0))
	while int(est["itens"].get(tok, 0)) >= 50 or (int(est["itens"].get(tok, 0)) >= 20 and h_car == 0):
		var of := "premium" if int(est["itens"].get(tok, 0)) >= 50 else "basic"
		semente_seq += 1
		var r: Array = itens_srv.tratar(est, {"type": "held-trade", "oferta": of, "semente": int(args["semente"]) * 7 + semente_seq})
		if String(r[0]["type"]) != "held-traded":
			break
		extras["helds_sorteados"] = int(extras.get("helds_sorteados", 0)) + 1
		var novo := int(r[0]["itemId"])
		var tier_car := int(l3["helds"].get(str(h_car), {}).get("tier", 0))
		var destino := String(car["id"]) if int(r[0]["tier"]) > tier_car else ""
		if destino == "":
			for pk in _time():
				if int(est["itens_uso"].get("held", {}).get(String(pk["id"]), 0)) == 0:
					destino = String(pk["id"])
					break
		if destino != "":
			itens_srv.tratar(est, {"type": "held-equip", "pokeId": destino, "itemId": novo})
			if destino == String(car["id"]):
				h_car = novo
	for par in [["tm_peca_id", ""], ["tm_peca_aoe_id", "AOE"]]:
		while int(est["itens"].get(str(int(l3.get(par[0], 0))), 0)) >= int(l3.get("tm_pecas_por_disco", 10)):
			var quem: Dictionary = {}
			var tipo := String(par[1])
			for pk in [car] + _time():
				var t0 := String(Regras.tipos_de(dados.especie(int(pk["speciesId"])))[0])
				var tp := tipo if tipo != "" else t0
				var ja: Dictionary = est["itens_uso"].get("tms", {}).get(String(pk["id"]), {})
				if (tipo == "AOE" and bool(ja.get("aoe", false))) or (tipo == "" and String(ja.get("elemental", "")) != ""):
					continue
				if itens_srv.pode_aprender(pk, itens_srv.disco_do_tipo(tp)) == "":
					quem = pk
					tipo = tp
					break
			if quem.is_empty():
				break
			itens_srv.tratar(est, {"type": "tm-trade", "tipo": tipo})
			var r2: Array = itens_srv.tratar(est, {"type": "tm-learn", "pokeId": String(quem["id"]), "itemId": itens_srv.disco_do_tipo(tipo)})
			if String(r2[0]["type"]) == "tm-learned":
				extras["tms"] = int(extras.get("tms", 0)) + 1
			tipo = String(par[1])


func _bosses_dia() -> void:
	## Ciclo 6: Auto Boss de até 50 lutas no boss Especial (sem entrada) mais alto que o time vence.
	est["nivel"] = _nivel_treinador()
	var time: Array = []
	for pk in _time():
		time.append({"speciesId": int(pk["speciesId"]), "xp": int(pk["xp"]), "ivs": pk["ivs"], "quality": float(pk["quality"])})
	var cands: Array = []
	for b in bosses_srv.p.lista:
		if b.get("entrada") == null and int(b["nivel"]) <= _nivel_treinador() and _nivel_lider() >= int(boss_bloq.get(String(b["key"]), -1000)) + 20:
			cands.append(b)
	cands.sort_custom(func(a, b): return int(a["nivel"]) > int(b["nivel"]))
	for b in cands.slice(0, 3):
		var r: Array = bosses_srv.tratar(est, {"type": "auto-boss", "key": String(b["key"]), "lutas": 50, "time": time, "agora": agora_s, "nivel": _nivel_treinador(), "semente": agora_s + semente_seq})
		var m: Dictionary = r[0]
		var vit := 0
		for l in m.get("lutas", []):
			vit += 1 if bool(l["venceu"]) else 0
		extras["boss_vitorias"] = int(extras.get("boss_vitorias", 0)) + vit
		if vit == 0:
			boss_bloq[String(b["key"])] = _nivel_lider()
			continue
		break


func _mais_fraco() -> Dictionary:
	var r: Dictionary = {}
	for pk in _time():
		if r.is_empty() or int(pk["xp"]) < int(r["xp"]):
			r = pk
	return r


func _ataca(pk: Dictionary) -> bool:
	## Tem golpe de dano no nível atual (A/C: golpes por nível da espécie). Sem ele o Pokémon não abate nada nem sobe
	## (XP só do ativo): Poliwag só ataca a partir do 5, Metapod nunca. Um jogador não o põe no time.
	var nv := _nivel(pk)
	for g in dados.especie(int(pk["speciesId"])).get("golpes", []):
		if int(g.get("nivel", 999)) <= nv and String(g.get("categoria", "STATUS")) != "STATUS" and int(g.get("poder", 0)) > 0:
			return true
	return false


func _montar_time() -> void:
	## Os 6 de maior Power, preferindo um tipo principal novo a cada vaga; o resto na BOX; excesso da BOX vendido.
	var todos: Array = (est["pokes"] as Array).filter(func(pk): return _ataca(pk) or bool(pk.get("starter", false)))
	var pod := {}
	for pk in todos:
		pod[String(pk["id"])] = Metas.poder_lider(dados, pk)
	todos.sort_custom(func(a, b): return int(pod[String(a["id"])]) > int(pod[String(b["id"])]))
	var time: Array = []
	var tipos := {}
	for pk in todos:
		if time.size() >= 6:
			break
		var t0 := String(_tipos_esp(int(pk["speciesId"]))[0])
		if not tipos.has(t0):
			time.append(pk)
			tipos[t0] = true
	var especies := {}
	for pk in time:
		especies[int(pk["speciesId"])] = true
	for pk in todos:   # depois, uma espécie nova a cada vaga; só então repete
		if time.size() >= 6:
			break
		if not pk in time and not especies.has(int(pk["speciesId"])):
			time.append(pk)
			especies[int(pk["speciesId"])] = true
	for pk in todos:
		if time.size() >= 6:
			break
		if not pk in time:
			time.append(pk)
	for pk in est["pokes"]:
		pk["team"] = pk in time
		pk["leader"] = false
		pk["slot"] = time.find(pk) if pk in time else -1
	todos = (est["pokes"] as Array).duplicate()
	todos.sort_custom(func(a, b): return Metas.poder_lider(dados, a) > Metas.poder_lider(dados, b))
	var box: Array = todos.filter(func(pk): return not pk in time and not bool(pk.get("shiny", false)) and not bool(pk.get("starter", false)))
	if box.size() > 40:
		var ids: Array = []
		for pk in box.slice(40):
			ids.append(String(pk["id"]))
		cidade.tratar(est, {"type": "pokemon-sell", "pokeIds": ids})


func _nivel_lider() -> int:
	if modo_time() and treino and not _mais_fraco().is_empty():
		return Regras.nivel_por_xp(int(_mais_fraco()["xp"]))
	return Regras.nivel_por_xp(int(_lider()["xp"]))


func _nivel_treinador() -> int:
	return Regras.nivel_por_xp(treinador_xp)


func _jogo(slug: String, penalizar: bool) -> Dictionary:
	var l: Dictionary = _lider()
	var inv: Array = []
	for k in est["itens"]:
		if int(k) >= 200 and int(k) <= 204:
			inv.append({"itemId": int(k), "quantity": int(est["itens"][k])})
	var bolas := {}
	for k in est["bolas"]:
		bolas[int(k)] = int(est["bolas"][k])
	var equipe: Array = [{"id": String(l.get("id", "lider")),
		"nome": String(dados.especie(int(l["speciesId"]))["nome"]), "xp": int(l["xp"]), "ivs": l["ivs"], "quality": float(l["quality"]),
		"hp": int(l["hp"]), "shiny": bool(l.get("shiny", false))}]
	if modo_time():
		var lp: Dictionary = _poke_id(lider_sessao) if lider_sessao != "" else _lider()
		if lp.is_empty():
			lp = _lider()
		equipe.clear()
		for pk in [lp] + _time().filter(func(x): return x != lp):
			equipe.append({"id": String(pk["id"]), "nome": String(dados.especie(int(pk["speciesId"]))["nome"]), "xp": int(pk["xp"]),
				"ivs": pk["ivs"], "quality": float(pk["quality"]), "hp": int(pk.get("hp", -1)), "shiny": bool(pk.get("shiny", false))})
	return {"slug": slug, "hunt": String(dados.hunts[slug]["nome"]), "equipe": equipe, "lider": 0, "treinador_xp": treinador_xp, "inventario": inv, "bolas": bolas,
		"auto_catch": int(est["bolas"].get("1", 0)) > 0, "bola_auto_catch": 1, "auto_potion": true, "pocao_id": 0,
		"medidor_captura": medidor, "vip": int(args["vip"]) == 1, "penalizar": penalizar,
		"auto_catch_shiny": completo(), "bola_auto_catch_shiny": _bola_shiny(),
		"helds": (est.get("itens_uso", {}).get("held", {}) as Dictionary).duplicate(),
		"tms": (est.get("itens_uso", {}).get("tms", {}) as Dictionary).duplicate(true)}.merged(prof_srv.para_sim(est) if modo_time() and completo() else {})


func completo() -> bool:
	return int(args["completo"]) == 1


func _bola_shiny() -> int:
	for id in [7, 6, 4, 3, 2, 1]:
		if int(est["bolas"].get(str(id), 0)) > 0:
			return id
	return 0


func _rodar(slug: String, minutos: float, penalizar: bool, aplicar: bool, sem_bolas: bool = false) -> Dictionary:
	semente_seq += 1
	var cfg := CenarioJogo.configurar(_jogo(slug, penalizar), dados, int(args["semente"]) * 100003 + semente_seq, agora_s * 1000 if completo() else 0)
	if completo():
		cfg["streak"] = jogador.efeitos_streak(est)
		cfg["eventos"] = jogador.msg_eventos(agora_s)["events"]
		cfg["boosts"] = (est["boosts"] as Array).filter(func(b): return int(b.get("until", 0)) > agora_s * 1000)
		cfg["insignias"] = gin.ativas(est, agora_s)   # ciclo 3: insígnias de ginásio (+1% XP e drop cada)
		if sem_bolas:
			cfg["auto_catch"] = false
			cfg["auto_catch_shiny"] = false
	var sim = Simulacao.new(cfg, dados, _mapa(slug))
	sim.iniciar()
	var r := {"slug": slug, "ticks": 0, "abates": 0, "morte": false, "xp": 0, "loot": {}, "capturas": 0, "pocoes": 0,
		"travado_max_s": 0.0, "por_especie": {}, "capturas_especie": [], "pxp": 0, "shiny": 0, "shiny_cap": 0}
	var xp0 := treinador_xp
	var pxp0 := int(_lider()["xp"])
	if modo_time() and not _poke_id(lider_sessao).is_empty():
		pxp0 = int(_poke_id(lider_sessao)["xp"])
	var parado := 0
	var shiny_pos := {}   # casas de abates de shiny ainda sem catch-result
	var ult_pos := Vector2i(-999, -999)
	var n := int(minutos * TICKS_MIN)
	var rod := int(args["rodizio_min"]) * TICKS_MIN
	var viaveis: Array = _viaveis(slug) if modo_time() and not treino and aplicar else []
	for t in n:
		var intents: Array = []
		if viaveis.size() > 1 and t > 0 and t % rod == 0:
			# ciclo 6: o membro viável com menos XP (na sim, o XP atual) passa a liderar
			var melhor := -1
			var menor := -1
			for i in sim.equipe.size():
				if String(sim.equipe[i].get("id", "")) in viaveis and int(sim.equipe[i]["hp"]) > 0 and (menor < 0 or int(sim.equipe[i]["xp"]) < menor):
					menor = int(sim.equipe[i]["xp"])
					melhor = i
			if melhor >= 0 and melhor != sim.ativo:
				intents.append({"type": "switch", "teamIndex": melhor})
				extras["trocas_rodizio"] = int(extras.get("trocas_rodizio", 0)) + 1
		for reg in sim.passo(intents):
			var m: Dictionary = reg.get("msg", reg)
			match String(m.get("type", "")):
				"field-kill":
					r["abates"] += 1
					var ke := str(int(m.get("speciesId", -1)))
					r["por_especie"][ke] = int(r["por_especie"].get(ke, 0)) + 1
					if bool(m.get("shiny", false)):
						r["shiny"] += 1
						shiny_pos[Vector2i(int(m.get("col", -1)), int(m.get("row", -1)))] = true
					for it in m.get("loot", []):
						var k := str(int(it.get("itemId", 0)))
						r["loot"][k] = int(r["loot"].get(k, 0)) + int(it.get("qty", 0))
						if aplicar and String(dados.itens.get(int(k), {}).get("categoria", "")) == "stone":
							pedras_obtidas[k] = int(pedras_obtidas.get(k, 0)) + int(it.get("qty", 0))
				"catch-result":
					if bool(m.get("success", false)):
						r["capturas"] += 1
						r["capturas_especie"].append(int(nome_para_id.get(String(m.get("speciesName", "")), -1)))
						if aplicar and modo_time() and int(nome_para_id.get(String(m.get("speciesName", "")), -1)) > 0:
							n_capturados += 1
							est["pokes"].append({"id": "c%d" % n_capturados, "speciesId": int(nome_para_id[String(m["speciesName"])]), "xp": 0,
								"ivs": Regras.sortear_ivs(rng_box), "quality": Regras.sortear_qualidade(rng_box), "hp": -1,
								"shiny": shiny_pos.has(Vector2i(int(m.get("col", -2)), int(m.get("row", -2)))), "team": false, "slot": -1})
						# ciclo 4: o shiny é reconhecido pela casa do abate (antes, só se a bola do shiny fosse diferente da do
						# Auto-Catch — com só Poké Balls, uma captura de shiny nunca era contada)
						if shiny_pos.has(Vector2i(int(m.get("col", -2)), int(m.get("row", -2)))):
							r["shiny_cap"] += 1
					if m.has("col"):
						shiny_pos.erase(Vector2i(int(m.get("col", -2)), int(m.get("row", -2))))
				"auto-heal":
					r["pocoes"] += 1
				"field-none":
					r["morte"] = String(m.get("motivo", "")) == "sem-reserva"
				"field":
					var h: Dictionary = m["hero"]
					var pos := Vector2i(int(h["col"]), int(h["row"]))
					var vivo := false
					for mb in m["mobs"]:
						if not bool(mb["dead"]):
							vivo = true
							break
					if pos == ult_pos and not bool(m.get("fighting", false)) and vivo and m.get("targetSlot") != null and not bool(m.get("fainted", false)):
						parado += 2
					else:
						parado = 0
					ult_pos = pos
					r["travado_max_s"] = maxf(float(r["travado_max_s"]), parado * 0.2)
		r["ticks"] = t + 1
		if sim.encerrada:
			break
	r["xp"] = int(sim.treinador["xp"]) - xp0
	if aplicar and modo_time() and completo():
		prof_srv.registrar_hunt(est, r["por_especie"], int(sim.estatisticas.get("ervas", 0)), int(sim.estatisticas.get("fotos", 0)))
	r["pxp"] = int(sim.equipe[0]["xp"]) - pxp0
	if aplicar:
		treinador_xp = int(sim.treinador["xp"])
		if modo_time():
			if OS.get_environment("CAMPANHA_DEBUG") != "":
				for e in sim.equipe:
					print("DBG equipe ", e.get("id"), " sp=", e.get("speciesId"), " xp=", e.get("xp"), " hp=", e.get("hp"), " lider=", e.get("leader"))
			for e in sim.equipe:
				var pk := _poke_id(String(e.get("id", "")))
				if not pk.is_empty():
					pk["xp"] = int(e["xp"])
					pk["hp"] = int(e["hp"])
		else:
			var e: Dictionary = sim.equipe[0]
			_lider()["xp"] = int(e["xp"])
			_lider()["hp"] = int(e["hp"])
		for k in est["itens"].keys():
			if int(k) >= 200 and int(k) <= 204:
				est["itens"].erase(k)
		for k in sim.inventario:
			if int(sim.inventario[k]) > 0:
				est["itens"][str(int(k))] = int(sim.inventario[k])
		for k in sim.balls["counts"]:
			est["bolas"][str(k)] = int(sim.balls["counts"][k])
		medidor = sim.medidor.duplicate(true)
		if completo():
			_pos_hunt(r)
	return r


func _pos_hunt(r: Dictionary) -> void:
	## Streak, diárias e coleção com o resultado de um trecho aplicado.
	for k in r["por_especie"]:
		ServicoJogador.somar_abates(est, int(r["por_especie"][k]), int(k))
		diarias.tratar(est, {"type": "abate", "speciesId": int(k), "n": int(r["por_especie"][k])})
	for sid in r["capturas_especie"]:
		if sid < 0:
			continue
		colecao[sid] = true
		est["nivel"] = _nivel_treinador()
		for m in diarias.tratar(est, {"type": "captura", "speciesId": sid, "agora": agora_s}):
			if String(m.get("type", "")) == "daily-catch-claimed":
				treinador_xp += int(m["xp"])
				extras["catch_xp"] += int(m["xp"])
	extras["shiny_vistos"] += int(r["shiny"])
	extras["shiny_capturados"] += int(r["shiny_cap"])


func _cidade() -> Dictionary:
	## Nurse, venda, evolução, compras. Devolve {ouro_venda, evoluiu}.
	var out := {"ouro_venda": 0, "evoluiu": ""}
	cidade.tratar(est, {"type": "joy-heal"})
	var venda: Array = []
	for k in est["itens"]:
		if cidade.preco_venda(int(k)) > 0:
			venda.append({"itemId": int(k), "qty": int(est["itens"][k])})
	if not venda.is_empty():
		for m in cidade.tratar(est, {"type": "shop-sell", "items": venda}):
			if String(m.get("type", "")) == "shop-sold":
				out["ouro_venda"] = int(m["goldGained"])
	if modo_time():
		_montar_time()
		if completo():
			_usar_itens()
			if prof_srv.rank(est) == "":
				prof_srv.tratar(est, {"type": "prof-escolher", "prof": "botanist"})
			while int(est["profissao"].get("ervas", 0)) >= int(prof_srv.p.craft_ervas) and int(est["gold"]) >= 2 * int(prof_srv.p.craft_ouro):
				prof_srv.tratar(est, {"type": "prof-craft", "tipo": "ROCK"})
			var rk: Array = prof_srv.tratar(est, {"type": "prof-subir", "especies": colecao.size()})
			if String(rk[0]["type"]) == "prof-rank":
				marcos_vistos["prof_" + String(rk[0]["rank"])] = snappedf(minutos_jogados / 60.0, 0.01)
	for pk in (_time() if modo_time() else [_lider()]):
		var pid := String(pk.get("id", "lider"))
		var info: Dictionary = cidade.tratar(est, {"type": "evolve-info", "capturedId": pid})[0]
		if bool(info.get("canEvolve", false)) and bool(info.get("hasStones", false)) and info.get("destId") != null:
			for m in cidade.tratar(est, {"type": "evolve", "capturedId": pid, "useStone": true, "destId": info["destId"]}):
				if String(m.get("type", "")) == "evolved":
					out["evoluiu"] += ("" if out["evoluiu"] == "" else ", ") + String(m["name"])
	# poção: a menor que cura ≥ 35% do HP máximo, senão a maior
	var max_hp: int = cidade.max_hp(_lider())
	var escolha := 204
	for id in [200, 201, 202, 203, 204]:
		if float(dados.itens[id].get("cura", 0)) >= 0.35 * max_hp:
			escolha = id
			break
	var preco := int(dados.itens[escolha]["precoGold"])
	var falta := 150 - int(est["itens"].get(str(escolha), 0))
	var qtd := mini(falta, int(est["gold"]) / maxi(1, preco))
	if qtd > 0:
		cidade.tratar(est, {"type": "shop-buy", "itemId": escolha, "qty": qtd})
	var falta_b := 60 - int(est["bolas"].get("1", 0))
	var qb := mini(falta_b, (int(est["gold"]) - 0) / 5)
	if qb > 0:
		cidade.tratar(est, {"type": "shop-buy", "ballId": 1, "qty": qb})
	return out


func _pedras_faltando() -> Array:
	## itemIds das pedras que faltam quando o líder já tem o nível para evoluir (evolve-info, como a tela do jogo).
	var info: Dictionary = cidade.tratar(est, {"type": "evolve-info", "capturedId": String(_lider().get("id", "lider"))})[0]
	var falta: Array = []
	if bool(info.get("canEvolve", false)) and not bool(info.get("hasStones", false)):
		for st in info.get("stones", []):
			if int(st["have"]) < int(st["need"]):
				falta.append(int(st["itemId"]))
	return falta


func _chance_pedra(slug: String, pedras: Array) -> float:
	## Chance média por abate de cair uma das pedras, pela tabela de loot das espécies dos spawns (A: creatures.json).
	var sp: Array = dados.hunts[slug].get("spawns", [])
	if sp.is_empty():
		return 0.0
	var soma := 0.0
	for x in sp:
		for l in dados.especie(int(x.get("pokeId", 0))).get("loot", []):
			if int(l.get("itemId", -1)) in pedras:
				soma += float(l.get("chance", 0))
	return soma / sp.size()


func _liberadas() -> Array:
	var r: Array = []
	for s in Acesso.hunts_liberadas(hunts_lista, _nivel_treinador()):
		if bloqueadas.has(s) and _nivel_lider() < int(bloqueadas[s]) + 10:
			continue
		r.append(s)
	return r


func _candidatas_pedra(pedras: Array) -> Array:
	var c: Array = []
	for s in _liberadas():
		var ch := _chance_pedra(s, pedras)
		if ch > 0.0 and int(dados.hunts[s]["nivel"]) <= _nivel_lider() + 20:
			c.append([ch, s])
	c.sort_custom(func(a, b): return a[0] > b[0])
	var r: Array = []
	for x in c.slice(0, 5):
		r.append(x[1])
	return r


func _candidatas() -> Array:
	var lib := _liberadas()
	var teto := _nivel_lider() + (2 if treino else 20)   # treino: hunts do nível do membro mais fraco
	if treino:
		# treino: as hunts até o nível do membro + 2 com a melhor vantagem de tipo para ele (e as de nível mais alto)
		var fraco := _mais_fraco()
		var tc: Array = []
		for s in lib:
			if int(dados.hunts[s]["nivel"]) <= teto:
				tc.append([_vantagem(fraco, s), int(dados.hunts[s]["nivel"]), s])
		tc.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and (a[1] > b[1] or (a[1] == b[1] and a[2] < b[2]))))
		var r: Array = []
		for x in tc.slice(0, 5):
			r.append(x[2])
		return r
	var niveis := {}
	for s in lib:
		var nv := int(dados.hunts[s]["nivel"])
		if nv <= teto:
			niveis[nv] = true
	var lv: Array = niveis.keys()
	lv.sort()
	lv.reverse()
	lv = lv.slice(0, 3)
	var c: Array = []
	for s in lib:
		if int(dados.hunts[s]["nivel"]) in lv:
			c.append(s)
	c.sort()
	# até 5, espalhadas de forma determinística
	var escolhidas: Array = []
	if c.size() <= 5:
		escolhidas = c
	else:
		var passo := float(c.size()) / 5.0
		for i in 5:
			escolhidas.append(c[int(i * passo + semente_seq) % c.size()])
	if ultima_hunt != "" and ultima_hunt in lib and not ultima_hunt in escolhidas:
		escolhidas.append(ultima_hunt)
	return escolhidas


func _escolher() -> String:
	var melhor := ""
	var melhor_v := -1.0
	var pedras := _pedras_faltando()
	var cands := _candidatas()
	for s in _candidatas_pedra(pedras) if not pedras.is_empty() and not treino else []:
		if not s in cands:
			cands.append(s)
	# pontuação = XP/min ÷ melhor XP/min + (faltando pedra) pedras/min ÷ melhor pedras/min; desmaio na sonda derruba
	var notas := []
	var melhor_xp := 0.0001
	var melhor_pedra := 0.0000001
	var lider_de := {}
	for s in cands:
		if modo_time():
			lider_sessao = String((_mais_fraco() if treino else _melhor_membro(s)).get("id", ""))
			lider_de[s] = lider_sessao
		var r := _rodar(s, float(args["sonda_min"]), false, false)
		var mins := maxf(0.1, r["ticks"] / float(TICKS_MIN))
		var xp := float(r["xp"]) / mins
		var pd := float(r["abates"]) / mins * _chance_pedra(s, pedras) if not pedras.is_empty() else 0.0
		xp += _bonus_kill(r, mins)
		notas.append([s, xp, pd, r["morte"]])
		melhor_xp = maxf(melhor_xp, xp)
		melhor_pedra = maxf(melhor_pedra, pd)
	for n in notas:
		var v: float = n[1] / melhor_xp + (n[2] / melhor_pedra if not pedras.is_empty() else 0.0)
		if n[3]:
			v *= 0.01
		if v > melhor_v:
			melhor_v = v
			melhor = n[0]
	if modo_time() and melhor != "":
		lider_sessao = String(lider_de[melhor])
	return melhor


func _bonus_kill(r: Dictionary, mins: float) -> float:
	## XP/min marginal da Daily Kill escolhida: prêmio × (abates da espécie por min ÷ quantidade que falta).
	if not completo():
		return 0.0
	var k: Dictionary = est.get("diarias", {}).get("kill", {})
	if int(k.get("pickedIdx", -1)) < 0 or bool(k.get("claimed", false)):
		return 0.0
	var o: Dictionary = k["opcoes"][int(k["pickedIdx"])]
	var falta := maxi(1, int(o["qty"]) - int(k.get("have", 0)))
	var taxa := float(r["por_especie"].get(str(int(o["speciesId"])), 0)) / mins
	return float(diarias._kill_xp(o)) * minf(1.0, taxa / falta)


func _dia_novo() -> void:
	## Daily Gift e escolha da Daily Kill (a opção de mais XP cuja espécie está numa hunt liberada que o líder aguenta).
	est["nivel"] = _nivel_treinador()
	for m in diarias.tratar(est, {"type": "daily-claim", "agora": agora_s}):
		if String(m.get("type", "")) == "daily-gift" or m.has("claimed"):
			extras["gift"] += 1
		if String(m.get("type", "")) == "boosts":
			est["boosts"] = (m["boosts"] as Array).duplicate(true)
	_escolher_kill()
	if modo_time():
		_bosses_dia()


func _escolher_kill() -> void:
	## A opção de mais XP cuja espécie está numa hunt liberada que o líder aguenta. Ciclo 4: tentada a cada volta à
	## cidade, não só na virada do dia (antes, com o treinador abaixo do nível 25 na virada, o dia ficava sem Daily Kill
	## mesmo passando do 25 depois — por isso a campanha de 20 h tinha kills_diarios 0).
	est["nivel"] = _nivel_treinador()
	var mk: Dictionary = diarias.tratar(est, {"type": "daily-kill-get", "agora": agora_s})[0]
	if bool(mk.get("locked", true)) or int(mk.get("pickedIdx", -1)) >= 0:
		return
	var aguenta := {}
	var pl := Metas.poder_lider(dados, _lider())
	for slug in _liberadas():
		if Metas.poder_hunt(dados, slug) <= pl:
			for x in dados.hunts[slug].get("spawns", []):
				aguenta[int(x.get("pokeId", 0))] = true
	var melhor := -1
	var melhor_xp := -1
	for i in (mk["options"] as Array).size():
		var o: Dictionary = mk["options"][i]
		if aguenta.has(int(o["speciesId"])) and int(o["xp"]) > melhor_xp:
			melhor = i
			melhor_xp = int(o["xp"])
	if melhor >= 0:
		diarias.tratar(est, {"type": "daily-kill-pick", "idx": melhor, "agora": agora_s})


func _diarias_cidade() -> void:
	## Antes da venda: tarefas completas, Daily Kill completa, Streak.
	est["nivel"] = _nivel_treinador()
	_escolher_kill()
	var mt: Dictionary = diarias.tratar(est, {"type": "tasks-get", "agora": agora_s})[0]
	for t in mt["tasks"]:
		if bool(t["complete"]) and not bool(t["claimed"]):
			for m in diarias.tratar(est, {"type": "tasks-claim", "taskId": String(t["id"]), "agora": agora_s}):
				if String(m.get("type", "")) == "tasks-claimed":
					treinador_xp += int(m["xp"])
					extras["tarefas_xp"] += int(m["xp"])
					extras["tarefas_ouro"] += int(m["cash"])
					extras["tarefas"] += 1
	for m in diarias.tratar(est, {"type": "daily-kill-claim", "agora": agora_s}):
		if String(m.get("type", "")) == "daily-kill-claimed":
			treinador_xp += int(m["payout"]["xp"])
			extras["kill_xp"] += int(m["payout"]["xp"])
			extras["kills_diarios"] += 1
	while true:
		var ms: Dictionary = jogador.msg_streak(est)
		if int(ms["available"]) <= 0 or int(est["gold"]) < int(ms["nextCost"]) * 3 / 2:
			break
		extras["streak_ouro"] += int(ms["nextCost"])
		jogador.tratar(est, {"type": "streak-spend", "track": "exp"})
		extras["streak_pontos"] += 1


func _ginasios() -> void:
	## Ciclo 3: na cidade, desafia cada ginásio liberado sem insígnia ativa (o time é só o líder, a política da campanha).
	est["nivel"] = _nivel_treinador()
	var l: Dictionary = _lider()
	var time := [{"speciesId": int(l["speciesId"]), "xp": int(l["xp"]), "ivs": l["ivs"], "quality": float(l["quality"])}]
	if modo_time():
		time.clear()
		for pk in _time():
			time.append({"speciesId": int(pk["speciesId"]), "xp": int(pk["xp"]), "ivs": pk["ivs"], "quality": float(pk["quality"])})
	for g in gin.p.lista:
		var gid := String(g["id"])
		if _nivel_treinador() < int(g["nivel_treinador"]):
			continue
		if int(est.get("ginasios", {}).get("insignias", {}).get(gid, 0)) > agora_s * 1000:
			continue
		var m: Array = gin.tratar(est, {"type": "ginasio-desafiar", "gymId": gid, "agora": agora_s, "nivel": _nivel_treinador(), "time": time, "semente": agora_s + semente_seq})
		if String(m[0].get("type", "")) != "gym-result":
			continue
		if bool(m[0]["venceu"]):
			extras["ginasios_vitorias"] += 1
		else:
			extras["ginasios_derrotas"] += 1
	extras["insignias_max"] = maxi(int(extras["insignias_max"]), gin.ativas(est, agora_s))
	var chave := "insignias_%d" % gin.ativas(est, agora_s)
	if not marcos_vistos.has(chave):
		marcos_vistos[chave] = snappedf(minutos_jogados / 60.0, 0.01)


func _soneca() -> void:
	## Fim do dia ativo: Zzz na última hunt (amostra de 5 min, sem bolas) e coleta ao acordar (50%, A/C).
	var fora := int((24.0 - float(args["horas_dia"])) * 3600.0)
	if ultima_hunt != "" and fora > 300:
		var r := _rodar(ultima_hunt, 5.0, false, true, true)
		var e := {"soneca": {"inicio": agora_s, "fim": agora_s + 300, "amostra": {"xpSample": int(r["xp"]), "pokeXpSample": int(r["pxp"]),
			"kills": int(r["abates"]), "slug": ultima_hunt, "leaderId": "lider"}}}
		for m in jogador.tratar(e, {"type": "offline-claim", "agora": agora_s + fora, "boost": false}):
			if String(m.get("type", "")) == "offline-claimed":
				treinador_xp += int(m["xpGained"])
				_lider()["xp"] = int(_lider()["xp"]) + int(m["pokeXpGained"])
				extras["soneca_xp"] += int(m["xpGained"])
				extras["soneca_pxp"] += int(m["pokeXpGained"])
				extras["sonecas"] += 1
	agora_s += fora
	ativo_no_dia = 0.0


func _registrar_metas() -> Dictionary:
	var esp := colecao.keys()
	var mt := Metas.resumo(dados, hunts_lista, treinador_xp, _lider(), esp)
	var rec: Dictionary = mt["hunt"]
	var marco := int(mt["marco"]["anterior"])
	if not marcos_vistos.has("nivel_%d" % marco):
		marcos_vistos["nivel_%d" % marco] = snappedf(minutos_jogados / 60.0, 0.01)
	var cm := int(mt["colecao"]["especies"])
	for m in Metas.parametros().metas_marcos_colecao:
		if cm >= int(m) and not marcos_vistos.has("colecao_%d" % int(m)):
			marcos_vistos["colecao_%d" % int(m)] = snappedf(minutos_jogados / 60.0, 0.01)
	return {"rec": String(rec["atual"].get("slug", "")), "rec_xp_min": rec["atual"].get("xp_min", 0),
		"prox": String(rec["proxima"].get("slug", "")), "prox_lv": int(rec["proxima"].get("nivel_lider", -1)),
		"prox_salto": bool(rec["proxima"].get("salto", false)), "prox_ganho": int(rec["proxima"].get("ganho_pct", 0)),
		"marco": int(mt["marco"]["proximo"]), "colecao": cm, "regiao_cap": "%d/%d" % [int(mt["colecao"]["liberadas_capturadas"]), int(mt["colecao"]["liberadas_total"])]}


func _campanha() -> void:
	var horas_max := float(args["horas"])
	var sessao := 0
	while minutos_jogados < horas_max * 60.0 and _nivel_treinador() < int(args["nivel_alvo"]):
		if completo():
			var d: int = diarias.dia(agora_s)
			if d != dia_atual:
				dia_atual = d
				_dia_novo()
			_diarias_cidade()
			_ginasios()
		var c := _cidade()
		treino = modo_time() and sessao % 4 == 3 and _time().size() > 1
		var slug := _escolher()
		if slug == "":
			print("SEM HUNT liberada?!")
			break
		var nt0 := _nivel_treinador()
		var nl0 := _nivel_lider()
		var lider_txt := ""
		if modo_time():
			var lp := _poke_id(lider_sessao)
			lider_txt = "%s %d" % [String(dados.especie(int(lp["speciesId"]))["nome"]), _nivel(lp)]
		var r := _rodar(slug, float(args["sessao_min"]), slug != ultima_hunt, true)
		ultima_hunt = slug
		if r["morte"] and not treino:
			bloqueadas[slug] = nl0
		if String(dados.hunts[slug]["area"]).to_lower() == "orre":
			if float(orre["inicio_h"]) < 0.0:
				orre["inicio_h"] = snappedf(minutos_jogados / 60.0, 0.01)
			orre["min"] += r["ticks"] / float(TICKS_MIN)
			orre["xp"] += int(r["xp"])
			orre["mortes"] += 1 if r["morte"] else 0
			orre["sessoes"] += 1
			var oh: Dictionary = orre["por_hunt"].get(slug, {"min": 0.0, "xp": 0, "mortes": 0, "sessoes": 0, "nivel": int(dados.hunts[slug]["nivel"])})
			oh["min"] += r["ticks"] / float(TICKS_MIN)
			oh["xp"] += int(r["xp"])
			oh["mortes"] += 1 if r["morte"] else 0
			oh["sessoes"] += 1
			orre["por_hunt"][slug] = oh
		var mins: float = r["ticks"] / float(TICKS_MIN)
		minutos_jogados += mins
		var mt := {}
		if completo():
			agora_s += int(mins * 60.0)
			ativo_no_dia += mins
			mt = _registrar_metas()
			if ativo_no_dia >= float(args["horas_dia"]) * 60.0:
				_soneca()
		var ouro_loot := 0
		for k in r["loot"]:
			ouro_loot += cidade.preco_venda(int(k)) * int(r["loot"][k])
		var h: Dictionary = por_hunt.get(slug, {"slug": slug, "nivel": int(dados.hunts[slug]["nivel"]), "area": String(dados.hunts[slug]["area"]),
			"min": 0.0, "abates": 0, "mortes": 0, "xp": 0, "ouro": 0, "pocoes": 0, "capturas": 0, "sessoes": 0, "travado_max_s": 0.0,
			"lider_de": nl0, "lider_ate": nl0})
		h["min"] += mins
		h["abates"] += int(r["abates"])
		h["mortes"] += 1 if r["morte"] else 0
		h["xp"] += int(r["xp"])
		h["ouro"] += ouro_loot
		h["pocoes"] += int(r["pocoes"])
		h["capturas"] += int(r["capturas"])
		h["sessoes"] += 1
		h["travado_max_s"] = maxf(float(h["travado_max_s"]), float(r["travado_max_s"]))
		h["lider_ate"] = _nivel_lider()
		por_hunt[slug] = h
		sessao += 1
		var esp := String(dados.especie(int(_lider()["speciesId"]))["nome"])
		var linha := {"sessao": sessao, "h": snappedf(minutos_jogados / 60.0, 0.01), "slug": slug, "nivel_hunt": int(dados.hunts[slug]["nivel"]),
			"treinador": "%d→%d" % [nt0, _nivel_treinador()], "lider": "%s %d→%d" % [esp, nl0, _nivel_lider()], "abates": int(r["abates"]),
			"morte": r["morte"], "ouro": int(est["gold"]), "evoluiu": c["evoluiu"], "pedras_bag": _pedras_bag(), "venda": c["ouro_venda"], "travado_s": r["travado_max_s"]}
		if modo_time():
			linha["lider_sessao"] = lider_txt
			linha["treino"] = treino
			var tt: Array = []
			for pk in _time():
				tt.append("%s %d" % [String(dados.especie(int(pk["speciesId"]))["nome"]), _nivel(pk)])
			linha["time"] = tt
			linha["box"] = (est["pokes"] as Array).size() - _time().size()
		if completo():
			linha["dias"] = snappedf(float(agora_s - int(Time.get_unix_time_from_datetime_string("2026-11-19T03:00:00"))) / 86400.0, 0.01)
			linha["metas"] = mt
			linha["streak"] = jogador.efeitos_streak(est)["exp"]
			linha["insignias"] = gin.ativas(est, agora_s)
		linha_tempo.append(linha)
		print("SESSAO ", JSON.stringify(linha))


func _pedras_bag() -> Dictionary:
	var r := {}
	for k in est["itens"]:
		if String(dados.itens.get(int(k), {}).get("categoria", "")) == "stone":
			r[String(dados.itens[int(k)]["nome"])] = int(est["itens"][k])
	return r


func _relatorio() -> void:
	var lista: Array = por_hunt.values()
	lista.sort_custom(func(a, b): return int(a["nivel"]) < int(b["nivel"]) or (int(a["nivel"]) == int(b["nivel"]) and String(a["slug"]) < String(b["slug"])))
	var problemas: Array = []
	for h in lista:
		var m := maxf(0.01, float(h["min"]))
		h["abates_min"] = snappedf(h["abates"] / m, 0.01)
		h["xp_h"] = int(h["xp"] / m * 60.0)
		h["ouro_h"] = int(h["ouro"] / m * 60.0)
		h["pocoes_h"] = snappedf(h["pocoes"] / m * 60.0, 0.1)
		if int(h["abates"]) == 0 or int(h["mortes"]) >= 3 or float(h["travado_max_s"]) >= 60.0:
			problemas.append(h["slug"])
	var saida := {"args": args, "minutos_jogados": minutos_jogados, "treinador_final": _nivel_treinador(), "lider_final": _nivel_lider(),
		"especie_final": String(dados.especie(int(_lider()["speciesId"]))["nome"]), "ouro_final": int(est["gold"]),
		"por_hunt": lista, "linha_tempo": linha_tempo, "pedras_obtidas": pedras_obtidas, "problemas": problemas, "segundos_reais": (Time.get_ticks_msec() - t0) / 1000.0,
		"extras": extras, "marcos": marcos_vistos, "colecao": colecao.size(), "orre": orre,
		"time_final": _time().map(func(pk): return {"id": String(pk["id"]), "nome": String(dados.especie(int(pk["speciesId"]))["nome"]), "xp": int(pk["xp"]),
			"nivel": _nivel(pk), "ivs": pk["ivs"], "quality": float(pk["quality"])}),
		"itens_uso": est.get("itens_uso", {})}
	var f := FileAccess.open(String(args["saida"]), FileAccess.WRITE)
	f.store_string(JSON.stringify(saida, "  "))
	f.close()
	print("FIM %.1f h jogadas, treinador %d, líder %s %d, ouro %d, %d hunts, problemas %s, %.0f s reais" % [minutos_jogados / 60.0,
		_nivel_treinador(), saida["especie_final"], _nivel_lider(), int(est["gold"]), lista.size(), str(problemas), saida["segundos_reais"]])
