class_name InventarioJogo
extends RefCounted

# Dono dos estoques BAG/DEPOT e das transferências. Sem dependência de cenas.
signal estoque_bolas_alterado
signal estoque_pocoes_alterado
signal depot_alterado
signal alterado
const CATALOGO_POCOES: Array[Dictionary] = [
	{"id": 200, "nome": "Small Potion", "cura": 60, "icone": "small_potion"},
	{"id": 201, "nome": "Great Potion", "cura": 150, "icone": "great_potion"},
	{"id": 202, "nome": "Ultra Potion", "cura": 400, "icone": "ultra_potion"},
	{"id": 203, "nome": "Hyper Potion", "cura": 1000, "icone": "hyper_potion"},
	{"id": 204, "nome": "Ultimate Potion", "cura": 3000, "icone": "ultimate_potion"}
]
const CATALOGO_BOLAS: Array[Dictionary] = [
	{
		"id": 1, "nome": "Poké Ball", "catch_rate": 1,
		"preco": 5, "compravel": true,
		"infinita": false, "vinculada": false
	},
	{
		"id": 2, "nome": "Great Ball", "catch_rate": 2,
		"preco": 20, "compravel": true,
		"infinita": false, "vinculada": false
	},
	{
		"id": 3, "nome": "Super Ball", "catch_rate": 3,
		"preco": 50, "compravel": true,
		"infinita": false, "vinculada": false
	},
	{
		"id": 4, "nome": "Ultra Ball", "catch_rate": 4,
		"preco": 130, "compravel": true,
		"infinita": false, "vinculada": false
	},
	{
		"id": 6, "nome": "Idle Ball", "catch_rate": 5,
		"preco": 400, "compravel": false,
		"infinita": false, "vinculada": false
	},
	{
		"id": 7, "nome": "Golden Idle Ball", "catch_rate": 5,
		"preco": 400, "compravel": false,
		"infinita": true, "vinculada": true
	},
	{
		"id": 5, "nome": "Master Ball", "catch_rate": 255,
		"preco": 0, "compravel": false,
		"infinita": false, "vinculada": false
	}
]
const CAPACIDADE_DEPOT: int = 200
var estoque_pocoes: Dictionary[int, int] = {200: 20, 201: 5, 202: 3, 203: 2, 204: 1}
var estoque_bolas: Dictionary[int, int] = {
	1: 100,
	2: 10,
	3: 10,
	4: 0,
	5: 0,
	6: 0,
	7: 0
}
var itens_depot: Dictionary = {}
var estoque_materiais: Dictionary[int,int] = {}
const LOOT: Script = preload("res://regras_loot.gd")
var bola_selecionada: int = 1

func obter_dados_bola(id: int) -> Dictionary:
	for bola in CATALOGO_BOLAS:
		if int(bola["id"]) == id:
			return bola.duplicate(true) # Evolução: consulta não expõe o catálogo mutável.
	return {}

func obter_quantidade_bola(id: int) -> int:
	return int(estoque_bolas.get(id, 0))

func selecionar_bola(id: int) -> bool:
	if obter_dados_bola(id).is_empty():
		return false
	bola_selecionada = id
	alterado.emit()
	return true

func consumir_bola(id: int) -> bool:
	var dados: Dictionary = obter_dados_bola(id)
	if dados.is_empty():
		return false
	var quantidade: int = obter_quantidade_bola(id)
	if quantidade <= 0:
		return false
	if bool(dados["infinita"]):
		return true
	estoque_bolas[id] = quantidade - 1
	estoque_bolas_alterado.emit()
	return true

func obter_dados_pocao(id: int) -> Dictionary:
	for pocao in CATALOGO_POCOES:
		if int(pocao["id"]) == id:
			return pocao.duplicate(true) # Evolução: consulta não expõe o catálogo mutável.
	return {}

func obter_quantidade_pocao(id: int) -> int:
	return int(estoque_pocoes.get(id, 0))

func consumir_pocao(id: int) -> bool:
	if obter_dados_pocao(id).is_empty() or obter_quantidade_pocao(id) <= 0:
		return false
	estoque_pocoes[id] = obter_quantidade_pocao(id) - 1
	estoque_pocoes_alterado.emit()
	return true

func catalogo_itens_depot() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var icones: Dictionary = {1: "pokeball", 2: "greatball", 3: "superball", 4: "ultraball", 5: "masterball", 6: "idleball", 7: "idleball_gold"}
	for bola in CATALOGO_BOLAS:
		var id: int = int(bola["id"])
		resultado.append({"id": id, "nome": bola["nome"], "categoria": "Poké Balls", "icone": "res://assets/interface/depot/" + str(icones[id]) + ".png", "vinculado": bool(bola["vinculada"]) or bool(bola["infinita"])})
	for pocao in CATALOGO_POCOES:
		resultado.append({"id": pocao["id"], "nome": pocao["nome"], "categoria": "Potions", "icone": "res://assets/interface/pocoes/" + str(pocao["icone"]) + ".png", "vinculado": false})
	resultado.append_array(LOOT.catalogo())
	return resultado

