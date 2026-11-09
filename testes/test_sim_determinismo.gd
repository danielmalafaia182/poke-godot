extends SceneTree
## Determinismo e estabilidade: mesma semente → JSONL idêntico byte a byte; semente diferente → saída diferente;
## 1 h simulada sem erro e em segundos.
## Rodar: testes/rodar.sh res://testes/test_sim_determinismo.gd

const RodarSim := preload("res://testes/rodar_sim.gd")
const ESTADO := "dados/testes/estado_rhydon_venusaur.json"

var falhas := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _init() -> void:
	var a: String = RodarSim.simular(ESTADO, 600, 7)["gravador"].texto()
	var b: String = RodarSim.simular(ESTADO, 600, 7)["gravador"].texto()
	var c: String = RodarSim.simular(ESTADO, 600, 8)["gravador"].texto()
	checar(a == b, "mesma semente, mesmo JSONL (600 s)", "%d bytes, md5 %s" % [a.length(), a.md5_text()])
	checar(a != c, "semente diferente, JSONL diferente")
	var t0 := Time.get_ticks_msec()
	var r := RodarSim.simular(ESTADO, 3600, 1)
	var dt := Time.get_ticks_msec() - t0
	var est: Dictionary = r["sim"].estatisticas
	checar(int(est["abates"]) > 0 and int(est["hits_selvagem"]) > 0, "1 h simulada com combate", str(est))
	checar(dt < 60000, "1 h simulada em menos de 60 s", "%d ms" % dt)
	print("RESULTADO: %s" % ("OK" if falhas == 0 else "%d falha(s)" % falhas))
	quit(0 if falhas == 0 else 1)
