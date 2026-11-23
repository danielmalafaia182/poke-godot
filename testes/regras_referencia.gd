extends SceneTree
## Referência byte a byte das regras (Game Master): roda a sim em cenários fixos e imprime o md5 de cada saída JSONL.
## Uso: testes/rodar.sh res://testes/regras_referencia.gd  →  linhas "REF <cenário> <md5> <bytes>".
## Cenários: Rhydon com Venusaur (estado gravado, 20 min), Orre (electrike com VIP, 10 min), Kanto nível baixo
## (geodude com Bulbasaur, 10 min, captura, poções) — cobrem combate, movimento, XP com piso, captura, loot e sessão.

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")
const JsonCanonico := preload("res://sim/json_canonico.gd")


static func rodar(cfg: Dictionary, dados, slug: String, minutos: float) -> String:
	var sim = Simulacao.new(cfg, dados, MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao()))
	var linhas := PackedStringArray()
	for m in sim.iniciar():
		linhas.append(JsonCanonico.texto(m.get("msg", m)))
	for t in int(minutos * 300):
		for m in sim.passo():
			linhas.append(JsonCanonico.texto(m.get("msg", m)))
	return "\n".join(linhas)


static func cenarios(dados) -> Dictionary:
	var r := {}
	r["rhydon"] = rodar(Cenario.de_estado("res://dados/testes/estado_rhydon_venusaur.json", dados, 5), dados, "rhydon", 20.0)
	var orre := {"slug": "electrike", "hunt": "electrike", "vip": true, "penalizar": true, "auto_catch": true, "bola_auto_catch": 3, "bolas": {3: 500},
		"equipe": [{"id": "g", "nome": "Golem", "xp": Regras.xp_total_para_nivel(560), "ivs": {"hp": 20, "atk": 20, "def": 20, "spAtk": 20, "spDef": 20, "speed": 20},
		"quality": 1.3, "hp": -1}], "auto_potion": true, "inventario": [{"itemId": 204, "quantity": 500}]}
	r["orre"] = rodar(CenarioJogo.configurar(orre, dados, 9, 0), dados, "electrike", 10.0)
	var baixo := {"slug": "geodude", "hunt": "geodude", "penalizar": true, "auto_catch": true, "bola_auto_catch": 1, "bolas": {1: 100},
		"equipe": [{"id": "b", "nome": "Bulbasaur", "xp": 0, "ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16},
		"quality": 1.0, "hp": -1}], "auto_potion": true, "inventario": [{"itemId": 200, "quantity": 100}]}
	r["baixo"] = rodar(CenarioJogo.configurar(baixo, dados, 11, 0), dados, "geodude", 10.0)
	return r


func _init() -> void:
	var dados = DadosJogo.carregar()
	var r := cenarios(dados)
	for k in r:
		print("REF %s %s %d" % [k, String(r[k]).md5_text(), String(r[k]).length()])
	quit(0)
