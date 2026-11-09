extends RefCounted

# Evolução: relógio de simulação e cooldowns independentes por combatente.
# A prioridade por ordem do catálogo e o primeiro uso imediato são regras locais.
const CATALOGO: Script = preload("res://catalogo_golpes.gd")
var tempo: float = 0.0
# Alteração: rotação local no modo rápido, evitando repetir sempre o primeiro golpe.
var indice_rapido: int = 0
# Alteração: cadência pertence ao combatente, preservada ao trocar de alvo.
var proximo_ataque_rapido: float = 0.0
var proximo_ataque_catalogado: float=0.0
var golpes: Array[Dictionary] = []
var proximos_usos: Dictionary[String,float] = {}
var especie: String = ""
var nivel: int = -1
var ultimo_diagnostico: Dictionary = {}

func configurar(nome: String, novo_nivel: int) -> void:
	if especie == nome and nivel == novo_nivel:
		return
	especie = nome
	nivel = novo_nivel
	golpes = CATALOGO.listar(nome,novo_nivel,true)

func avancar(delta: float) -> void:
	if is_finite(delta) and delta > 0.0:
		tempo += delta

func retirar_pronto(aplicar_cooldown: bool = true, intervalo: float = 0.0, avaliar_dano: Callable = Callable()) -> Dictionary:
	if avaliar_dano.is_valid():
		return _retirar_maior_dano(aplicar_cooldown,intervalo,avaliar_dano)
	if not aplicar_cooldown:
		if golpes.is_empty() or tempo+0.000001 < proximo_ataque_rapido:
			return {}
		var golpe: Dictionary = golpes[indice_rapido % golpes.size()]
		indice_rapido += 1
		# Alteração: reserva antes de emitir efeitos; não acumula ataques atrasados.
		proximo_ataque_rapido = tempo+maxf(0.0,intervalo)
		return golpe.duplicate(true)
	if intervalo>0 and tempo+0.000001<proximo_ataque_catalogado: return {}
	for golpe in golpes:
		var nome: String = str(golpe["name"])
		if tempo+0.000001 < float(proximos_usos.get(nome,0.0)):
			continue
		# Cooldown passa a contar no momento da execução, não na animação.
		proximos_usos[nome] = tempo+maxf(0.001,float(golpe["cooldownMs"])/1000.0)
		if intervalo>0: proximo_ataque_catalogado=tempo+intervalo
		return golpe.duplicate(true)
	return {}

func resumo(aplicar_cooldown: bool = true) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for golpe in golpes:
		resultado.append({"nome":str(golpe["name"]),"tipo":str(golpe["type"]),
			"restante":maxf(0.0,float(proximos_usos.get(str(golpe["name"]),0.0))-tempo) if aplicar_cooldown else 0.0,
			"cooldown":float(golpe["cooldownMs"])/1000.0})
	return resultado

# Escolha determinística contra o defensor atual. Empates mantêm a ordem do catálogo.
func _retirar_maior_dano(aplicar_cooldown: bool, intervalo: float, avaliar: Callable) -> Dictionary:
	var prazo: float=proximo_ataque_catalogado if aplicar_cooldown else proximo_ataque_rapido
	if tempo+0.000001<prazo: return {}
	var melhor: Dictionary={}
	var maior: float=0.0
	for golpe in golpes:
		if aplicar_cooldown and tempo+0.000001<float(proximos_usos.get(str(golpe["name"]),0.0)): continue
		var dano: float=float(avaliar.call(golpe))
		if is_finite(dano) and dano>maior:
			maior=dano
			melhor=golpe
	if melhor.is_empty(): return {}
	if aplicar_cooldown:
		proximos_usos[str(melhor["name"])]=tempo+residuo_tick+maxf(0.001,float(melhor["cooldownMs"])/1000.0)
		proximo_ataque_catalogado=tempo+maxf(0.0,intervalo)
	else:
		proximo_ataque_rapido=tempo+maxf(0.0,intervalo)
	return melhor.duplicate(true)

# Perfil experimental: quantiza só o relógio de combate, nunca movimento/animações.
var residuo_tick: float=0.0
func avancar_calibrado(delta: float) -> void:
	if not is_finite(delta) or delta<=0.0: return
	residuo_tick+=delta
	var passos: int=floori((residuo_tick+0.000001)/0.2)
	if passos>0:
		tempo+=passos*0.2
		residuo_tick=maxf(0.0,residuo_tick-passos*0.2)

