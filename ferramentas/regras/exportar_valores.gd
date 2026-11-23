extends SceneTree
## Game Master, passo 1: exporta os valores EM EXECUÇÃO de todos os parâmetros do jogo (sim + serviços), com o tipo e o
## literal exato (var_to_str), para ferramentas/regras/catalogo.py montar o catálogo (dados/regras/catalogo.json).
## Fontes: sim/regras.gd PARAMETROS + balanceamento "combate"; o `p` de cada serviço depois da sua seção; as seções do
## balanceamento que só existem lá (jogo_novo, apresentacao, metas).
## Uso: testes/rodar.sh res://ferramentas/regras/exportar_valores.gd -- <saida.json>

const DadosJogo := preload("res://sim/dados_jogo.gd")
const Regras := preload("res://sim/regras.gd")
const B := preload("res://sim/balanceamento.gd")


func _item(v) -> Dictionary:
	return {"literal": var_to_str(v), "tipo": type_string(typeof(v)), "json": v if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING] else JSON.stringify(v)}


func _init() -> void:
	var saida := String(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else "saida_testes/regras_valores.json"
	var dados = DadosJogo.carregar()
	var r := {}
	var sim: Dictionary = Regras.PARAMETROS.duplicate(true)
	B.aplicar(sim, "combate")
	r["sim"] = {}
	for k in sim:
		r["sim"][k] = _item(sim[k])
	var servicos := {
		"cidade": "res://sim/servico_cidade.gd", "diarias": "res://sim/servico_diarias.gd", "jogador": "res://sim/servico_jogador.gd",
		"ginasios": "res://sim/servico_ginasios.gd", "bosses": "res://sim/servico_bosses.gd", "cards": "res://sim/servico_cards.gd",
		"itens": "res://sim/servico_itens.gd", "profissoes": "res://sim/servico_profissoes.gd", "breeding": "res://sim/servico_breeding.gd",
		"golden_stars": "res://sim/servico_golden_stars.gd", "pesca": "res://sim/servico_pesca.gd", "ditto": "res://sim/servico_ditto.gd",
	}
	for sec in servicos:
		var sc = load(servicos[sec])
		var s = sc.new() if sec in ["cards", "jogador"] else sc.new(dados)
		r[sec] = {}
		for k in s.p:
			r[sec][k] = _item(s.p[k])
	var metas = load("res://sim/metas.gd")
	r["metas"] = {}
	for k in metas.parametros():
		if not sim.has(k):
			r["metas"][k] = _item(metas.parametros()[k])
	for sec in ["jogo_novo", "apresentacao"]:
		r[sec] = {}
		var s: Dictionary = B.secao(sec)
		for k in s:
			r[sec][k] = _item(s[k])
	var f := FileAccess.open(saida, FileAccess.WRITE)
	f.store_string(JSON.stringify(r, " "))
	f.close()
	var n := 0
	for k in r:
		n += (r[k] as Dictionary).size()
	print("VALORES %d parâmetros em %d fontes → %s" % [n, r.size(), saida])
	quit(0)
