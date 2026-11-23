extends RefCounted
## Pesca (ciclo 8). Puro e determinístico; tratar(estado, cmd) → mensagens.
##
## Do cliente (C, window.fishing.* e o componente fish-tier): o Pescador fica na cidade (A: city-npcs "fishing" em (7, −10));
## habilidade de Pesca com nível; faixas {id, minSkill, natural, mobLevel [mín, máx], fish [{dex, name, looktype}]}; faixas
## com skill maior que a sua ficam trancadas; a faixa da sua skill dá progresso cheio, uma faixa menor 50%; há recarga
## entre pescas ("⏳ Aguarde Ns") e a onda de pesca ("Pescando… Ns"); "{{inLevel}}/{{forNext}} peixes para o próximo nível";
## nível máximo.
## Medido (A, /api/game/profile): fishingSkill 4 com fishForNext 12 → peixes para subir = 3 × nível (classe 3 fora daí).
## Classe 3 (balanceamento.json "pesca", padrões abaixo): faixas e espécies (de água, do snapshot), duração da onda e da
## recarga, nível máximo; cada peixe vale um abate da espécie no nível sorteado da faixa: loot pela tabela (A) e XP do
## treinador = experience da espécie (A); E: a onda é abstrata (sem luta), o peixe sempre vem.
##
## Estado: pesca {skill, progresso (peixes, frações de 0,5), prox_ms (recarga), peixes_total}.
## Comandos: pesca-get; pescar {faixa, agora_ms, semente} → {peixe, nivel, loot, xp, skill, subiu, progresso, forNext}.

const Balanceamento := preload("res://sim/balanceamento.gd")
const Rng := preload("res://sim/rng.gd")

var p := {
	"faixas": [
		{"minSkill": 1, "mobLevel": [5, 15], "fish": ["Magikarp", "Goldeen", "Poliwag"]},
		{"minSkill": 10, "mobLevel": [20, 35], "fish": ["Horsea", "Krabby", "Tentacool"]},
		{"minSkill": 20, "mobLevel": [40, 60], "fish": ["Staryu", "Shellder", "Seel"]},
		{"minSkill": 35, "mobLevel": [70, 100], "fish": ["Seaking", "Kingler", "Poliwhirl"]},
		{"minSkill": 50, "mobLevel": [110, 150], "fish": ["Starmie", "Cloyster", "Dewgong"]},
		{"minSkill": 70, "mobLevel": [160, 220], "fish": ["Tentacruel", "Seadra", "Lanturn"]},
		{"minSkill": 90, "mobLevel": [240, 320], "fish": ["Lapras", "Kingdra", "Gyarados"]},
	],
	"skill_max": 100,
	"peixes_por_nivel": 3,       # A: skill 4 → 12
	"onda_s": 10,
	"recarga_s": 30,
}
var dados
var _faixas: Array = []


func _init(dados_jogo) -> void:
	dados = dados_jogo
	var b: Dictionary = Balanceamento.secao("pesca")
	for k in b:
		p[k] = b[k]
	var por_nome := {}
	for k in dados.especies:
		por_nome[String(dados.especies[k]["nome"])] = int(k)
	for i in (p.faixas as Array).size():
		var f: Dictionary = p.faixas[i]
		var peixes: Array = []
		for n in f["fish"]:
			if por_nome.has(String(n)):
				var sid: int = por_nome[String(n)]
				peixes.append({"dex": sid, "name": String(n), "looktype": int(dados.especies[sid].get("looktype", 0))})
		_faixas.append({"id": i, "minSkill": int(f["minSkill"]), "mobLevel": f["mobLevel"], "fish": peixes})


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


func _est(estado: Dictionary) -> Dictionary:
	if not estado.has("pesca"):
		estado["pesca"] = {}
	var e: Dictionary = estado["pesca"]
	for k in [["skill", 1], ["progresso", 0.0], ["prox_ms", 0], ["peixes_total", 0]]:
		if not e.has(k[0]):
			e[k[0]] = k[1]
	return e


