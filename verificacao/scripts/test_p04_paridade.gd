extends SceneTree
const NOVA=preload("res://agenda_golpes.gd")
const ANTERIOR=preload("res://verificacao/scripts/test_suporte_agenda_p03.gd")
const DANO=preload("res://regras_dano_candidato.gd")
const TIPOS=preload("res://regras_dano.gd")
var checks: int=0
var falhas: int=0
func _initialize() -> void: call_deferred("executar")
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: falhas+=1;push_error(msg)
func executar() -> void:
	var especies: Dictionary=preload("res://especies_importadas.gd").obter_especies()
	var cenarios: int=0
	for nome in ["Bulbasaur","Geodude","Gastly","Rattata","Gyarados","Blastoise","Togepi","Abra"]:
		for nivel in [1,16,37,80]:
			var atacante: DadosPokemon=DadosPokemon.new();atacante.especie=especies[nome];atacante.nivel=nivel
			for defesa in ["Rattata","Gastly","Geodude","Blastoise"]:
				var defensor: DadosPokemon=DadosPokemon.new();defensor.especie=especies[defesa];defensor.nivel=80
				var avaliar: Callable=func(g: Dictionary)->float:return DANO.nominal(atacante,defensor,g)
				var efetividade: Callable=func(g: Dictionary)->float:return TIPOS.efetividade(g,defensor)
				for habilidades in [false,true]:
					cenarios+=1
					var antiga: RefCounted=ANTERIOR.new();var nova: RefCounted=NOVA.new()
					antiga.configurar(nome,nivel);nova.configurar(nome,nivel)
					for passo in range(30):
						antiga.avancar_calibrado(0.2);nova.avancar_calibrado(0.2)
						var esperado: Dictionary=antiga.retirar_calibrado(1.5,avaliar,habilidades)
						var obtido: Dictionary=nova.retirar_calibrado(1.5,avaliar,habilidades,efetividade)
						check(esperado==obtido,"mesmo golpe e metadados %s lv%d x %s habilidade=%s tick%d" % [nome,nivel,defesa,habilidades,passo])
						check(antiga.proximo_ataque_rapido==nova.proximo_ataque_rapido and antiga.proximo_ataque_catalogado==nova.proximo_ataque_catalogado,"mesma reserva da agenda")
						check(antiga.proximos_usos==nova.proximos_usos,"mesmos cooldowns individuais")
	# O caminho rápido de cooldown não precisa avaliar todos os danos novamente.
	var chamadas: Array[int]=[0]
	var custo: Callable=func(_g: Dictionary)->float:chamadas[0]+=1;return 1.0
	var ag: RefCounted=NOVA.new();ag.configurar("Gyarados",100);ag.proximo_ataque_rapido=100.0
	for i in range(100): check(ag.retirar_calibrado(1.5,custo).is_empty(),"cooldown sem ataque extra")
	check(chamadas[0]==0,"cooldown mantém retorno barato sem avaliar dano por frame")
	print("P04 PARIDADE: %d configurações x 30 ticks; %d verificações; %d falhas" % [cenarios,checks,falhas])
	quit(1 if falhas else 0)
