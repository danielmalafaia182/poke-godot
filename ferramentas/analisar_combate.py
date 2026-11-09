"""Analisa registro local e mensagens JSON do original sem inferir regras desconhecidas.
Exemplo: python analisar_combate.py local.jsonl --original original.json --saida comparacao.json
"""
import argparse,json,collections,statistics
from pathlib import Path

def carregar(p):
 s=Path(p).read_text(encoding='utf-8-sig')
 try:v=json.loads(s)
 except json.JSONDecodeError:
  v=[]
  for n,l in enumerate(s.splitlines(),1):
   if not l.strip():continue
   try:v.append(json.loads(l))
   except json.JSONDecodeError as e:raise ValueError(f'Linha {n} inválida: use apenas JSON, sem texto de console.') from e
 if isinstance(v,dict):v=[v]
 if not isinstance(v,list) or any(not isinstance(x,dict) for x in v):raise ValueError('Esperado objeto JSON, lista de objetos ou JSONL.')
 return v

def local(registros):
 sessoes=[r for r in registros if r.get('tipo')=='sessao']
 if len(sessoes)!=1:raise ValueError('Registro local deve conter exatamente uma sessão.')
 golpes=[r for r in registros if r.get('tipo')=='golpe'];grupos=collections.defaultdict(list);nomes=collections.Counter()
 for r in golpes:
  e=r['dados'];chave='aliado' if e['aliado'] else 'selvagem:'+str(e['encontro_id'])
  grupos[chave].append(float(e['tempo_atacante']));nomes[e['nome']]+=1
 intervalos={}
 for nome,ts in grupos.items():
  ds=[round(b-a,6) for a,b in zip(ts,ts[1:])]
  intervalos[nome]={'ataques':len(ts),'intervalos_s':ds,'mediana_s':statistics.median(ds) if ds else None}
 estados=[r['dados'] for r in registros if r.get('tipo')=='estado']
 return {'configuracao':sessoes[0]['dados'],'ataques':len(golpes),'golpes':dict(nomes),'cadencia_por_atacante':intervalos,'estado_inicial':estados[0] if estados else None,'fim_presente':any(r.get('tipo')=='fim' for r in registros),'limite_atingido':any(r.get('tipo')=='fim' and r['dados'].get('limite_atingido') for r in registros)}

def original(registros):
 tipos=collections.Counter();chaves_hits=collections.Counter();mobs=collections.defaultdict(list);hero=[];tempos=[];hits=0;eventos=[]
 for r in registros:
  tipos[str(r.get('type','desconhecido'))]+=1
  if r.get('type')!='field':continue
  if isinstance(r.get('serverNow'),(int,float)):tempos.append(r['serverNow'])
  if isinstance(r.get('heroHp'),(int,float)):hero.append(r['heroHp'])
  for m in r.get('mobs',[]):
   if isinstance(m,dict) and isinstance(m.get('maxHp'),(int,float)):mobs[str(m.get('speciesId','?'))].append(m['maxHp'])
  for h in r.get('hits',[]):
   hits+=1
   if isinstance(h,dict):
    chaves_hits.update(h.keys())
    slot=h.get('slot')
    eventos.append({'serverNow':r.get('serverNow'),'seq':r.get('seq'),'alvo':'aliado' if slot==-1 else ('selvagem' if isinstance(slot,int) and slot>=0 else 'desconhecido'),'slot_alvo':slot,'atacante':None,'amount':h.get('amount'),'move':h.get('move'),'eff':h.get('eff'),'crit':h.get('crit'),'blocked':h.get('blocked'),'fx':h.get('fx'),'fx2':h.get('fx2'),'fxHit':h.get('fxHit'),'fxHit2':h.get('fxHit2'),'dmgDelayMs':h.get('dmgDelayMs'),'raw':h})
   else:chaves_hits['tipo:'+type(h).__name__]+=1
 return {'mensagens':len(registros),'tipos':dict(tipos),'hits_observados':hits,'campos_hits':dict(chaves_hits),'hits_normalizados':eventos,'hp_maximo_por_speciesId':{k:sorted(set(v)) for k,v in mobs.items()},'hp_aliado_observado':hero,'serverNow':tempos,'aviso':'Variação de HP não é dano bruto: pode incluir cura e múltiplos golpes. Mapeamento de apresentação conferido no cliente extraído: slot identifica o alvo. Não inferimos atacante/cadência individual pela posição na lista.'}

def comparar(a,b=None):
 r={'schema':1,'fidelidade_comprovada':False,'local':local(a),'original':original(b) if b is not None else None,'pendencias':['Validar correspondência entre speciesId e looktype.','Confirmar identidade do atacante quando ausente em hits; slot é alvo, não origem.','Conferir atributos/bônus do aliado nas duas amostras.','Medir HP, dano, cadência, alcance e seleção de golpes separadamente.']}
 if b is not None and not r['original']['hits_observados']:r['pendencias'].append('Amostra original não contém hits; não permite validar dano ou cadência.')
 return r
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('local',type=Path);p.add_argument('--original',type=Path);p.add_argument('--saida',type=Path,default=Path('comparacao_combate.json'));a=p.parse_args()
 try:r=comparar(carregar(a.local),carregar(a.original) if a.original else None)
 except (ValueError,OSError,KeyError) as e:p.exit(2,f'Falha na análise: {e}\n')
 a.saida.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');print(a.saida)