func for_next(skill: int) -> int:
	return int(p.peixes_por_nivel) * skill


func faixa_natural(skill: int) -> int:
	var n := 0
	for f in _faixas:
		if skill >= int(f["minSkill"]):
			n = int(f["id"])
	return n


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	var e := _est(estado)
	match String(cmd.get("type", "")):
		"pesca-get":
			return [_msg(e, int(cmd.get("agora_ms", 0)))]
		"pescar":
			return _pescar(estado, e, int(cmd.get("faixa", 0)), int(cmd.get("agora_ms", 0)), int(cmd.get("semente", 1)))
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


func _pescar(estado: Dictionary, e: Dictionary, faixa: int, agora_ms: int, semente: int) -> Array:
	if faixa < 0 or faixa >= _faixas.size():
		return [_erro("Faixa inválida.")]
	var f: Dictionary = _faixas[faixa]
	var skill := int(e["skill"])
	if skill < int(f["minSkill"]):
		return [_erro("Requer Pesca Nv %d" % int(f["minSkill"]))]   # C: tierLockedTitle
	if agora_ms < int(e["prox_ms"]):
		return [_erro("⏳ Aguarde %ds" % ceili(float(int(e["prox_ms"]) - agora_ms) / 1000.0))]   # C: cooldownBtn
	var rng = Rng.new(semente)
	var peixe: Dictionary = f["fish"][int(rng.randf() * (f["fish"] as Array).size()) % (f["fish"] as Array).size()]
	var lv: Array = f["mobLevel"]
	var nivel := int(lv[0]) + int(rng.randf() * (int(lv[1]) - int(lv[0]) + 1))
	var esp: Dictionary = dados.especie(int(peixe["dex"]))
	var loot: Array = []
	for l in esp.get("loot", []):
		if l.get("itemId") != null and rng.randf() * 100000.0 < float(l.get("chanceBruta", 0.0)):
			var q: int = int(l.get("min", 1)) + int(rng.randf() * (int(l.get("max", 1)) - int(l.get("min", 1)) + 1))
			loot.append({"itemId": int(l["itemId"]), "name": String(l.get("item", "")), "qty": q})
			estado["itens"][str(int(l["itemId"]))] = int(estado["itens"].get(str(int(l["itemId"])), 0)) + q
	var xp := int(esp.get("xpAbate", 0))
	# C: faixa da sua skill → progresso cheio; faixa menor → 50%
	e["progresso"] = float(e["progresso"]) + (1.0 if faixa == faixa_natural(skill) else 0.5)
	e["peixes_total"] = int(e["peixes_total"]) + 1
	var subiu := false
	while skill < int(p.skill_max) and float(e["progresso"]) >= float(for_next(skill)):
		e["progresso"] = float(e["progresso"]) - float(for_next(skill))
		skill += 1
		subiu = true
	if skill >= int(p.skill_max):
		e["progresso"] = 0.0
	e["skill"] = skill
	e["prox_ms"] = agora_ms + (int(p.onda_s) + int(p.recarga_s)) * 1000
	return [{"type": "fishing-result", "peixe": peixe, "nivel": nivel, "loot": loot, "xp": xp, "skill": skill, "subiu": subiu,
		"progresso": float(e["progresso"]), "forNext": for_next(skill), "ondaS": int(p.onda_s)}]


func _msg(e: Dictionary, agora_ms: int) -> Dictionary:
	var skill := int(e["skill"])
	var nat := faixa_natural(skill)
	var fx: Array = []
	for f in _faixas:
		fx.append({"id": int(f["id"]), "minSkill": int(f["minSkill"]), "mobLevel": f["mobLevel"], "fish": f["fish"],
			"natural": int(f["id"]) == nat, "locked": skill < int(f["minSkill"])})
	return {"type": "fishing", "skill": skill, "inLevel": float(e["progresso"]), "forNext": for_next(skill), "max": skill >= int(p.skill_max),
		"cooldownS": maxi(0, ceili(float(int(e["prox_ms"]) - agora_ms) / 1000.0)), "tiers": fx}
