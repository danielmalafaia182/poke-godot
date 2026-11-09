extends SceneTree
const E=preload("res://analise_encontros_pareados.gd")
const R=preload("res://regras_vida_selvagem.gd")
var checks: int=0
var falhas: int=0
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func executar() -> void:
	var fontes: Array=JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/fontes_perfis_conjuntos.json"))
	var ajuste: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/perfis_conjuntos_ajustados.json"))
	var engines: Dictionary={};var encontros: Dictionary={}
	for f in fontes:
		var engine: RefCounted=E.new();engine.iniciar(f);engines[f["fonte"]["arquivo"]]=engine
		for e in f["encontros"]:encontros[f["fonte"]["arquivo"]+"|"+e["id_local"]]=e
	var familia: Dictionary={}
	for item in E.familias():
		if item["id"]=="085_100_stab15":familia=item
	check(not familia.is_empty(),"hipótese fixa encontrada")
	var total: int=0
	for nivel in ajuste["resultados_por_nivel"]:
		var rows: Array=ajuste["resultados_por_nivel"][nivel]
		check(rows.size()==24,"24 encontros em cada nível testado")
		for row in rows:
			var ex: Dictionary=row["exemplo"]
			check(row["compativel"] and ex!=null,"exemplo condicional existente")
			var p: DadosPokemon=DadosPokemon.new()
			p.especie=preload("res://especies_importadas.gd").obter_especies()["Blastoise"]
			p.nivel=int(ex["nivel"]);p.qualidade=float(ex["qualidade"])
			p.iv_hp=int(ex["iv_hp"]);p.iv_def=int(ex["iv_def"]);p.iv_sp_def=int(ex["iv_sp_def"])
			var e: Dictionary=encontros[row["fonte"]+"|"+row["encontro"]]
			check(R.calcular(p)==int(e["hp_maximo"]),"mesmo perfil reproduz HP observado")
			var attrs: Dictionary=p.obter_atributos()
			var h: Dictionary=engines[row["fonte"]].hipotese(e,int(attrs["def"]),int(attrs["spDef"]),familia)
			check(h["danos_compativeis"],"mesmo perfil reproduz suporte de todos os danos recebidos pelo selvagem")
			check(h["escolhas_nominais_compativeis"],"melhor golpe nominal coincide para ambos os aliados")
			check(ex["ivs_livres"]==["atk","spAtk","speed"],"IVs não inferidos explicitamente livres")
			total+=1
	check(total==144,"144 exemplos conjuntos validados no Godot")
	print("PERFIS CONJUNTOS: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
