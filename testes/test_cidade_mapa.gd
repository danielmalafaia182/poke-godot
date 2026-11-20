extends SceneTree
## Cidade (ciclo 4, item 2): Cerulean com o mapa do servidor (cerulean_novo) pelo renderizador das hunts.
## Confere: a colisão da cidade é a mesma regra do walkable() do cliente — casa a casa igual à grade derivada pela sim
## (sim/mapa_hunt.gd, que bate com as grades reais de 7 hunts); a casa (−2,−4) à direita da porta do Pokémon Center
## é bloqueada pela peça invisível 8274 (A: collision.json do servidor) e as duas casas da porta (−3,−5)/(−2,−5) e a de
## baixo (−3,−4) são livres; os 5 NPCs do city-npcs (A) são desenhados; o mapa tem peças animadas (decoração).
## Rodar: testes/rodar.sh res://testes/test_cidade_mapa.gd

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")

var falhas := 0
var total := 0
var quadros := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var cen = load("res://cenario_cidade.gd").new()
	get_root().add_child.call_deferred(cen)
	get_root().set_meta("cen", cen)


func _verificar(cen) -> void:
	var m = MapaHunt.carregar("cerulean_novo", Fontes.ler_mapa("cerulean_novo"), Fontes.ler_colisao())
	var dif := 0
	var livres := 0
	for r in m.rows:
		for c in m.cols:
			var cel := Vector2i(c + m.min_tx, r + m.min_ty)
			var a: bool = m.passavel(r, c)
			if a:
				livres += 1
			if a != cen.celula_transitavel(cel):
				dif += 1
	checar(dif == 0 and livres > 6000, "colisão da cidade = walkable() do cliente, casa a casa", "%d diferentes, %d livres" % [dif, livres])
	checar(not cen.celula_transitavel(Vector2i(-2, -4)) and cen.motivos_bloqueio.get(Vector2i(-2, -4), []) == [8274],
		"(−2,−4) bloqueada pela peça invisível 8274, como no original")
	checar(cen.celula_transitavel(Vector2i(-3, -5)) and cen.celula_transitavel(Vector2i(-2, -5)) and cen.celula_transitavel(Vector2i(-3, -4)),
		"porta do Pokémon Center livre: (−3,−5), (−2,−5) e (−3,−4)")
	checar(cen.npcs.size() == 5 and not cen.npc("nurse").is_empty() and not cen.npc("pokedepot").is_empty(), "5 NPCs do city-npcs desenhados", str(cen.npcs.size()))
	cen.atualizar_cobertura(Vector2(-1, 2) * 32.0 + Vector2(16, 16))


func _process(_d: float) -> bool:
	quadros += 1
	var cen = get_root().get_meta("cen")
	if quadros == 3:
		_verificar(cen)
	if quadros < 30:
		return false
	checar(int(cen.mapa.perfil.get("animados", 0)) > 0, "decorações animadas no mapa (tickAnimations, C)", str(cen.mapa.perfil.get("animados", 0)))
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
