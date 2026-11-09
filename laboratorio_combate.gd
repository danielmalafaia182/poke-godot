extends Control
# Cena de diagnóstico independente. Fixtures sintéticas; não escreve no EstadoJogo.
const DANO=preload("res://regras_dano.gd")
var resultado: Dictionary={}
var texto: RichTextLabel
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var fundo: ColorRect=ColorRect.new();fundo.color=Color("0b1620");fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(fundo)
 var margem: MarginContainer=MarginContainer.new();margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for lado in ["left","right","top","bottom"]:margem.add_theme_constant_override("margin_"+lado,24)
 add_child(margem)
 var coluna: VBoxContainer=VBoxContainer.new();coluna.add_theme_constant_override("separation",12);margem.add_child(coluna)
 var titulo: Label=Label.new();titulo.text="Laboratório de combate · referência Geodude";titulo.add_theme_font_size_override("font_size",22);coluna.add_child(titulo)
 var botao: Button=Button.new();botao.text="Executar teste controlado";botao.pressed.connect(executar);coluna.add_child(botao)
 var comparar: Button=Button.new();comparar.text="Abrir comparador de confrontos";comparar.pressed.connect(func() -> void:get_tree().change_scene_to_file("res://comparador_combate.tscn"));coluna.add_child(comparar)
 var exportar: Button=Button.new();exportar.text="Exportar resultado do teste";exportar.pressed.connect(_exportar);coluna.add_child(exportar)
 texto=RichTextLabel.new();texto.size_flags_vertical=Control.SIZE_EXPAND_FILL;coluna.add_child(texto)
 executar()
func _fixture(ivs: Array[int]) -> DadosPokemon:
 var p: DadosPokemon=DadosPokemon.new();p.especie=load("res://dados/especies/geodude.tres");p.nivel=1;p.qualidade=1.13
 var campos: Array[String]=["iv_hp","iv_atk","iv_def","iv_sp_atk","iv_sp_def","iv_spd"]
 for i in range(campos.size()):p.set(campos[i],ivs[i])
 return p
func _tempos(intervalo: float,passo: float) -> Array[float]:
 var agenda: RefCounted=preload("res://agenda_golpes.gd").new();agenda.configurar("Geodude",1)
 var ataques: Array[float]=[]
 for i in range(roundi(10.0/passo)+1):
  if not agenda.retirar_pronto(false,intervalo).is_empty():ataques.append(snappedf(agenda.tempo,0.001))
  agenda.avancar(passo)
 return ataques
func executar() -> Dictionary:
 # Um conjunto POSSÍVEL, não os IVs verdadeiros da conta original.
 var p: DadosPokemon=_fixture([32,28,32,32,32,17])
 var d: DadosPokemon=_fixture([16,16,16,16,16,16]);d.qualidade=1.0
 var golpe: Dictionary={"name":"Tackle","power":50,"type":"NORMAL","category":"PHYSICAL","cooldownMs":15000,"learnLevel":1}
 resultado={"origem":"laboratorio_local","perfil":"atributos_local_v2_piso_2_1","bonus_selvagem_removido":true,"fidelidade_comprovada":false,"ivs_fixture_sinteticos":[32,28,32,32,32,17],"iv_total":p.obter_total_ivs(),"atributos_fixture":p.obter_atributos(),"power_fixture":p.obter_power(),"hp_fixture":p.obter_vida_maxima(),"qualidade_fixture":p.qualidade,"defesa_adversario_fixture":d.obter_atributos()["def"],"observado_original":{"aliado_nivel":1,"qualidade_exibida":1.13,"power":8,"hp_aliado":24,"hp_selvagem":120,"tackle_causado":2,"tackle_recebido":1,"eff":1.0/3.0},"previsto_legado":{"tackle_causado":DANO.calcular(p,d,golpe,false,false),"tackle_recebido":DANO.calcular(d,p,golpe,true,false)},"previsto_local":{"tackle_causado":DANO.calcular(p,d,golpe,false),"tackle_recebido":DANO.calcular(d,p,golpe,true)},"hipoteses_temporais":{"intervalo1_5_passo60fps":_tempos(1.5,1.0/60.0),"intervalo1_5_tick200ms":_tempos(1.5,0.2),"intervalo2_tick200ms":_tempos(2.0,0.2)},"limites":["IVs sintéticos compatíveis com os atributos exibidos, não inferência dos IVs reais.","Atributos defensivos do selvagem original não são conhecidos.","Perfil v2: piso aliado 2 e remoção do bônus selvagem 1,8; coincidência deste caso não comprova fórmula universal.","O tick de mensagens pode ser diferente do relógio de execução dos golpes."]}
 if texto!=null:
  texto.text="REFERÊNCIA ORIGINAL\nGeodude Lv1 · qualidade exibida 1,13 · Power 8 · HP 24\nAtributos: HP1 ATK1 DEF2 SpATK1 SpDEF1 Speed1\nTackle causado: 2 · recebido: 1 · alvo: 120 HP\n\nFIXTURE LOCAL\nIVs sintéticos: 32/28/32/32/32/17 (total173). Não representam os IVs reais da conta.\nAtributos: %s · Power %d · HP %d\nDano previsto pela fórmula atual: causado %d, recebido %d.\n\nCALIBRAÇÃO PARCIAL\nO legado previa 1 causado. O perfil v2 usa piso local de 2 causado/1 recebido, sem o bônus selvagem 1,8 do protótipo; imunidades continuam zeradas. Reproduzir este caso não comprova a fórmula do servidor.\n\nHIPÓTESES DE CADÊNCIA (primeiros10 s)\n1,5 s em passos60fps: %s\n1,5 s em ticks200ms: %s\n2,0 s em ticks200ms: %s\n\nAs simulações demonstram quantização, não provam a cadência interna do servidor.\nSeu time, líder, IVs, níveis e saves não são editados por este laboratório." % [str(resultado["atributos_fixture"]),p.obter_power(),p.obter_vida_maxima(),resultado["previsto_local"]["tackle_causado"],resultado["previsto_local"]["tackle_recebido"],str(resultado["hipoteses_temporais"]["intervalo1_5_passo60fps"]),str(resultado["hipoteses_temporais"]["intervalo1_5_tick200ms"]),str(resultado["hipoteses_temporais"]["intervalo2_tick200ms"])]
 return resultado.duplicate(true)
func _exportar() -> void:
 DirAccess.make_dir_recursive_absolute("user://diagnosticos_combate")
 var caminho: String="user://diagnosticos_combate/laboratorio_geodude.json"
 var f: FileAccess=FileAccess.open(caminho,FileAccess.WRITE)
 if f==null:texto.text+="\nFalha ao gravar resultado.";return
 f.store_string(JSON.stringify(resultado,"  "));f.close()
 texto.text+="\nResultado exportado: "+ProjectSettings.globalize_path(caminho)
 print("LABORATORIO EXPORTADO: ",ProjectSettings.globalize_path(caminho))