# Ataque automático e habilidade compartilham a reserva do combatente.
# O catálogo não comprova que uma TM foi aprendida; status não causa dano aqui.
func retirar_calibrado(intervalo: float, avaliar: Callable, habilidade: bool=false, efetividade: Callable=Callable()) -> Dictionary:
	# Mantém o caminho barato entre ataques; a revisão da hunt consulta a
	# viabilidade separadamente. Não recalcula todos os danos a cada frame.
	if avaliar.is_valid() and is_finite(tempo) and is_finite(proximo_ataque_rapido) and tempo+0.000001<proximo_ataque_rapido:
		ultimo_diagnostico={"estado":"aguardando_cooldown", "motivo":"cooldown", "golpe":{}, "dano_previsto":0.0, "proxima_liberacao":proximo_ataque_rapido, "detalhes":[]}
		return {}
	ultimo_diagnostico = diagnosticar_calibrado(avaliar, habilidade, efetividade)
	if ultimo_diagnostico["estado"] != "pronto": return {}
	var melhor: Dictionary = ultimo_diagnostico["golpe"]
	proximo_ataque_rapido=tempo+residuo_tick+maxf(0.05,intervalo)
	proximo_ataque_catalogado=proximo_ataque_rapido
	if habilidade:
		proximos_usos[str(melhor["name"])]=tempo+residuo_tick+maxf(0.001,float(melhor["cooldownMs"])/1000.0)
	var resultado: Dictionary=melhor.duplicate(true)
	resultado["via_combate"]="habilidade_catalogada" if habilidade else "ataque_automatico"
	resultado["cooldown_aplicado_ms"]=int(melhor["cooldownMs"]) if habilidade else 0
	return resultado

# P04: consulta sem executar, reservar cooldown, consumir RNG ou trocar alvo.
# Distingue impossibilidade ofensiva de uma liberação futura conhecida.
func diagnosticar_calibrado(avaliar: Callable, habilidade: bool=false, efetividade: Callable=Callable()) -> Dictionary:
	var resultado: Dictionary = {"estado":"bloqueado", "motivo":"sem_dano_positivo",
		"golpe":{}, "dano_previsto":0.0, "proxima_liberacao":-1.0, "detalhes":[]}
	if not avaliar.is_valid():
		resultado["motivo"]="avaliador_indisponivel"
		return resultado
	if not is_finite(tempo) or not is_finite(proximo_ataque_rapido):
		resultado["motivo"]="dados_invalidos"
		return resultado
	if golpes.is_empty():
		resultado["motivo"]="sem_golpe_catalogado" if CATALOGO.obter(especie).get("attacks",[]).is_empty() else "sem_golpe_no_nivel"
		return resultado
	var total_status: int=0
	var indisponiveis: int=0
	var ofensivos: int=0
	var imunes: int=0
	var invalidos: int=0
	var positivos: int=0
	var liberacao: float=INF
	var maior: float=0.0
	var melhor: Dictionary={}
	for golpe in golpes:
		var motivo: String=""
		var dano: float=0.0
		var prazo: float=proximo_ataque_rapido
		if golpe.has("tm") or not bool(golpe.get("disponivel",true)) or (nivel>=1 and int(golpe.get("learnLevel",1))>nivel):
			indisponiveis+=1; motivo="habilidade_indisponivel"
		elif str(golpe.get("category","STATUS")).to_upper()=="STATUS":
			total_status+=1; motivo="status_nao_implementado"
		elif str(golpe.get("category","")).to_upper() not in ["PHYSICAL","SPECIAL"] or int(golpe.get("power",0))<=0:
			invalidos+=1; motivo="golpe_nao_suportado"
		else:
			ofensivos+=1
			var fator: float=float(efetividade.call(golpe)) if efetividade.is_valid() else 1.0
			if not is_finite(fator) or fator<0.0:
				invalidos+=1; motivo="efetividade_invalida"
			elif fator==0.0:
				imunes+=1; motivo="imune"
			else:
				dano=float(avaliar.call(golpe))
				if not is_finite(dano) or dano<0.0:
					invalidos+=1; motivo="dano_invalido"
				elif dano==0.0:
					motivo="sem_dano_positivo"
				else:
					if habilidade: prazo=maxf(prazo,float(proximos_usos.get(str(golpe.get("name","")),0.0)))
					if not is_finite(prazo):
						invalidos+=1; motivo="cooldown_invalido"
					else:
						positivos+=1
						liberacao=minf(liberacao,prazo)
						motivo="cooldown" if tempo+0.000001<prazo else "pronto"
						if motivo=="pronto" and dano>maior:
							maior=dano; melhor=golpe
		resultado["detalhes"].append({"nome":str(golpe.get("name","?")), "motivo":motivo, "dano_previsto":dano, "liberacao":prazo})
	if not melhor.is_empty():
		resultado.merge({"estado":"pronto", "motivo":"", "golpe":melhor.duplicate(true), "dano_previsto":maior, "proxima_liberacao":tempo},true)
	elif positivos>0 and is_finite(liberacao):
		resultado.merge({"estado":"aguardando_cooldown", "motivo":"cooldown", "proxima_liberacao":liberacao},true)
	elif invalidos>0:
		resultado["motivo"]="dados_invalidos"
	elif ofensivos>0 and imunes==ofensivos:
		resultado["motivo"]="todos_imunes"
	elif ofensivos>0:
		resultado["motivo"]="sem_dano_positivo"
	elif total_status>0:
		resultado["motivo"]="somente_status"
	elif indisponiveis>0:
		resultado["motivo"]="habilidades_indisponiveis"
	return resultado
