extends SceneTree
var falhas: int=0
var checks: int=0
func checar(ok: bool, texto: String) -> void:
 checks+=1
 if not ok: falhas+=1;push_error(texto)
func _initialize() -> void:
 var agenda: RefCounted=preload("res://agenda_golpes.gd").new()
 agenda.golpes.assign([{"name":"A","cooldownMs":10000},{"name":"B","cooldownMs":5000},{"name":"C","cooldownMs":1000}])
 var dano: Dictionary={"A":5,"B":20,"C":0}
 var avaliar: Callable=func(g: Dictionary) -> float: return dano[g["name"]]
 checar(agenda.retirar_pronto(false,1.5,avaliar).get("name")=="B","Maior dano")
 checar(agenda.retirar_pronto(false,1.5,avaliar).is_empty(),"Sem ataque duplicado")
 agenda.avancar(1.5)
 checar(agenda.retirar_pronto(false,1.5,avaliar).get("name")=="B","Repete melhor golpe em vez de alternar")
 dano["A"]=30;agenda.avancar(1.5)
 checar(agenda.retirar_pronto(false,1.5,avaliar).get("name")=="A","Reavalia defensor")
 agenda=preload("res://agenda_golpes.gd").new()
 agenda.golpes.assign([{"name":"A","cooldownMs":10000},{"name":"B","cooldownMs":5000}])
 checar(agenda.retirar_pronto(true,1,avaliar).get("name")=="A","Melhor disponível com cooldown")
 agenda.avancar(1)
 checar(agenda.retirar_pronto(true,1,avaliar).get("name")=="B","Alternativa quando melhor indisponível")
 agenda.avancar(1)
 checar(agenda.retirar_pronto(true,1,avaliar).is_empty(),"Aguarda ambos cooldowns")
 agenda.avancar(20);dano["A"]=0;dano["B"]=0
 checar(agenda.retirar_pronto(true,1,avaliar).is_empty(),"Não escolhe golpe sem dano")
 # Fórmula real do protótipo: defesa e tipo podem vencer o maior power.
 var a: DadosPokemon=DadosPokemon.new();a.especie=load("res://dados/especies/larvitar.tres");a.nivel=30
 var d: DadosPokemon=DadosPokemon.new();d.especie=load("res://dados/especies/geodude.tres");d.nivel=30
 var normal: Dictionary={"name":"Normal","type":"NORMAL","category":"PHYSICAL","power":80,"cooldownMs":1000}
 var planta: Dictionary={"name":"Planta","type":"GRASS","category":"SPECIAL","power":40,"cooldownMs":1000}
 var dano_real: Callable=func(g: Dictionary) -> float: return preload("res://regras_dano.gd").calcular(a,d,g,true)
 agenda=preload("res://agenda_golpes.gd").new();agenda.golpes.assign([normal,planta])
 checar(agenda.retirar_pronto(false,1.5,dano_real).get("name")=="Planta","Efetividade e atributos acima do power isolado")
 print("MELHOR GOLPE: %d verificações; %d falhas" % [checks,falhas])
 quit(1 if falhas else 0)
