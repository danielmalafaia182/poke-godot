extends SceneTree
## Planejamento das gravações da fase 3 (dados, não gravação): para cada Pokémon das contas do usuário e cada espécie de
## cada hunt, o golpe que a hipótese de seleção (Regras.escolher_golpe, F) prevê, o 2º colocado e a margem entre eles,
## mais o custo da luta (golpes e segundos para abater um selvagem; dano previsto que um selvagem tira por golpe).
## IVs desconhecidos: IV 16 e Quality 1,0 dos dois lados (a margem diz quanto a previsão aguenta essa incerteza).
## Saída: saida_testes/plano_fase3.json. Uso: testes/rodar.sh res://ferramentas/fase3/planejar_fase3.gd

const Regras := preload("res://sim/regras.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")

# [espécie, nível, IVs (opcional), Quality (opcional)]. O Venusaur da conta A é o indivíduo das gravações (IVs fechados
# pelos stats exibidos, D; Quality 0,835 do poke-delta, A). Os outros: IV 16 e Quality 1,0 (desconhecidos).
const IVS_VENUSAUR := {"hp": 26, "atk": 5, "def": 4, "spAtk": 18, "spDef": 17, "speed": 28}
const CONTAS := {
	"A": [["Venusaur", 124, IVS_VENUSAUR, 0.835], ["Geodude", 10]],
	"B": [["Exeggutor", 413], ["Rhydon", 423], ["Gyarados", 214], ["Golem", 386]],
}
const IVS := {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}


func _stats(esp: Dictionary, nivel: int, modo: String, ivs: Dictionary = IVS, q: float = 1.0) -> Dictionary:
	return Regras.calcular_stats_dano(esp["base"], ivs, nivel, q, modo)


func _valores(atk: Dictionary, nivel: int, sa: Dictionary, defe: Dictionary, sd: Dictionary) -> Array:
	## [[valor, nome, tipo, cd], …] de todos os golpes elegíveis, do maior para o menor (mesma conta de escolher_golpe)
	var p: Dictionary = Regras.PARAMETROS
	var ta := Regras.tipos_de(atk)
	var td := Regras.tipos_de(defe)
	var r: Array = []
	for g in atk.get("golpes", []):
		var cat := String(g.get("categoria", ""))
		var poder := int(g.get("poder", 0))
		if int(g.get("nivel", 1)) > nivel or cat == "STATUS" or poder <= 0 or poder > int(p.golpe_poder_maximo):
			continue
		var esp := cat == "SPECIAL"
		var tipo := String(g.get("tipo", ""))
		var stab: bool = tipo == ta[0] or (ta[1] != "" and tipo == ta[1])
		var eff := Regras.efetividade_amplificada(Regras.efetividade_bruta(tipo, td[0], td[1]))
		var v := float(poder) * float(sa["spAtk" if esp else "atk"]) / maxf(1.0, float(sd["spDef" if esp else "def"])) * (float(p.stab) if stab else 1.0) * eff
		r.append([v, String(g["nome"]), tipo, int(g.get("cooldownMs", 0))])
	r.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[3] < b[3]))
	return r


func _initialize() -> void:
	var dados = DadosJogo.carregar()
	var por_nome := {}
	for id in dados.especies:
		por_nome[String(dados.especies[id]["nome"])] = dados.especies[id]
	var p: Dictionary = Regras.PARAMETROS
	var linhas: Array = []
	for conta in CONTAS:
		for par in CONTAS[conta]:
			var atk: Dictionary = por_nome[par[0]]
			var nivel: int = par[1]
			var ivs_l: Dictionary = par[2] if par.size() > 2 else IVS
			var q_l: float = par[3] if par.size() > 3 else 1.0
			var sa := _stats(atk, nivel, String(p.stats_dano_aliado), ivs_l, q_l)
			var s_int := Regras.calcular_stats(atk["base"], ivs_l, nivel, q_l)
			var hp_aliado := Regras.hp_combate_aliado(int(s_int["hp"]))
			for slug in dados.hunts:
				var h: Dictionary = dados.hunts[slug]
				var nivel_s := int(h.get("nivel", 1))
				var vistas := {}
				for s in h.get("spawns", []):
					vistas[int(s["pokeId"])] = int(vistas.get(int(s["pokeId"]), 0)) + 1
				for sid in vistas:
					var defe: Dictionary = dados.especie(sid)
					var sd := _stats(defe, nivel_s, String(p.stats_dano_selvagem))
					var vals := _valores(atk, nivel, sa, defe, sd)
					if vals.is_empty():
						continue
					var g1: Dictionary = Regras.escolher_golpe(atk, nivel, sa, defe, sd, p)
					var hp_s := Regras.hp_combate_selvagem(int(Regras.calcular_stats(defe["base"], IVS, nivel_s, 1.0)["hp"]), p)
					var d1 := Regras.dano(nivel, int(g1["poder"]), float(sa["spAtk" if g1["categoria"] == "SPECIAL" else "atk"]),
						float(sd["spDef" if g1["categoria"] == "SPECIAL" else "def"]), bool(g1["stab"]), float(g1.get("eff", 1.0)), false, 0.925, p)
					# golpe do selvagem contra o aliado (mesma hipótese de seleção)
					var sdd := _stats(defe, nivel_s, String(p.stats_dano_selvagem))
					var gs: Dictionary = Regras.escolher_golpe(defe, nivel_s, sdd, atk, sa, p)
					var ds := 0
					if not gs.is_empty():
						ds = Regras.dano(nivel_s, int(gs["poder"]), float(sdd["spAtk" if gs["categoria"] == "SPECIAL" else "atk"]),
							float(sa["spDef" if gs["categoria"] == "SPECIAL" else "def"]), bool(gs["stab"]), float(gs.get("eff", 1.0)), true, 0.925, p)
					var golpes := int(ceil(float(hp_s) / maxf(1.0, float(d1))))
					linhas.append({"conta": conta, "lider": par[0], "nivel_lider": nivel, "hp_lider": hp_aliado,
						"hunt": slug, "nome_hunt": String(h.get("nome", slug)), "area": String(h.get("area", "")), "nivel_hunt": nivel_s,
						"especie": String(defe["nome"]), "tipos_alvo": defe.get("tipos", []), "spawns_da_especie": vistas[sid],
						"previsto": String(g1["nome"]), "segundo": String(vals[1][1]) if vals.size() > 1 else "",
						"margem": snappedf(float(vals[0][0]) / maxf(1e-9, float(vals[1][0])), 0.001) if vals.size() > 1 else 99.0,
						"empate_por_cooldown": vals.size() > 1 and is_equal_approx(float(vals[0][0]), float(vals[1][0])),
						"golpes_para_abater": golpes, "segundos_para_abater": golpes * int(p.ataque_aliado_ticks) * int(p.tick_ms) / 1000.0,
						"dano_selvagem_por_golpe": ds, "golpes_do_selvagem_para_nocautear": int(ceil(float(hp_aliado) / maxf(1.0, float(ds)))),
						"golpe_selvagem": String(gs.get("nome", ""))})
	var f := FileAccess.open(ProjectSettings.globalize_path("res://saida_testes/plano_fase3.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(linhas, " "))
	f.close()
	print("PLANO %d linhas" % linhas.size())
	quit(0)
