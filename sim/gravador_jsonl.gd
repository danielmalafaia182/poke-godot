extends RefCounted
## Escreve a saída da simulação no formato do gravador (`{sessao, t, dir, msg}` por linha),
## para rodar o mesmo ferramentas/gravador/analisar_gravacao.py usado nas gravações reais.

const Json := preload("res://sim/json_canonico.gd")

var sessao: String = ""
var linhas := PackedStringArray()


func _init(nome_sessao: String) -> void:
	sessao = nome_sessao


func adicionar(mensagens: Array, direcao: String = "in") -> void:
	for e in mensagens:
		linhas.append(Json.texto({"sessao": sessao, "t": e["t"], "dir": direcao, "msg": e["msg"]}))


func texto() -> String:
	return "\n".join(linhas) + ("\n" if linhas.size() > 0 else "")


func salvar(caminho: String) -> bool:
	DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		push_error("Não foi possível escrever " + caminho)
		return false
	f.store_string(texto())
	f.close()
	return true
