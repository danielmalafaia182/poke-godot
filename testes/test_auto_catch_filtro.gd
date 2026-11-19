extends SceneTree
## Filtro de nomes do Auto-Catch (C, Auto-Helper: "Nomes (separe por vírgula)"; "Campo em branco = capturar todos. O
## filtro vale pros dois modos."). Hunt rattata, 3 min com o Geodude do jogo novo e Super Ball.
## Rodar: testes/rodar.sh res://testes/test_auto_catch_filtro.gd

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


func tentativas(dados, mapa, nomes: String) -> int:
	var jogo := {"slug": "rattata", "hunt": "Rattata", "equipe": [{"id": "g", "nome": "Geodude", "xp": 400,
		"ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}, "quality": 1.0, "hp": -1}],
		"auto_catch": true, "bola_auto_catch": 3, "auto_catch_nomes": nomes, "auto_potion": true, "penalizar": false,
		"bolas": {3: 500}, "inventario": [{"itemId": 200, "quantity": 100}]}
	var sim = Simulacao.new(CenarioJogo.configurar(jogo, dados, 5, 0), dados, mapa)
	sim.iniciar()
	var n := 0
	for t in 900:
		for reg in sim.passo():
			if String(reg.get("msg", reg).get("type", "")) == "catch-result":
				n += 1
	return n


func _init() -> void:
	var dados = DadosJogo.carregar()
	var mapa = MapaHunt.carregar("rattata", Fontes.ler_mapa("rattata"), Fontes.ler_colisao())
	checar(Simulacao.nomes_filtro(" Charizard, gyarados ,,") == ["charizard", "gyarados"], "nomes: separados por vírgula, sem espaço nem caixa")
	var vazio := tentativas(dados, mapa, "")
	var certo := tentativas(dados, mapa, "pidgey, RATTATA")
	var outro := tentativas(dados, mapa, "pidgey")
	checar(vazio > 0 and vazio == certo, "campo em branco = captura todos; com o nome da espécie, o mesmo", "%d e %d" % [vazio, certo])
	checar(outro == 0, "com outro nome, nenhuma bola", "%d" % outro)
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
