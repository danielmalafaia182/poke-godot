extends SceneTree
## Fase 4, item 3 — diárias e tarefas na cena da cidade, com save ISOLADO (rodar com testes/rodar.sh):
##   janela Quests, Tasks & Dailys → Daily Gift (bolas e boost) → Daily Kill (escolher, abater, coletar) → Daily Catch
##   (captura premiada) → tarefa do Paul (abates, entregar) → save → recarga com diárias, boosts e abates por espécie.

const ESPECIES: Script = preload("res://especies_importadas.gd")
const LOOT: Script = preload("res://regras_loot.gd")

var falhas := 0
var total := 0
var etapa := 0
var quadros := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var ej = get_root().get_node("EstadoJogo")
	ej.iniciar_depot()
	ej.definir_perfil_treinador("Teste", 169)
	ej.vip = true
	change_scene_to_file("res://cidade.tscn")


func _botao(p: Node, nome: String) -> Button:
	return p.find_child(nome, true, false) as Button


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	if etapa != 0 or current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	etapa = 1
	var painel: Control = current_scene.get_node("Interface/PainelDiarias")
	checar(painel != null and current_scene.find_child("Diarias", true, false) != null, "botão e janela Quests, Tasks & Dailys na cidade (⚙)")
	# ---- Daily Gift
	var bolas0 := int(ej.estoque_bolas.get(1, 0))
	painel.abrir(0)
	var b := _botao(painel, "ColetarGift")
	checar(b != null and not b.disabled, "Daily Gift: botão Coletar ativo no 1º dia")
	b.pressed.emit()
	checar(int(ej.estoque_bolas.get(1, 0)) == bolas0 + 100 and _botao(painel, "ColetarGift").disabled, "coletou o dia 1 (+100 Poké Balls); botão desliga até amanhã")
	# ---- Daily Kill
	painel.abrir(1)
	var esc := _botao(painel, "Escolher0")
	checar(esc != null, "Daily Kill: 3 opções para escolher (nível 169)")
	esc.pressed.emit()
	var k: Dictionary = ej.diarias_tratar({"type": "daily-kill-get", "agora": int(Time.get_unix_time_from_system())})["msg"]
	var alvo := int(k["options"][0]["speciesId"])
	for i in int(k["options"][0]["qty"]):
		ej.diaria_abate(alvo)
	painel.atualizar()
	var xp0: int = ej.experiencia_treinador_acumulada
	var tok0 := int(ej.inventario.estoque_materiais.get(LOOT.id_interno(13115), 0))
	var ck := _botao(painel, "ColetarKill")
	checar(ck != null and not ck.disabled, "missão completa: Coletar ativo")
	ck.pressed.emit()
	checar(ej.experiencia_treinador_acumulada == xp0 + int(k["options"][0]["xp"]) and int(ej.inventario.estoque_materiais.get(LOOT.id_interno(13115), 0)) == tok0 + 6,
		"coletou: +XP da missão no treinador e +6 Devoted Token na BAG", "%d → %d" % [xp0, ej.experiencia_treinador_acumulada])
	# ---- Daily Catch
	var xp1: int = ej.experiencia_treinador_acumulada
	var r: Dictionary = ej.diaria_captura(246)
	var xp_c := int(r["msgs"][0]["xp"]) if not r["msgs"].is_empty() else -1
	checar(xp_c > 0 and ej.experiencia_treinador_acumulada == xp1 + xp_c, "captura de Larvitar: slot 1, XP do Daily Catch no treinador", str(r.get("aviso", r.get("erro", ""))))
	painel.abrir(2)
	checar(painel.find_child("*", true, false) != null, "aba Daily Catch desenha")
	# ---- tarefa do Paul (Viridian)
	for i in 15:
		ej.diaria_abate(19)
	for i in 5:
		ej.diaria_abate(41)
	painel.abrir(3)
	var ent := _botao(painel, "Entregar_paul")
	checar(ent != null and not ent.disabled, "Paul: 15 Rattata e 5 Zubat → Entregar ativo")
	var xp2: int = ej.experiencia_treinador_acumulada
	ent.pressed.emit()
	checar(ej.experiencia_treinador_acumulada == xp2 + 920 and _botao(painel, "Entregar_paul") == null, "entregou: +920 XP; a tarefa sai da lista de pendentes")
	# ---- save e recarga
	ej.boosts = [{"key": "xp", "until": int(Time.get_unix_time_from_system()) * 1000 + 3600000, "pct": 50}]
	ej.registrar_abates(3, 74)
	checar(ej.salvar_agora(), "save gravado")
	var sl = load("res://salvamento_local.gd").new()
	var lido: Dictionary = sl.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json"))
	var d: Dictionary = lido.get("dados", {})
	checar(d.has("diarias") and d.has("boosts") and int(d["streak"]["bySpecies"].get("74", 0)) >= 3, "save com diárias, boosts e abates por espécie", str(lido.get("erro", "")))
	var antes := JSON.stringify(ej.diarias)
	ej.diarias = {}
	ej.boosts = []
	ej.streak = {}
	sl._restaurar(ej, d)
	checar(JSON.stringify(ej.diarias) == JSON.stringify(JSON.parse_string(antes)) and ej.boosts.size() == 1 and int(ej.streak["bySpecies"].get("74", 0)) >= 3, "recarga: diárias, boosts e abates por espécie iguais")
	var dk: Dictionary = ej.diarias_tratar({"type": "daily-kill-get", "agora": int(Time.get_unix_time_from_system())})["msg"]
	checar(bool(dk["claimed"]), "depois da recarga: o Daily Kill de hoje continua coletado")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
