extends RefCounted

# Paleta TYPE_COLOR e assets /types e /elements do cliente extraído.
# Pedra (ROCK) e Terra (GROUND) têm símbolos e cores distintos.
const CORES: Dictionary[String,Color] = {
	"NORMAL":Color("9099a1"),"FIRE":Color("ff9d55"),"WATER":Color("4d90d5"),
	"GRASS":Color("63bc5a"),"ELECTRIC":Color("f4d23c"),"ICE":Color("74cec0"),
	"FIGHTING":Color("ce4069"),"POISON":Color("ab6ac8"),"GROUND":Color("d97845"),
	"FLYING":Color("8fa9de"),"PSYCHIC":Color("f97176"),"BUG":Color("90c12c"),
	"ROCK":Color("c7b78b"),"GHOST":Color("5269ad"),"DRAGON":Color("0b6dc3"),
	"DARK":Color("5a5366"),"STEEL":Color("5a8ea1"),"FAIRY":Color("ec8fe6")
}
static var _icones: Dictionary[String,Texture2D] = {}
static var _elementos: Dictionary[String,Texture2D] = {}
static func normalizar(tipo: String) -> String:
	var chave: String = tipo.to_upper()
	return chave if CORES.has(chave) else "NORMAL"
static func cor(tipo: String) -> Color:
	return CORES[normalizar(tipo)]
static func primario(pokemon: DadosPokemon) -> String:
	return str(preload("res://regras_pokemon.gd").obter_base(pokemon.especie.nome).get("type1","NORMAL"))
static func icone(tipo: String) -> Texture2D:
	var chave: String = normalizar(tipo)
	if not _icones.has(chave):
		_icones[chave] = load("res://assets/interface/tipos/"+chave.to_lower()+".png")
	return _icones[chave]
static func elemento(tipo: String) -> Texture2D:
	var chave: String = normalizar(tipo)
	if not _elementos.has(chave):
		var caminho: String = "res://assets/interface/elementos/"+chave.to_lower()+".png"
		# Há 18 insígnias pequenas, mas só três marcas d'água no material
		# extraído. Ausência não deve carregar outro tipo nem produzir erro.
		_elementos[chave] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _elementos[chave]
