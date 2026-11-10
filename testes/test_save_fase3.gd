extends SceneTree
## Fase 3: campos opcionais do save (medidor de captura por espécie e última hunt) e a regra da penalidade de entrada.
## Save antigo (sem os campos) carrega; ida e volta preserva o medidor; valor inválido é recusado; sessão expira com
## 15 min de jogo fechado (B-relatado/E). Save isolado (rodar com testes/rodar.sh).

const CenarioJogo := preload("res://sim/cenario_jogo.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	call_deferred("executar")


func _envelope(s: RefCounted, dados: Dictionary) -> String:
	var ida := JSON.stringify(dados)
	return JSON.stringify({"formato": s.FORMATO, "versao": s.VERSAO, "sha256": ida.sha256_text(), "conteudo": ida})


func executar() -> void:
	var e: Node = root.get_node("EstadoJogo")
	var s: RefCounted = load("res://salvamento_local.gd").new()
	var lido: Dictionary = s.decodificar(FileAccess.get_file_as_string("res://dados/testes/save_antigo_inventario.json"))
	checar(lido.has("dados"), "save antigo (sem os campos novos) passa na validação", str(lido.get("erro", "")))
	s._restaurar(e, lido["dados"])
	checar(e.medidor_captura.is_empty() and e.ultima_hunt_slug == "", "save antigo: medidor vazio e sem última hunt")
	var fechado := int(Time.get_unix_time_from_system()) - int(lido["dados"].get("salvo_em_unix", 0))
	checar(e.sessao_expirada == (fechado >= 900 or not lido["dados"].has("salvo_em_unix")), "sessão expirada decidida pelo salvo_em_unix", "%d s" % fechado)

	e.medidor_captura = {"112": {"investido": 150.0, "tentativas": 3, "total": 40, "gasto": 2000}, "19s": {"investido": 0.0, "tentativas": 0, "total": 2, "gasto": 100}}
	e.ultima_hunt_slug = "rhydon"
	var dados: Dictionary = s.construir_dados(e)
	checar(s._validar(dados) == "", "save com medidor e última hunt passa na validação", s._validar(dados))
	var volta: Dictionary = s.decodificar(_envelope(s, dados))
	s._restaurar(e, volta["dados"])
	checar(e.medidor_captura.get("112", {}).get("tentativas", -1) == 3 and float(e.medidor_captura["112"]["investido"]) == 150.0
		and e.medidor_captura.has("19s") and e.ultima_hunt_slug == "rhydon", "ida e volta preserva o medidor e a última hunt", str(e.medidor_captura))
	checar(not e.sessao_expirada, "save recém-gravado: sessão não expirada")
	var velho := dados.duplicate(true)
	velho["salvo_em_unix"] = int(Time.get_unix_time_from_system()) - 901
	s._restaurar(e, s.decodificar(_envelope(s, velho))["dados"])
	checar(e.sessao_expirada, "15 min com o jogo fechado: sessão expirada")
	var ruim := dados.duplicate(true)
	ruim["captura_medidor"] = {"112": {"investido": -5, "tentativas": 1, "total": 1, "gasto": 0}}
	checar(s._validar(ruim) != "", "medidor inválido é recusado", s._validar(ruim))
	ruim = dados.duplicate(true)
	ruim["ultima_hunt"] = 7
	checar(s._validar(ruim) != "", "última hunt inválida é recusada")

	checar(CenarioJogo.penalizar_entrada(false, "rhydon", "geodude"), "hunt diferente da última: penaliza")
	checar(not CenarioJogo.penalizar_entrada(false, "rhydon", "rhydon"), "mesma hunt de novo: não penaliza")
	checar(CenarioJogo.penalizar_entrada(true, "rhydon", "rhydon"), "sessão expirada: penaliza mesmo na mesma hunt")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
