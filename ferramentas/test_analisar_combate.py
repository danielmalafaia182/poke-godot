import unittest,tempfile,json
from pathlib import Path
from analisar_combate import carregar,comparar,original
class Analise(unittest.TestCase):
 def test_original_sem_hits_nao_inventa_dano(self):
  r=original([{'type':'field','serverNow':1000,'heroHp':50,'mobs':[{'speciesId':9,'maxHp':100}],'hits':[]},{'type':'field','serverNow':1200,'heroHp':40,'hits':[]}])
  self.assertEqual(r['hits_observados'],0)
  self.assertNotIn('dano',r)
  self.assertEqual(r['hp_maximo_por_speciesId'],{'9':[100]})
 def test_relogios_independentes(self):
  r=[{'tipo':'sessao','dados':{'origem':'prototipo_local'}}]
  for inimigo,tempo in [('a',0),('b',0),('a',1),('b',2)]:r.append({'tipo':'golpe','dados':{'aliado':False,'encontro_id':inimigo,'tempo_atacante':tempo,'nome':'Tackle'}})
  a=comparar(r,[{'type':'field','hits':[]}])
  self.assertFalse(a['fidelidade_comprovada'])
  self.assertEqual(a['local']['cadencia_por_atacante']['selvagem:a']['mediana_s'],1)
  self.assertEqual(a['local']['cadencia_por_atacante']['selvagem:b']['mediana_s'],2)
 def test_slot_alvo_nao_vira_atacante(self):
  r=original([{'type':'field','serverNow':1234,'hits':[{'slot':-1,'amount':12,'move':'Tackle','eff':1,'crit':False},{'slot':3,'amount':18,'move':'Vine Whip','eff':2,'dmgDelayMs':300}]}])
  self.assertEqual(r['hits_normalizados'][0]['alvo'],'aliado')
  self.assertIsNone(r['hits_normalizados'][0]['atacante'])
  self.assertEqual(r['hits_normalizados'][1]['slot_alvo'],3)
  self.assertEqual(r['hits_normalizados'][1]['dmgDelayMs'],300)
 def test_formatos_e_erro_claro(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'input.json';p.write_text('[{"type":"field"}]')
   self.assertEqual(len(carregar(p)),1)
   p.write_text('{"type":"field"}\n{"type":"field"}')
   self.assertEqual(len(carregar(p)),2)
   p.write_text('texto que não é JSON')
   with self.assertRaises(ValueError):carregar(p)
if __name__=='__main__':unittest.main()
