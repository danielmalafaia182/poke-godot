extends SceneTree
## Troca de líder (ciclo 5; A: vídeo do usuário referencia_visual/teste_ciclo4/cooldown.mp4 no original). Save ISOLADO.
## Confere: escolher outro membro faz dele o líder e o põe em 1º no time (o antigo vai para o lugar dele); na hunt, depois
## de uma troca manual, nova troca fica bloqueada 5 s (sim: troca_manual_liberada_tick + mensagem poke-swap-cooldown) e
## uma segunda troca dentro dos 5 s é recusada; depois dos 5 s, aceita.

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var ej = get_root().get_node("EstadoJogo")
	ej.novo_jogo(1, "Teste", 3)
	for id in [4, 7]:
		var p = load("res://dados_pokemon.gd").new()
		p.especie = preload("res://especies_importadas.gd").obter_todas().values().filter(func(e): return e.nome == {4: "Charmander", 7: "Squirtle"}[id])[0]
		p.normalizar_atributos() if p.has_method("normalizar_atributos") else null
		ej.time_pokemon.append(p)
	var antes: Array = ej.time_pokemon.map(func(p): return String(p.especie.nome))
	var alvo = ej.time_pokemon[2]
	var ok: bool = ej.selecionar_lider(alvo)
	var depois: Array = ej.time_pokemon.map(func(p): return String(p.especie.nome))
	checar(ok and ej.obter_lider() == alvo and depois[0] == "Squirtle" and depois[2] == "Bulbasaur",
		"o escolhido vira líder e sobe para o 1º lugar; o antigo vai para o lugar dele", "%s → %s" % [str(antes), str(depois)])
	# sim: cooldown depois da troca manual
	var dados = DadosJogo.carregar()
	var mapa = MapaHunt.carregar("rattata", Fontes.ler_mapa("rattata"), Fontes.ler_colisao())
	var eq: Array = []
	for nome in ["Bulbasaur", "Charmander", "Squirtle"]:
		eq.append({"id": nome, "nome": nome, "xp": 100, "ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}, "quality": 1.0, "hp": -1})
	var jogo := {"slug": "rattata", "hunt": "Rattata", "equipe": eq, "auto_catch": false, "auto_potion": false, "penalizar": false, "bolas": {}, "inventario": []}
	var sim = Simulacao.new(CenarioJogo.configurar(jogo, dados, 3, 0), dados, mapa)
	sim.iniciar()
	for i in 10:
		sim.passo()
	var r: Array = sim.passo([{"type": "switch", "teamIndex": 1}])
	var cd: Array = r.filter(func(x): return String(x.get("msg", x).get("type", "")) == "poke-swap-cooldown")
	checar(sim.ativo == 1 and cd.size() == 1 and int(cd[0].get("msg", cd[0])["leftMs"]) == 5000, "troca manual aceita e avisa o cooldown de 5 s")
	var r2: Array = sim.passo([{"type": "switch", "teamIndex": 2}])
	checar(sim.ativo == 1 and not r2.filter(func(x): return String(x.get("msg", x).get("type", "")) == "error").is_empty(), "outra troca dentro dos 5 s é recusada")
	for i in 25:
		sim.passo()
	sim.passo([{"type": "switch", "teamIndex": 2}])
	checar(sim.ativo == 2, "depois dos 5 s a troca é aceita")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