func quantidade_item_bag(id: int) -> int:
	if not LOOT.obter(id).is_empty(): return int(estoque_materiais.get(id,0))
	return int(estoque_pocoes.get(id, 0)) if id >= 200 else int(estoque_bolas.get(id, 0))

# Evolução: planeja e valida toda a operação antes de modificar estoques.
const MAX_ESTOQUE: int = 2147483647
func _planejar_transferencia(id: int, guardar: bool) -> Dictionary:
	var dados: Dictionary = {}
	for item in catalogo_itens_depot():
		if int(item["id"]) == id:
			dados = item
			break
	if dados.is_empty():
		return {"erro":"Item desconhecido."}
	if bool(dados["vinculado"]):
		return {"erro":"Este item vinculado permanece na BAG."}
	var bag: int = quantidade_item_bag(id)
	var depot: Variant = itens_depot.get(id,0)
	if not depot is int or int(depot)<0 or int(depot)>MAX_ESTOQUE or bag<0 or bag>MAX_ESTOQUE:
		return {"erro":"Estoque inválido; transferência não realizada."}
	var quantidade: int = bag if guardar else int(depot)
	if quantidade <= 0:
		return {"erro":"Não há unidades para transferir."}
	var destino: int = int(depot) if guardar else bag
	if quantidade > MAX_ESTOQUE-destino:
		return {"erro":"A transferência excede o limite de estoque."}
	return {"id":id,"bag":0 if guardar else bag+quantidade,"depot":int(depot)+quantidade if guardar else 0}

func _aplicar_transferencia(plano: Dictionary) -> void:
	var id: int = int(plano["id"])
	if int(plano["depot"])==0:
		itens_depot.erase(id)
	else:
		itens_depot[id] = int(plano["depot"])
	if not LOOT.obter(id).is_empty():
		if int(plano["bag"])==0: estoque_materiais.erase(id)
		else: estoque_materiais[id]=int(plano["bag"])
	elif id>=200:
		estoque_pocoes[id] = int(plano["bag"])
	else:
		estoque_bolas[id] = int(plano["bag"])

func mover_item_depot(id: int, guardar: bool) -> String:
	var plano: Dictionary = _planejar_transferencia(id,guardar)
	if plano.has("erro"):
		return str(plano["erro"])
	if guardar and not itens_depot.has(id) and itens_depot.size()>=CAPACIDADE_DEPOT:
		return "Depot cheio."
	_aplicar_transferencia(plano)
	if not LOOT.obter(id).is_empty():
		alterado.emit()
	elif id>=200:
		estoque_pocoes_alterado.emit()
	else:
		estoque_bolas_alterado.emit()
	depot_alterado.emit()
	return ""

func guardar_todos_itens_depot() -> String:
	var planos: Array[Dictionary] = []
	var novas_pilhas: int = 0
	var bolas: bool = false
	var pocoes: bool = false
	for item in catalogo_itens_depot():
		var id: int = int(item["id"])
		if bool(item["vinculado"]) or quantidade_item_bag(id)<=0:
			continue
		var plano: Dictionary = _planejar_transferencia(id,true)
		if plano.has("erro"):
			return str(plano["erro"])
		planos.append(plano)
		if not itens_depot.has(id):
			novas_pilhas += 1
		bolas = bolas or (id<200 and LOOT.obter(id).is_empty())
		pocoes = pocoes or (id>=200 and LOOT.obter(id).is_empty())
	if planos.is_empty():
		return "Nenhum item transferível na BAG."
	if itens_depot.size()+novas_pilhas>CAPACIDADE_DEPOT:
		return "Depot cheio: nenhum item foi transferido."
	# Sem sinais/await entre mutações: observadores recebem o lote concluído.
	for plano in planos:
		_aplicar_transferencia(plano)
	if bolas:
		estoque_bolas_alterado.emit()
	if pocoes:
		estoque_pocoes_alterado.emit()
	depot_alterado.emit()
	return "Itens guardados."

# Valida o lote inteiro antes de conceder; o evento recebe somente o aplicado.
func receber_loot(itens: Array[Dictionary]) -> Array[Dictionary]:
	var somas: Dictionary={}
	for item in itens:
		var id: int=int(item.get("itemId",-1))
		var qtd: int=int(item.get("qty",0))
		if LOOT.obter(id).is_empty() or qtd<=0: return []
		somas[id]=int(somas.get(id,0))+qtd
		if int(somas[id])>MAX_ESTOQUE-quantidade_item_bag(id): return []
	for id in somas: estoque_materiais[int(id)]=quantidade_item_bag(int(id))+int(somas[id])
	if not somas.is_empty():
		alterado.emit()
		depot_alterado.emit()
	return itens.duplicate(true)
