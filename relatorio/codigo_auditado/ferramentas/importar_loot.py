"""Gera tabelas a partir das extrações locais. Python 3 + Pillow (GIF -> PNG estático)."""
import json,shutil,argparse
from pathlib import Path
from PIL import Image

def executar(origem,p):
 itens=json.loads((origem/'stage3/poke-local/public/game/items.json').read_text())['items']
 criaturas=json.loads((p/'dados/importados/catalogo_fonte.json').read_text())
 nomes={}
 for item in itens:nomes.setdefault(item['name'],[]).append(item)
 arquivos={}
 for f in sorted(origem.rglob('*')):
  if f.is_file():arquivos.setdefault(f.name,[]).append(f)
 antigo=json.loads((p/'dados/referencias/loot_geodude.json').read_text())['itens']
 catalogo={int(x['id']):x for x in antigo};tabelas={'Geodude':antigo};pendencias=[]
 hunts=json.loads((p/'dados/caca/hunts.json').read_text())
 for c in criaturas:
  if c['name'] not in hunts or c['name']=='Geodude':continue
  tabela=[]
  for drop in c.get('loot',[]):
   candidatos=nomes.get(drop['name'],[])
   if len(candidatos)!=1:
    pendencias.append({'especie':c['name'],'drop':drop['name'],'motivo':'ID ausente ou ambíguo'});continue
   item=candidatos[0];id_original=int(item['id']);id_local=1000000+id_original if id_original in [1,2,3,4,5,6,7,200,201,202,203,204] else id_original
   icone=str(item.get('icon',''));caminhos=arquivos.get(Path(icone).name,[])
   if icone.startswith('/'):
    exatos=[f for f in caminhos if str(f).endswith(icone)]
    if exatos:caminhos=exatos
   if not caminhos and id_local in catalogo:
    existente=p/catalogo[id_local]['icone'].removeprefix('res://')
    if existente.exists(): caminhos=[existente]
   local=p/'assets/interface/loot/importados'/f'{id_original}.png'
   if not caminhos and local.exists(): caminhos=[local]
   if not caminhos:
    pendencias.append({'especie':c['name'],'drop':drop['name'],'motivo':'Ícone não disponível; marcador neutro utilizado'})
   if not (0<=float(drop['chance'])<=100000 and 1<=int(drop['minCount'])<=int(drop['maxCount'])):
    pendencias.append({'especie':c['name'],'drop':drop['name'],'motivo':'Probabilidade ou quantidade inválida'});continue
   if id_local not in catalogo:
    target=p/'assets/interface/loot/importados'/f'{id_original}.png';target.parent.mkdir(parents=True,exist_ok=True)
    if caminhos: Image.open(caminhos[0]).convert('RGBA').save(target)
    catalogo[id_local]={'id':id_local,'id_original':id_original,'nome':item['name'],'categoria':'Materials','icone':('res://assets/interface/loot/importados/'+target.name if caminhos else 'res://assets/interface/loot/icone_pendente.svg'),'vinculado':False,'raro':bool(item.get('rare',False))}
   r=dict(catalogo[id_local]);r.update(chance_catalogo=float(drop['chance']),minimo=int(drop['minCount']),maximo=int(drop['maxCount']));tabela.append(r)
  tabelas[c['name']]=tabela
 dados={'denominador':100000,'fonte':'creatures.json + items.json fornecidos; rolagens independentes locais','itens':list(catalogo.values()),'especies':tabelas}
 (p/'dados/referencias/loot_hunts.json').write_text(json.dumps(dados,ensure_ascii=False,indent=2))
 relatorio={'especies':len(tabelas),'itens':len(catalogo),'drops_mapeados':sum(map(len,tabelas.values())),'pendencias':pendencias,'aliases_colisao':[x for x in catalogo.values() if x.get('id_original',x['id'])!=x['id']]}
 (p/'relatorio_loot.json').write_text(json.dumps(relatorio,ensure_ascii=False,indent=2))
 print({k:v for k,v in relatorio.items() if k not in ['pendencias','aliases_colisao']},'pendencias',len(pendencias))
if __name__=='__main__':
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--origem',type=Path,required=True);a.add_argument('--projeto',type=Path,required=True);n=a.parse_args();executar(n.origem,n.projeto)
