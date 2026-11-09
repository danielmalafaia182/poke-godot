extends SceneTree
const DANO=preload("res://regras_dano.gd")
const GOLPES=preload("res://catalogo_golpes.gd")
var checks: int=0
var falhas: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool,texto: String) -> void:
 checks+=1
 if not ok: falhas+=1;push_error(texto)
func individuo(nome: String,nivel: int) -> DadosPokemon:
 var p: DadosPokemon=DadosPokemon.new()
 p.especie=preload("res://especies_importadas.gd").obter_especies()[nome]
 p.nivel=nivel;p.qualidade=1.0
 for campo in ["iv_hp","iv_atk","iv_def","iv_sp_atk","iv_sp_def","iv_spd"]:p.set(campo,16)
 p.normalizar_atributos()
 return p
func melhor(a: DadosPokemon,d: DadosPokemon,selvagem: bool) -> int:
 var dano: int=0
 for g in GOLPES.listar(a.especie.nome,a.nivel,true):
  if selvagem and g.has("tm"):continue
  dano=maxi(dano,DANO.calcular(a,d,g,selvagem))
 return dano
func executar() -> void:
 var mapa: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/referencias/mapa_kanto.json"))
 var aliado: DadosPokemon=individuo("Larvitar",8)
 var altos: int=0
 for registro in mapa["hunts"]:
  var c: Dictionary=preload("res://catalogo_hunts.gd").obter(registro["name"])
  if c.is_empty():continue
  checar(int(c["nivel"])==maxi(1,int(registro["level"])),"Proxy aplicado "+str(registro["name"]))
  if int(c["nivel"])!=80:continue
  altos+=1
  var selvagem: DadosPokemon=individuo(registro["name"],80)
  var hp_a: int=aliado.obter_vida_maxima()
  var hp_s: int=selvagem.obter_vida_maxima()*5
  var ataque_a: int=melhor(aliado,selvagem,false)
  var ataque_s: int=melhor(selvagem,aliado,true)
  var turnos: int=0
  while hp_a>0 and hp_s>0 and turnos<1000:
   turnos+=1;hp_s-=ataque_a
   if hp_s>0:hp_a-=ataque_s
  checar(hp_a<=0 and hp_s>0,"Larvitar Lv8 perde 1x1 contra "+str(registro["name"]))
  print("BALANCO ",registro["name"]," Lv80: HP=",selvagem.obter_vida_maxima()*5,"; dano causado=",ataque_a,"; recebido=",ataque_s,"; rodadas=",turnos)
 checar(altos>0,"Há hunts Lv80 no teste")
 var baixo: DadosPokemon=individuo("Geodude",1)
 checar(melhor(aliado,baixo,false)>0 and aliado.obter_vida_maxima()>baixo.obter_vida_maxima(),"Aliado Lv8 mantém vantagem de atributos sobre Geodude Lv1")
 # Integração: o nível realmente chega ao encontro, não fica só no JSON.
 var estado: Node=root.get_node("EstadoJogo")
 estado.especie_caca=preload("res://especies_importadas.gd").obter_especies()["Dragonite"]
 estado.curar_time()
 var caca: Node=load("res://Caca.tscn").instantiate();root.add_child(caca)
 caca.set_process(false);caca.set_physics_process(false)
 await process_frame
 checar(caca.selvagens[0].pokemon.nivel==int(preload("res://catalogo_hunts.gd").obter("Dragonite")["nivel"]),"Spawn usa nível configurado")
 checar(caca._prever_dano_selvagem({"name":"TM teste","tm":"FIRE","power":600,"type":"FIRE","category":"SPECIAL"},caca.selvagens[0])==0,"TM não é presumida aprendida pelo selvagem")
 var capturavel: DadosPokemon=caca.selvagens[0].pokemon
 var nivel: int=capturavel.nivel
 checar(estado.registrar_captura(capturavel) and capturavel.nivel==nivel,"Captura preserva nível e atributos")
 print("DIFICULDADE HUNTS: %d verificações; %d falhas" % [checks,falhas])
 quit(1 if falhas else 0)
