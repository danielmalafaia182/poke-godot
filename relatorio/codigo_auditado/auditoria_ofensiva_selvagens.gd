extends RefCounted
# Refuta limites da combinação de regras, sem atribuir slot=-1 a um inimigo.
const C=preload("res://regras_dano_candidato.gd")
const CAT=preload("res://catalogo_golpes.gd")
static func carregar() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/amostra_ofensiva_selvagens.json"))
static func individuo(nivel: int,iv: int,q: float) -> DadosPokemon:
	var p: DadosPokemon=DadosPokemon.new()
	p.especie=preload("res://especies_importadas.gd").obter_especies()["Blastoise"]
	p.nivel=nivel;p.qualidade=q
	for campo in ["iv_hp","iv_atk","iv_def","iv_sp_atk","iv_sp_def","iv_spd"]:p.set(campo,iv)
	return p
static func analisar(nivel: int,amostra: Dictionary) -> Dictionary:
	if nivel<1 or nivel>100000:return {"erro":"Nível fora de1–100000."}
	var minimo: DadosPokemon=individuo(nivel,1,0.8)
	var maximo: DadosPokemon=individuo(nivel,32,1.8)
	var grupos: Dictionary={};var excluidos: int=0
	for h in amostra["recebidos"]:
		if h["pacote_de_transicao"]:excluidos+=1;continue
		var pid: String=h["perfil_id"]
		var chave: String=pid+"|"+str(h["golpe"])+"|"+str(h["efetividade"])
		if not grupos.has(chave):
			var golpe: Dictionary={}
			for g in CAT.listar("Blastoise",nivel):
				if g["name"]==h["golpe"]:golpe=g;break
			if golpe.is_empty():return {"erro":"Golpe ausente do catálogo: "+str(h["golpe"])}
			var perfil: Dictionary=amostra["perfis"][pid]
			var inferior: Dictionary=C.detalhar_atributos(nivel,minimo.obter_atributos(),perfil["atributos"],C.tipos(minimo),golpe,h["efetividade"],0.85,true)
			var superior: Dictionary=C.detalhar_atributos(nivel,maximo.obter_atributos(),perfil["atributos"],C.tipos(maximo),golpe,h["efetividade"],1.0,true)
			grupos[chave]={"aliado":perfil["especie"],"nivel_aliado":perfil["nivel"],"perfil_id":pid,
				"golpe":h["golpe"],"efetividade":h["efetividade"],"catalogo_disponivel":int(golpe["learnLevel"])<=nivel,
				"atributo_ofensivo_minimo":inferior["ataque_usado"],"atributo_ofensivo_maximo":superior["ataque_usado"],
				"limites_dano":[inferior["dano"],superior["dano"]],"observados":[],"fora_limites":[]}
		var grupo: Dictionary=grupos[chave]
		grupo["observados"].append(h["dano"])
		if h["dano"]<grupo["limites_dano"][0] or h["dano"]>grupo["limites_dano"][1] or not grupo["catalogo_disponivel"]:grupo["fora_limites"].append(h["dano"])
	var total: int=0;var fora: int=0
	for grupo in grupos.values():total+=grupo["observados"].size();fora+=grupo["fora_limites"].size()
	return {"schema":1,"nivel_combate_local_testado":nivel,"fonte":amostra["fonte"],
		"grupos":grupos.values(),"eventos":total,"excluidos_transicao":excluidos,"fora_limites":fora,
		"gerador_refutado_nestas_premissas":fora>0,"fidelidade_comprovada":false,
		"premissas":["Curva candidata V3, sem bônus ofensivo exclusivo dos selvagens.","Nível fixo testado, IVs1–32, qualidades locais entre0,8 e1,8.","Variação85–100%, efetividade observada, atributos do aliado de pokes.list."],
		"limites":["Envelope entre extremos; estar dentro não comprova perfil individual alcançável.","Cada golpe pode vir de um selvagem diferente; não os ajustamos ao mesmo indivíduo.","Não valida correlação entre HP/Def/Atk ou a política de escolha dos golpes.","Uma contradição refuta a combinação de premissas; não revela qual delas está errada.","Somente Blastoise nesta amostra. Nível da hunt não comprova nível de combate."]}
static func varrer(amostra: Dictionary,maximo: int=200) -> Dictionary:
	var niveis: Array[int]=[]
	var conjuntos: Array[int]=[]
	var hp_dados: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/hp_selvagens_observados.json"))
	var menor_hp_observado: int=2147483647
	for caso in hp_dados["casos"]:menor_hp_observado=mini(menor_hp_observado,int(caso["hp_maximo"]))
	for nivel in range(1,maximo+1):
		if analisar(nivel,amostra)["fora_limites"]==0:
			niveis.append(nivel)
			if preload("res://regras_vida_selvagem.gd").calcular(individuo(nivel,1,0.8))<=menor_hp_observado:conjuntos.append(nivel)
	return {"limite_busca":maximo,"niveis_nao_refutados_pelos_envelopes":niveis,
		"niveis_nao_refutados_dano_e_hp_minimo":conjuntos,"menor_hp_maximo_observado":menor_hp_observado,
		"nivel_original_identificado":false,"aviso":"Interseção de condições necessárias sob as premissas candidatas. Não valida um perfil conjunto de HP/Atk/Def nem identifica nível real."}
