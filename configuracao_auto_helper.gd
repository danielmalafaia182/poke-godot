class_name ConfiguracaoAutoHelper
extends RefCounted

signal auto_catch_alterado
signal auto_potion_alterado
var inventario: InventarioJogo
const LIMITES_AUTO_POTION: Array[int] = [25, 40, 50, 60, 75, 90]
var auto_potion: bool = true
var auto_potion_threshold: int = 50
var auto_potion_item_id: int = 200
var auto_catch: bool = true
var auto_catch_ball_id: int = 1
var auto_catch_names: String = ""
# C (Auto-Helper): Auto-Catch Shiny com bola própria. Decisão do usuário (ciclo 2): ligado. Bola 0 = a melhor que tiver (E).
var auto_catch_shiny: bool = true
var auto_catch_shiny_ball_id: int = 0
const ORDEM_BOLA_SHINY: Array[int] = [7, 6, 4, 3, 2, 1]   # Golden Idle, Idle, Ultra, Super, Great, Poké (catchRate C)

func definir_auto_catch_shiny(ativo: bool) -> void:
	auto_catch_shiny = ativo
	auto_catch_alterado.emit()

func bola_shiny_efetiva() -> int:
	## A bola que o Auto-Catch Shiny vai jogar: a escolhida, ou a de maior catchRate com estoque.
	if auto_catch_shiny_ball_id != 0:
		return auto_catch_shiny_ball_id
	for id in ORDEM_BOLA_SHINY:
		if inventario != null and inventario.obter_quantidade_bola(id) > 0:
			return id
	return 0

func definir_auto_catch(ativo: bool) -> void:
	auto_catch = ativo
	auto_catch_alterado.emit()

func selecionar_bola_auto_catch(id: int) -> bool:
	if id == 5 or inventario.obter_dados_bola(id).is_empty():
		return false
	auto_catch_ball_id = id
	auto_catch_alterado.emit()
	return true

func definir_nomes_auto_catch(nomes: String) -> void:
	auto_catch_names = nomes
	auto_catch_alterado.emit()

func nome_permitido_auto_catch(nome: String) -> bool:
	if auto_catch_names.strip_edges().is_empty():
		return true
	var nome_normalizado: String = nome.strip_edges().to_lower()
	for entrada in auto_catch_names.split(",", false):
		var candidato: String = entrada.strip_edges().to_lower()
		if not candidato.is_empty() and candidato == nome_normalizado:
			return true
	return false

func definir_auto_potion(ativo: bool) -> void:
	auto_potion = ativo
	auto_potion_alterado.emit()

func definir_limite_auto_potion(percentual: int) -> bool:
	if not LIMITES_AUTO_POTION.has(percentual):
		return false
	auto_potion_threshold = percentual
	auto_potion_alterado.emit()
	return true

func selecionar_pocao_auto_potion(id: int) -> bool:
	if id != 0 and inventario.obter_dados_pocao(id).is_empty():
		return false
	auto_potion_item_id = id
	auto_potion_alterado.emit()
	return true

func escolher_pocao_auto_potion() -> int:
	if auto_potion_item_id != 0:
		if not inventario.obter_dados_pocao(auto_potion_item_id).is_empty():
			if inventario.obter_quantidade_pocao(auto_potion_item_id) > 0:
				return auto_potion_item_id
		# Regra do protótipo: seleção específica não troca de item ao esgotar.
		return -1
	# Regra PROVISÓRIA: automático escolhe a maior cura disponível,
	# mesmo que falte pouco HP. Não é a fórmula comprovada do original.
	var escolhido: int = -1
	var maior_cura: int = 0
	for pocao in InventarioJogo.CATALOGO_POCOES:
		var id: int = int(pocao["id"])
		var cura: int = int(pocao["cura"])
		if inventario.obter_quantidade_pocao(id) > 0 and cura > maior_cura:
			escolhido = id
			maior_cura = cura
	return escolhido
