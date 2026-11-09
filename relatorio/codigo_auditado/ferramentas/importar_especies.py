"""Importador offline. Sem --aplicar, produz somente relatório de disponibilidade.
Python 3, biblioteca padrão. --origem aponta a pasta das extrações; --projeto a raiz Godot.
"""
import argparse,json,re,shutil
from pathlib import Path

def executar(origem,projeto,aplicar=False):
    arquivos=sorted(origem.rglob('*'))
    paginas={p.name:p for p in arquivos if p.is_file() and p.suffix=='.webp'}
    fontes=[p for p in arquivos if p.name=='creatures.json']
    if not fontes: raise ValueError('creatures.json ausente')
    criaturas=max((json.loads(p.read_text())['creatures'] for p in fontes),key=len)
    categorias={}
    for p in arquivos:
        if p.is_file() and re.match(r'outfits-male-\d+-.*\.json$',p.name):
            d=json.loads(p.read_text())
            for cat,c in d.get('categories',{}).items():
                categorias.setdefault(int(cat.split('/')[-1]),[]).append((d,c))
    mapa=json.loads((projeto/'dados/referencias/mapa_kanto.json').read_text())['hunts']
    alvos={m['name']:m for m in mapa if m['level']>0}
    aprovados={};pendentes=[]
    for c in criaturas:
        nome=c['name']
        if nome not in alvos: continue
        motivo='Sprites completos não encontrados'
        if any(c.get(k,0)<=0 for k in ['baseHp','baseAtk','baseDef','baseSpAtk','baseSpDef','baseSpeed']):
            pendentes.append({'nome':nome,'motivo':'Atributos incompletos'});continue
        nivel_encontro=1
        if not any(a.get('power',0)>0 and (a.get('learnLevel',999)<=nivel_encontro or (nome=='Togepi' and a.get('name')=='Last Resort')) for a in c.get('attacks',[])):
            pendentes.append({'nome':nome,'motivo':'Sem golpe ofensivo no nível provisório 1'});continue
        for d,cat in categorias.get(c['looktype'],[]):
            g=cat['geometry'];n=g['frames']
            if g['directions']!=4 or g['layers']!=1:continue
            frames=[];valido=True
            for direcao in range(1,5):
                for quadro in range(1,n+1):
                    a=d.get('assets',{}).get(f"/assets/outfits/male/{c['looktype']}/{quadro}_1_1_{direcao}.png",{})
                    fs=a.get('frames',[])
                    if len(fs)!=1:valido=False;break
                    f=fs[0];page=cat['pages'][f['page']];pagina=paginas.get(Path(page['image']).name)
                    if pagina is None or f['x']+f['w']>page['width'] or f['y']+f['h']>page['height']:valido=False;break
                    frames.append({'arquivo':pagina.name,'rect':[f['x'],f['y'],f['w'],f['h']]})
                if not valido:break
            if valido:
                aprovados[nome]={'criatura':c,'quadros':n,'frames':frames};break
        if nome not in aprovados:pendentes.append({'nome':nome,'motivo':motivo})
    relatorio={'catalogo_criaturas':len(criaturas),'destinos_pokemon_kanto':len(alvos),'aprovados':sorted(aprovados),'pendentes':pendentes,'regras_provisorias':['Cenário e navegação do Geodude','Nível de combate usa nível de acesso como proxy local; não confirmado no servidor','Bônus VIP não inferido para espécies novas','Loot novo desabilitado; tabela bruta preservada para investigação','Efeitos/status dos golpes mantêm implementação atual']}
    (projeto/'relatorio_importacao.json').write_text(json.dumps(relatorio,ensure_ascii=False,indent=2))
    if not aplicar:return relatorio
    pasta=projeto/'dados/importados';pasta.mkdir(exist_ok=True)
    visual={};recursos={};hunts=json.loads((projeto/'dados/caca/hunts.json').read_text());modelo=hunts['Geodude']
    golpes=json.loads((projeto/'dados/combate/golpes_originais.json').read_text())
    bases=json.loads((projeto/'assets/interface/hud/atributos_base.json').read_text())
    for nome,a in aprovados.items():
        c=a['criatura'];slug=alvos[nome]['slug'];destino=f'res://dados/importados/{slug}.tres'
        if nome in ['Geodude','Larvitar']:
            recursos[nome]=f'res://dados/especies/{nome.lower()}.tres'
        else:
            for frame in a['frames']:
                target=projeto/'assets/pokemon/importados'/frame['arquivo'];target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(paginas[frame['arquivo']],target)
            visual[nome]={'quadros':a['quadros'],'frames':[{'arquivo':'res://assets/pokemon/importados/'+f['arquivo'],'rect':f['rect']} for f in a['frames']]}
            f=a['frames'][a['quadros']*2];rect=f['rect'];textura='res://assets/pokemon/importados/'+f['arquivo']
            s='[gd_resource type="Resource" format=3]\n[ext_resource type="Script" path="res://dados_especie.gd" id="1"]\n[ext_resource type="Texture2D" path="'+textura+'" id="2"]\n[sub_resource type="AtlasTexture" id="A"]\natlas=ExtResource("2")\nregion=Rect2('+','.join(map(str,rect))+')\n[resource]\nscript=ExtResource("1")\nnome='+json.dumps(nome)+'\ntextura=SubResource("A")\n'
            for gd,k in [('base_hp','baseHp'),('base_atk','baseAtk'),('base_def','baseDef'),('base_sp_atk','baseSpAtk'),('base_sp_def','baseSpDef'),('base_speed','baseSpeed')]:s+=f'{gd}={c[k]}\n'
            s+='tipo_primario='+json.dumps(c['type1'])+'\ntipo_secundario='+json.dumps(c.get('type2') or '')+'\n'
            (pasta/(slug+'.tres')).write_text(s);recursos[nome]=destino
            conf=json.loads(json.dumps(modelo));conf.update(nivel=1,xp=int(c['experience']),vip=0,provisorio=True);hunts[nome]=conf
        if nome=='Larvitar':hunts[nome]['xp']=int(c['experience'])
        hunts[nome].update(nivel=max(1,int(alvos[nome]['level'])),dificuldade=max(1,int(alvos[nome]['level'])),regra_nivel='proxy_local_nivel_acesso_v1')
        golpes[nome]=c;bases[nome]=c
    for path,data in [('dados/importados/visuais.json',visual),('dados/importados/catalogo_fonte.json',criaturas),('dados/caca/hunts.json',hunts),('dados/combate/golpes_originais.json',golpes),('assets/interface/hud/atributos_base.json',bases)]:
        (projeto/path).write_text(json.dumps(data,ensure_ascii=False,indent=2))
    linhas=['extends RefCounted','const CAMINHOS = {']
    # Os dois recursos iniciais sempre permanecem suportados em saves antigos.
    recursos.update(Geodude='res://dados/especies/geodude.tres',Larvitar='res://dados/especies/larvitar.tres')
    linhas += [json.dumps(n)+':'+json.dumps(r)+',' for n,r in sorted(recursos.items())]
    linhas+=['}', 'static var _especies: Dictionary = {}', 'static func obter_especies() -> Dictionary:', '\tif _especies.is_empty():', '\t\tfor nome in CAMINHOS: _especies[nome]=load(CAMINHOS[nome])', '\treturn _especies'];(projeto/'especies_importadas.gd').write_text('\n'.join(linhas)+'\n')
    return relatorio
if __name__=='__main__':
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('--origem',type=Path,required=True);a.add_argument('--projeto',type=Path,required=True);a.add_argument('--aplicar',action='store_true');n=a.parse_args()
    r=executar(n.origem,n.projeto,n.aplicar);print(json.dumps({'aprovados':len(r['aprovados']),'pendentes':len(r['pendentes']),'aplicado':n.aplicar},ensure_ascii=False))
