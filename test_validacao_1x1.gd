extends SceneTree
const C=preload("res://regras_dano_candidato.gd")
const V=preload("res://regras_vida_selvagem.gd")
var checks: int=0
var falhas: int=0
var caso: Dictionary
var perfil: Dictionary
var thrash: Dictionary={"name":"Thrash","power":120,"type":"NORMAL","category":"PHYSICAL"}
var skull: Dictionary={"name":"Skull Bash","power":130,"type":"NORMAL","category":"PHYSICAL"}
var tipos: Array[String]=["WATER"]
var gya_tipos: Array[String]=["WATER","FLYING"]
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func pokemon(nivel: int,q: float,iv_hp: int,iv_def: int,iv_atk: int) -> DadosPokemon:
	var p: DadosPokemon=DadosPokemon.new()
	p.especie=preload("res://especies_importadas.gd").obter_especies()["Blastoise"]
	p.nivel=nivel;p.qualidade=q;p.iv_hp=iv_hp;p.iv_def=iv_def;p.iv_atk=iv_atk
	return p
func recebe_compativel(attrs: Dictionary) -> bool:
	var lo: int=C.detalhar_atributos(perfil["nivel"],perfil["atributos"],attrs,gya_tipos,thrash,1.0,0.85)["dano"]
	var hi: int=C.detalhar_atributos(perfil["nivel"],perfil["atributos"],attrs,gya_tipos,thrash,1.0,1.0)["dano"]
	for d in caso["ajuste_exploratorio"]["saida"]:
		if int(d)<lo or int(d)>hi:return false
	return true
func validar_exemplo(ex: Dictionary) -> void:
	var p: DadosPokemon=pokemon(ex["level"],ex["q"],ex["hpIV"],ex["defIV"],ex["atkIV"])
	check(V.calcular(p)==3780,"exemplo mantém HP3780")
	check(recebe_compativel(p.obter_atributos()),"exemplo mantém todos os Thrash")
	var lo: int=C.detalhar_atributos(ex["attacklevel"],p.obter_atributos(),perfil["atributos"],tipos,skull,1.0,0.85,true)["dano"]
	var hi: int=C.detalhar_atributos(ex["attacklevel"],p.obter_atributos(),perfil["atributos"],tipos,skull,1.0,1.0,true)["dano"]
	check(lo<=54 and hi>=55,"exemplo alternativo comporta54/55")
func executar() -> void:
	caso=JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/caso_1x1_video.json"));perfil=caso["perfil_aliado_assumido"]
	for s in caso["snapshots"]:
		var total: int=0
		for h in s["golpes"]:
			if int(h["slot"])==4:total+=int(h["amount"])
		check(int(s["selvagem_hp_depois_pacote"])==maxi(0,int(s["selvagem_hp_antes_pacote"])-total),"pacote fecha HP do selvagem, preservando overkill")
		if int(s["seq"]) in [160,170]:
			check(int(s["hero_hp_antes_pacote"])-int(s["hero_hp_depois_pacote"])==int(s["golpes"][0]["amount"]),"54/55 fecham a vida do aliado")
	var niveis: Array[int]=[94,95,96,97,98,99]
	var maximos: Array[int]=[47,47,48,48,49,50]
	var qs: Array[float]=[]
	for i in range(800,1600):qs.append(i/1000.0)
	for i in range(1700,1800):qs.append(i/1000.0)
	qs.append(1.8)
	for idx in range(niveis.size()):
		var nivel: int=niveis[idx];var maior: int=-1
		var p: DadosPokemon=pokemon(nivel,1.0,1,1,32)
		for q in qs:
			p.qualidade=q;var hp_compativel: bool=false
			for iv in range(1,33):
				p.iv_hp=iv
				if V.calcular(p)==3780:hp_compativel=true;break
			if not hp_compativel:continue
			for iv in range(1,33):
				p.iv_def=iv
				if not recebe_compativel(p.obter_atributos()):continue
				var dano: int=C.detalhar_atributos(nivel,p.obter_atributos(),perfil["atributos"],tipos,skull,1.0,1.0,true)["dano"]
				maior=maxi(maior,dano)
		check(maior==maximos[idx] and maior<54,"busca exaustiva condicionada refuta nível"+str(nivel))
		print("TETO 1X1: nivel",nivel," = ",maior)
	var achou: bool=false
	for r in caso["ajuste_exploratorio"]["resultados"]:
		if int(r["nivel_atributos"])==111:
			validar_exemplo(r["exemplo_ajuste"]);achou=true;break
	check(achou,"alternativa de nível comum111 conferida como exemplo, não nível descoberto")
	validar_exemplo(caso["ajuste_exploratorio"]["alternativa"]["exemplo_ajuste"])
	print("VALIDACAO 1X1: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
