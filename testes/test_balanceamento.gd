extends SceneTree
## Classe 3 em dados/balanceamento.json (ESTRATEGIA.md): toda chave tem valor e motivo de uma linha, existe nos PARAMETROS
## do módulo que a usa (ou é lida por ele), e mudar o valor no JSON muda o comportamento.
## Rodar: testes/rodar.sh res://testes/test_balanceamento.gd

const B := preload("res://sim/balanceamento.gd")
const Regras := preload("res://sim/regras.gd")
const Cidade := preload("res://sim/servico_cidade.gd")
const Diarias := preload("res://sim/servico_diarias.gd")
const Jogador := preload("res://sim/servico_jogador.gd")
const NovoJogo := preload("res://sim/servico_novo_jogo.gd")
const Apresentacao := preload("res://sim/regras_apresentacao.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _init() -> void:
	var d := B.dados()
	checar(not d.is_empty(), "dados/balanceamento.json lido")
	var sem_motivo: Array = []
	for sec in d:
		if String(sec).begins_with("_"):
			continue
		for k in d[sec]:
			var e = d[sec][k]
			if not (e is Dictionary and e.has("valor") and String(e.get("motivo", "")).length() >= 10):
				sem_motivo.append("%s.%s" % [sec, k])
	checar(sem_motivo.is_empty(), "toda chave tem valor e motivo", str(sem_motivo))
	var dados = DadosJogo.carregar()
	var alvos := {"combate": Regras.PARAMETROS, "cidade": Cidade.new(dados).p, "diarias": Diarias.new(dados).p, "jogador": Jogador.new().p}
	var orfas: Array = []
	for sec in alvos:
		for k in B.secao(sec):
			if not alvos[sec].has(k):
				orfas.append("%s.%s" % [sec, k])
	checar(orfas.is_empty(), "toda chave existe nos PARAMETROS do módulo que a usa", str(orfas))
	checar(Cidade.new(dados).p["capacidade_depot_pilhas"] == B.valor("cidade", "capacidade_depot_pilhas"), "o serviço da cidade usa o valor do JSON")
	# mudar o JSON muda o jogo (dados injetados no leitor)
	var original := d.duplicate(true)
	d["cidade"]["capacidade_depot_pilhas"]["valor"] = 7
	d["jogo_novo"]["ouro_inicial"]["valor"] = 123
	d["apresentacao"]["cartoes_por_instancia"]["valor"] = 2
	checar(Cidade.new(dados).p["capacidade_depot_pilhas"] == 7, "depot: 7 pilhas no JSON → 7 no serviço")
	checar(int(NovoJogo.criar(74, 1)["ouro"]) == 123, "jogo novo: ouro inicial vem do JSON")
	var ap = Apresentacao.new()
	var n := 0
	for i in 5:
		if ap.mostrar_cartao({"shiny": false}, i * 100000):
			n += 1
	checar(n == 2, "cartões: no máximo 2 por instância com o JSON pedindo 2", "%d" % n)
	B._dados = original
	checar(Cidade.new(dados).p["capacidade_depot_pilhas"] == 200, "de volta ao valor do arquivo")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
