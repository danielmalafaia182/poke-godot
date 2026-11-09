extends SceneTree
# Diagnóstico em processo isolado. Nunca chamar durante uma partida: seed() é global.
const C=preload("res://regras_dano_candidato.gd")
const V=preload("res://regras_vida_selvagem.gd")
const A=preload("res://agenda_golpes.gd")
const N: int=2048
var checks: int=0
var falhas: int=0
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func resumo(valores: Array) -> Dictionary:
	var a: Array=valores.duplicate();a.sort();var total: float=0
	for n in a:total+=float(n)
	return {"n":a.size(),"minimo":a.front(),"p10":a[maxi(0,ceili(a.size()*0.1)-1)],"p50":a[maxi(0,ceili(a.size()*0.5)-1)],"p90":a[maxi(0,ceili(a.size()*0.9)-1)],"maximo":a.back(),"media":total/a.size()}
func executar() -> void:
	var especies: Dictionary=preload("res://especies_importadas.gd").obter_especies()
	var gya: DadosPokemon=DadosPokemon.new();gya.especie=especies["Gyarados"];gya.nivel=214;gya.qualidade=1.8
	gya.iv_hp=23;gya.iv_atk=32;gya.iv_def=23;gya.iv_sp_atk=24;gya.iv_sp_def=23;gya.iv_spd=29
	var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=20261109
	seed(20261108)
	var hps: Array=[];var causados: Array=[];var recebidos: Array=[];var recebidos_anteriores: Array=[];var golpes_ko: Array=[];var duracoes: Array=[];var qualidades: Array=[]
	for i in range(N):
		var mob: DadosPokemon=DadosPokemon.new();mob.especie=especies["Blastoise"];mob.nivel=80
		# Mesma ordem/métodos da criação real: nenhum IV/qualidade é escolhido para encaixar.
		mob.sortear_ivs();mob.sortear_qualidade()
		var hp: int=V.calcular(mob);hps.append(hp);qualidades.append(mob.qualidade)
		var vida_gya: int=6324;var ataques: int=0;var tempo: float=0
		var aa: RefCounted=A.new();aa.configurar("Gyarados",214)
		var am: RefCounted=A.new();am.configurar("Blastoise",80)
		# Contato frio emt=0: candidata reserva um intervalo próprio antes do1º golpe.
		am.proximo_ataque_rapido=2.0
		var prever_aliado: Callable=func(g: Dictionary) -> float:return C.nominal(gya,mob,g)
		var prever_mob: Callable=func(g: Dictionary) -> float:return C.nominal(mob,gya,g,true,150)
		while hp>0 and vida_gya>0 and tempo<60:
			var ga: Dictionary=aa.retirar_calibrado(1.5,prever_aliado)
			if not ga.is_empty():
				var r: Dictionary=C.resolver(gya,mob,ga,false,rng)
				causados.append(r["dano"]);hp=maxi(0,hp-int(r["dano"]));ataques+=1
			if hp<=0:break
			var gm: Dictionary=am.retirar_calibrado(2.0,prever_mob)
			if not gm.is_empty():
				var r: Dictionary=C.resolver(mob,gya,gm,true,rng,150)
				recebidos.append(r["dano"]);recebidos_anteriores.append(r["dano_v3_nivel_pokemon_mesma_variacao"])
				vida_gya=maxi(0,vida_gya-int(r["dano"]))
			aa.avancar_calibrado(0.2);am.avancar_calibrado(0.2);tempo+=0.2
		check(hp==0 and vida_gya>0 and ataques>0,"1x1 de referência conclui em até60s")
		golpes_ko.append(ataques);duracoes.append(roundi(tempo*1000))
	var resultado: Dictionary={"schema":1,"n_individuos":N,"seed_geracao":"20261108","seed_dano":"20261109",
		"hp_maximo":resumo(hps),"dano_causado":resumo(causados),"dano_recebido":resumo(recebidos),"dano_recebido_politica_anterior_mesmo_sorteio":resumo(recebidos_anteriores),
		"golpes_ate_ko":resumo(golpes_ko),"duracao_ideal_ms":resumo(duracoes),"qualidade":resumo(qualidades),"fidelidade_comprovada":false,
		"limites":["Novos indivíduos independentes; não conta respawns estáveis como perfis novos.","Contato imediato, aliado com primeira ação imediata, selvagem com preparo inicial de2s e sem deslocamento.","Relógio local de200ms, aliado1,6s efetivos, selvagem2s; não é medição de cadência original.","Duração de um duelo local novo, sem cooldown carregado de alvo anterior, sem auto-potion ou aliados adicionais.","Estatísticas por golpe dão mais peso aos indivíduos que sobrevivem mais tempo.","Não é validação independente: a candidata foi escolhida com parte destes dados originais."]}
	print("AUDITORIA_GERACAO_JSON: ",JSON.stringify(resultado))
	print("AUDITORIA GERACAO: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
