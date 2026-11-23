extends SceneTree
## Pesca (ciclo 8): serviço (sim/servico_pesca.gd) e o Pescador na cidade, com save ISOLADO (rodar com testes/rodar.sh).
## C: faixas trancadas acima da skill, progresso cheio na faixa natural e 50% nas menores, recarga entre pescas.
## A: skill 4 → 12 peixes para o próximo nível.

const DadosJogo := preload("res://sim/dados_jogo.gd")
const Pesca := preload("res://sim/servico_pesca.gd")

var falhas := 0
var total := 0
var quadros := 0
var feito := false


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var dados = DadosJogo.carregar()
	var s = Pesca.new(dados)
	var est := {"itens": {}}
	var g: Dictionary = s.tratar(est, {"type": "pesca-get", "agora_ms": 0})[0]
	checar(int(g["skill"]) == 1 and bool(g["tiers"][0]["natural"]) and bool(g["tiers"][1]["locked"]) and s.for_next(4) == 12,
		"skill 1: faixa 1 natural, faixa 2 trancada; skill 4 pede 12 peixes (A)")
	checar(String(s.tratar(est, {"type": "pescar", "faixa": 1, "agora_ms": 0})[0]["type"]) == "error", "faixa trancada: recusado (C: Requer Pesca Nv N)")
	var r: Dictionary = s.tratar(est, {"type": "pescar", "faixa": 0, "agora_ms": 0, "semente": 3})[0]
	checar(String(r["type"]) == "fishing-result" and int(r["xp"]) > 0 and float(r["progresso"]) == 1.0, "pescou: peixe, XP da espécie, +1 de progresso", str(r["peixe"]))
	checar(String(s.tratar(est, {"type": "pescar", "faixa": 0, "agora_ms": 5000})[0]["type"]) == "error", "na recarga: ⏳ Aguarde (C)")
	est["pesca"]["skill"] = 12
	est["pesca"]["progresso"] = 0.0
	est["pesca"]["prox_ms"] = 0
	var r2: Dictionary = s.tratar(est, {"type": "pescar", "faixa": 0, "agora_ms": 0, "semente": 4})[0]
	checar(float(r2["progresso"]) == 0.5, "faixa menor que a natural: 50% do progresso (C)")
	est["pesca"]["prox_ms"] = 0
	est["pesca"]["progresso"] = 35.5
	var r3: Dictionary = s.tratar(est, {"type": "pescar", "faixa": 1, "agora_ms": 0, "semente": 5})[0]
	checar(bool(r3["subiu"]) and int(r3["skill"]) == 13, "36 de 36 peixes no nível 12: sobe para o 13")
	get_root().get_node("EstadoJogo").iniciar_depot()
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if feito or current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	feito = true
	var ej = get_root().get_node("EstadoJogo")
	var cena = current_scene
	checar(cena.placa_pesca != null and cena.painel_pesca != null, "Pescador na cidade (placa e janela)")
	cena.painel_pesca.abrir()
	var xp0: int = ej.experiencia_treinador_acumulada
	(cena.painel_pesca.find_child("Pescar", true, false) as Button).pressed.emit()
	checar(ej.experiencia_treinador_acumulada > xp0 and int(ej.pesca.get("peixes_total", 0)) == 1, "pescar na janela: XP do treinador e 1 peixe no save")
	checar((cena.painel_pesca.find_child("Pescar", true, false) as Button).disabled, "botão em recarga depois de pescar")
	checar(ej.salvar_agora(), "save gravado com a pesca")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
