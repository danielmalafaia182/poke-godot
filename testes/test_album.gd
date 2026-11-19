extends SceneTree
## Álbum de Pokécards (ciclo 3; A: 430 cartas e o Poke Card Pack; C: abrir pacote vai pro álbum; classe 3: pesos e
## drop do pacote). Save ISOLADO (testes/rodar.sh).

const C := preload("res://sim/servico_cards.gd")
const Rng := preload("res://sim/rng.gd")

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
	var sv = C.new()
	checar(sv.cartas.size() == 430 and sv.sets.size() >= 3, "430 cartas em sets do snapshot (A)")
	var rng = Rng.new(5)
	var cont := {}
	for i in 4000:
		var r := String(sv.sortear(rng)["rarity"])
		cont[r] = int(cont.get(r, 0)) + 1
	checar(int(cont.get("common", 0)) > 2000 and int(cont.get("common", 0)) < 2800 and int(cont.get("mega_hyper_rare", 0)) < 10, "sorteio pelos pesos (classe 3): comum ~60%, hiper-rara rara", str(cont))
	var e := {"itens": {"6352": 3}}
	var m = sv.tratar(e, {"type": "pack-abrir", "qtd": 2, "agora": 10, "semente": 1})
	checar(String(m[0]["type"]) == "pack-aberto" and (m[0]["cartas"] as Array).size() == 2 and int(e["itens"]["6352"]) == 1 and (e["album"] as Dictionary).size() >= 1, "abrir 2 pacotes: 2 cartas no álbum, 1 pacote sobra (C)")
	checar(String(sv.tratar({"itens": {}}, {"type": "pack-abrir", "qtd": 1, "agora": 1})[0]["type"]) == "error", "sem pacote não abre")
	get_root().get_node("EstadoJogo").iniciar_depot()
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if feito or current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	feito = true
	var ej = get_root().get_node("EstadoJogo")
	ej.inventario.estoque_materiais[preload("res://regras_loot.gd").id_interno(6352)] = 5
	current_scene.get_node("Interface/MenuSuperior").botoes["pokecards"].pressed.emit()
	var pa: Control = current_scene.get_node("Interface/PainelAlbum")
	checar(pa.visible and not (pa.find_child("AbrirPacote", true, false) as Button).disabled, "dock: o álbum abre e o pacote da BAG aparece")
	var r: Dictionary = pa.abrir_pacotes(1)
	checar((r.get("cartas", []) as Array).size() == 1 and int(ej.inventario.estoque_materiais.get(preload("res://regras_loot.gd").id_interno(6352), 0)) == 4 and ej.album.size() == 1, "abrir pela janela: carta no álbum, pacote sai da BAG")
	checar(ej.salvar_agora(), "save gravado")
	var sl = load("res://salvamento_local.gd").new()
	var d: Dictionary = sl.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json")).get("dados", {})
	checar((d.get("album", {}) as Dictionary).size() == 1, "álbum no save")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
