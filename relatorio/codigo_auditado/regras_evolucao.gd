extends RefCounted
# Destinos e níveis de creatures.json fornecido. Cidade/ausência de custo são política local.
const LINHAS={"Larvitar":{"nome":"Pupitar","nivel":60},"Pupitar":{"nome":"Tyranitar","nivel":100},"Geodude":{"nome":"Graveler","nivel":40},"Graveler":{"nome":"Golem","nivel":80}}
static func obter(nome: String) -> Dictionary: return LINHAS.get(nome,{}).duplicate(true)
