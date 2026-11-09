extends RefCounted
# Curva LOCAL substituível; a fórmula completa do servidor não foi publicada.
# Espécie, IVs, nível e qualidade entram pelos atributos já calculados no cliente.
const CATALOGO: Script=preload("res://catalogo_golpes.gd")
static func amplificar_elemento(fator: float) -> float:
	if fator<=0 or is_equal_approx(fator,1.0): return fator
	return 1.0+(fator-1.0)*1.5 if fator>1 else fator/1.5
static func efetividade(golpe: Dictionary, defensor: DadosPokemon) -> float:
	var b: Dictionary=defensor.especie.obter_base()
	return amplificar_elemento(CATALOGO.efetividade(str(golpe.get("type","NORMAL")),str(b.get("type1","")),str(b.get("type2",""))))
static func calcular(atacante: DadosPokemon, defensor: DadosPokemon, golpe: Dictionary, selvagem: bool=false, calibrado: bool=true) -> int:
	var categoria: String=str(golpe.get("category","PHYSICAL")).to_upper()
	var poder: int=int(golpe.get("power",0))
	if categoria not in ["PHYSICAL","SPECIAL"] or poder<=0: return 0
	var a: Dictionary=atacante.obter_atributos()
	var d: Dictionary=defensor.obter_atributos()
	if a.is_empty() or d.is_empty(): return 0
	return calcular_atributos(atacante.nivel,a,d,golpe,efetividade(golpe,defensor),selvagem,calibrado)

# A mesma curva usada na caça recebe snapshots independentes no laboratório.
# A extração não muda a fórmula, os pisos ou os multiplicadores existentes.
static func calcular_atributos(nivel: int, a: Dictionary, d: Dictionary, golpe: Dictionary, fator: float, selvagem: bool=false, calibrado: bool=true) -> int:
	return finalizar_dano(calcular_bruto_atributos(nivel,a,d,golpe,fator,selvagem,calibrado),selvagem,calibrado)

# Valor contínuo anterior ao arredondamento. Nenhuma sorte/variação é aplicada na caça.
static func finalizar_dano(bruto: float, selvagem: bool=false, calibrado: bool=true) -> int:
	if not is_finite(bruto) or bruto<=0:return 0
	return maxi(2 if calibrado and not selvagem else 1,roundi(bruto))

static func calcular_bruto_atributos(nivel: int, a: Dictionary, d: Dictionary, golpe: Dictionary, fator: float, selvagem: bool=false, calibrado: bool=true) -> float:
	var categoria: String=str(golpe.get("category","PHYSICAL")).to_upper()
	var poder: int=int(golpe.get("power",0))
	if categoria not in ["PHYSICAL","SPECIAL"] or poder<=0 or nivel<1 or not is_finite(fator) or fator<=0:return 0
	var ataque_chave: String="spAtk" if categoria=="SPECIAL" else "atk"
	var defesa_chave: String="spDef" if categoria=="SPECIAL" else "def"
	if not a.has(ataque_chave) or not d.has(defesa_chave):return 0
	var atk: float=maxf(1,float(a[ataque_chave]))
	var defesa: float=maxf(1,float(d[defesa_chave]))
	if not is_finite(atk) or not is_finite(defesa):return 0
	var base: float=((2.0*nivel/5.0+2.0)*poder*atk/defesa)/50.0+2.0
	return base*fator*(1.8 if selvagem and not calibrado else 1.0)
