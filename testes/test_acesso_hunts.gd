extends SceneTree
## Acesso às hunts como o original (C: cliente, janela do mapa; sim/regras_acesso.gd). Save ISOLADO (testes/rodar.sh).
## Regra pura (região por nível do treinador, nível da hunt, aviso de Orre) e o mapa-múndi de verdade: abas das 4 regiões
## com os marcadores do snapshot, bloqueios com as mensagens do original e a confirmação de Orre.
## Rodar: testes/rodar.sh res://testes/test_acesso_hunts.gd

const ACESSO := preload("res://sim/regras_acesso.gd")
var falhas := 0
var total := 0
var etapa := 0
var quadros := 0
var mapa: Node


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	change_scene_to_file("res://cidade.tscn")


func _registro(slug: String) -> Dictionary:
	for r in mapa.catalogo:
		if String(r.get("slug", "")) == slug:
			return r
	return {}


func _visiveis() -> int:
	var n := 0
	for m in mapa.marcadores:
		if bool(m.get_meta("atende_filtro", true)):
			n += 1
	return n


func _pura() -> void:
	var v := ACESSO.verificar("kanto", 80, "Rhydon", 1)
	checar(not v["ok"] and v["motivo"] == "nivel" and String(v["texto"]) == "Você precisa ser nível 80 para caçar em Rhydon. 🔒", "Kanto: hunt nível 80 com treinador 1 → bloqueada (texto do original)")
	checar(ACESSO.verificar("kanto", 1, "Geodude", 1)["ok"] and ACESSO.verificar("kanto", 80, "Rhydon", 80)["ok"], "nível igual ao da hunt entra")
	v = ACESSO.verificar("outland", 150, "Brave Nidoqueen", 149)
	checar(not v["ok"] and v["motivo"] == "area" and String(v["texto"]) == "Outland desbloqueia no nível 150. 🔒", "Outland abre no nível 150")
	checar(ACESSO.verificar("nightmare", 2000, "Nightmare Elekid", 1999)["motivo"] == "area" and ACESSO.verificar("nightmare", 3000, "X", 2500)["motivo"] == "nivel"
		and ACESSO.verificar("nightmare", 2000, "X", 2000)["ok"], "Nightmare abre no 2000; hunt 3000 pede 3000")
	v = ACESSO.verificar("orre", 520, "Orre X", 520)
	checar(v["ok"] and v["confirmar"] and not ACESSO.verificar("orre", 520, "Orre X", 520, true)["confirmar"], "Orre: entra, mas pergunta dos TMs (sem TMs AoE+elemento)")
	var dj = preload("res://sim/dados_jogo.gd").carregar()
	var hunts: Array = dj.hunts.values()
	var n1 := ACESSO.hunts_liberadas(hunts, 1).size()
	var n100 := ACESSO.hunts_liberadas(hunts, 100).size()
	var n_tudo := ACESSO.hunts_liberadas(hunts, 3000).size()
	checar(n1 == 12 and n100 == 224 and n_tudo == 451, "liberadas: 12 no nível 1, as 224 de Kanto no 100, as 451 no 3000", "%d, %d, %d" % [n1, n100, n_tudo])


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	match etapa:
		0:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn" and quadros > 5:
				_pura()
				ej.novo_jogo(74, "Brock", 5)
				mapa = load("res://mapa_mundi.tscn").instantiate()
				current_scene.add_child(mapa)
				etapa = 1
				quadros = 0
		1:
			if quadros == 3:
				checar(not mapa.acesso_hunts_sem_limite, "mapa-múndi cobra o nível (padrão, C)")
				checar(_visiveis() == 227, "aba Kanto: 227 marcadores (224 hunts + 3 cidades, como o map-markers)", "%d" % _visiveis())
				mapa._selecionar_registro(_registro("rhydon"))
				checar(mapa.aviso.visible and mapa.aviso.text.contains("nível 80") and current_scene.scene_file_path == "res://cidade.tscn", "treinador 1 clica no Rhydon: aviso e fica na cidade", mapa.aviso.text)
				var contagem := {}
				for rg in ["outland", "orre", "nightmare"]:
					mapa.selecionar_regiao(rg)
					contagem[rg] = _visiveis()
				checar(contagem == {"outland": 47, "orre": 72, "nightmare": 108}, "abas: Outland 47, Orre 72, Nightmare 108 hunts (map-markers, A)", str(contagem))
				mapa.selecionar_regiao("outland")
				mapa._selecionar_registro(_registro("brave_nidoqueen"))
				checar(mapa.aviso.text == "Outland desbloqueia no nível 150. 🔒", "Outland com treinador 1: aviso de desbloqueio", mapa.aviso.text)
				ej.definir_perfil_treinador("Brock", 520)
				mapa.selecionar_regiao("orre")
				var orre := {}
				for r in mapa.catalogo:
					if String(r.get("area", "")) == "orre" and int(r["level"]) <= 520 and bool(r.get("simulada", false)):
						orre = r
						break
				mapa._selecionar_registro(orre)
				checar(mapa.confirmacao != null and mapa.confirmacao.visible and current_scene.scene_file_path == "res://cidade.tscn", "Orre com nível: pergunta dos TMs antes de entrar", String(orre.get("slug", "")))
				mapa.confirmacao.hide()
				mapa.selecionar_regiao("outland")
				mapa._selecionar_registro(_registro("brave_nidoqueen"))
				etapa = 2
				quadros = 0
		2:
			if current_scene != null and current_scene.scene_file_path == "res://caca_sim.tscn" and quadros > 5:
				checar(String(current_scene.sim.slug) == "brave_nidoqueen", "nível 520 entra na hunt da Outland pelo slug", String(current_scene.sim.slug))
				print("RESULTADO: %d/%d" % [total - falhas, total])
				quit(1 if falhas else 0)
				return true
			if quadros > 600:
				checar(false, "nível 520 entra na hunt da Outland pelo slug", "a cena não trocou")
				print("RESULTADO: %d/%d" % [total - falhas, total])
				quit(1)
				return true
	return false
