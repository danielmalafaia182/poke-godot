# Movimento dos selvagens — desvio reaberto em 18/11/2026

Situação depois da regra nova de alvo (o menor tempo de caminho, A, 18/11). Tabela gerada por
`python -I ferramentas/fase4/comparar_movimento.py`.

- **Real:** gravações rhydon-1h, M1, M2 e M3.
- **Sim:** 3 sementes × 30 min a partir do estado inicial de cada gravação (`testes/rodar_sim.gd`), com
  `visao_meia_altura` 7 (o padrão) e 13.
- **Métricas:** chegadas, adjacentes e perseguindo vêm de `medir_movimento.py` (caixa 13×13). Os ms por tile vêm do
  `comparar_sim.py`, as mesmas métricas do diferencial.
- **Chegada:** um selvagem que não é o alvo passa de d ≥ 2 para d ≤ 1 do herói entre dois fields consecutivos, por
  minuto de pares consecutivos.
- **Atenção:** o denominador é diferente do da tabela antiga do CLAUDE.md, por isso os números não são os mesmos de lá.

| Caso | Grandeza | Real | Sim 7 (3 sementes) | Sim 13 (3 sementes) |
| --- | --- | --- | --- | --- |
| rhydon-1h (Venusaur, luta curta) | Chegadas de não-alvos / min | 0.99 | 1.20 (0.80–1.97) | 2.31 (1.30–3.47) |
| rhydon-1h (Venusaur, luta curta) | Adjacentes por field | 0.395 | 0.54 (0.43–0.74) | 0.74 (0.51–1.12) |
| rhydon-1h (Venusaur, luta curta) | Perseguindo por field | 0.664 | 0.47 (0.46–0.49) | 0.50 (0.49–0.52) |
| rhydon-1h (Venusaur, luta curta) | Herói: ms por tile | 758 | 786 (779–794) | 782 (770–792) |
| rhydon-1h (Venusaur, luta curta) | Selvagem: ms por tile perseguindo | 1136 | 1333 (1310–1352) | 1292 (1276–1314) |
| M1 (Kangaskhan, luta longa) | Chegadas de não-alvos / min | 2.49 | 1.36 (1.27–1.53) | 1.14 (0.87–1.37) |
| M1 (Kangaskhan, luta longa) | Adjacentes por field | 1.381 | 1.30 (1.27–1.33) | 1.20 (1.09–1.32) |
| M1 (Kangaskhan, luta longa) | Perseguindo por field | 0.161 | 0.13 (0.10–0.16) | 0.12 (0.10–0.14) |
| M1 (Kangaskhan, luta longa) | Herói: ms por tile | 786 | 681 (639–728) | 758 (697–806) |
| M1 (Kangaskhan, luta longa) | Selvagem: ms por tile perseguindo | 1314 | 1346 (1304–1382) | 1265 (1235–1292) |
| M2 (Kangaskhan, luta longa) | Chegadas de não-alvos / min | 1.46 | 1.36 (1.27–1.53) | 1.14 (0.87–1.37) |
| M2 (Kangaskhan, luta longa) | Adjacentes por field | 1.275 | 1.30 (1.27–1.33) | 1.20 (1.09–1.32) |
| M2 (Kangaskhan, luta longa) | Perseguindo por field | 0.221 | 0.13 (0.10–0.16) | 0.12 (0.10–0.14) |
| M2 (Kangaskhan, luta longa) | Herói: ms por tile | 763 | 681 (639–728) | 758 (697–806) |
| M2 (Kangaskhan, luta longa) | Selvagem: ms por tile perseguindo | 1233 | 1346 (1304–1382) | 1265 (1235–1292) |
| M3 (Rhydon, Golem, 1 golpe) | Chegadas de não-alvos / min | 0.5 | 0.67 (0.50–0.93) | 0.89 (0.63–1.07) |
| M3 (Rhydon, Golem, 1 golpe) | Adjacentes por field | 0.03 | 0.06 (0.05–0.08) | 0.08 (0.07–0.10) |
| M3 (Rhydon, Golem, 1 golpe) | Perseguindo por field | 0.919 | 0.63 (0.63–0.64) | 0.64 (0.64–0.65) |
| M3 (Rhydon, Golem, 1 golpe) | Herói: ms por tile | 809 | 794 (789–799) | 796 (787–801) |
| M3 (Rhydon, Golem, 1 golpe) | Selvagem: ms por tile perseguindo | 1124 | 1368 (1359–1376) | 1313 (1311–1315) |

## O que ainda diverge

| Grandeza | Situação |
| --- | --- |
| **Cadência de cada passo** (herói e selvagem) | **Igual** (A × sim, `medir_passos.py` pelo tick exato): selvagem reto 1000/1200 ms, diagonal 2000 ms; real rhydon-1h 359/208 retos em 1000/1200, sim 389/232. Não é a causa de nada abaixo |
| **Chegadas de não-alvos por minuto** | Com 7, dentro da faixa em rhydon-1h, M2 e M3 (no limite de baixo); **fora só no M1** (2,49 × 1,27–1,53; o M2, mesmo estado e hunt, dá 1,46, dentro). Com 13: fora em rhydon-1h e M3 (junta demais em luta curta) e no M1 |
| **Borda 13 × 7** | A borda real é 13 nos dois eixos (A, zero a partir de 14). A sim com 13 junta selvagens demais em luta curta; com 7 acerta as chegadas, mas não é o que a gravação mostra. **Continua aberto** |
| **Adjacentes por field** | Com 7: rhydon-1h real 0,395 abaixo da faixa (0,43–0,74); M3 0,03 abaixo (0,05–0,08); M1 1,38 acima (1,27–1,33); M2 dentro |
| **Selvagem: ms por tile perseguindo** | Sim ~18% mais lenta em luta curta (rhydon-1h 1136 × 1310–1352; M3 1124 × 1359–1376); em luta longa, dentro (M1/M2). A métrica real usa só pares Δseq = 2, que no real se concentram quando algo anda (artefato já registrado). Parte do desvio pode ser amostragem, e não a regra |
| **Herói: ms por tile** | Sinal misto: rhydon-1h a sim é mais lenta (758 × 779–794); M1/M2 e M3 a sim é mais rápida (786/763 × 639–728; 809 × 789–799). Com a cadência igual, sobra a escolha de rota (proporção de diagonais) e o caminho até o alvo |
| **Perseguindo por field** | Real maior em todos (0,66 × 0,47; 0,92 × 0,63; 0,16–0,22 × 0,13), mas com o mesmo viés de amostragem dos pares Δseq = 2 |

Teste feito com dados que já existem: não-alvos dentro da caixa 13×13 a d ≥ 3 que se aproximam por intervalo, separados
pelo estado do herói. Real × sim 13:

| Estado do herói | rhydon-1h | M1 | M2 | M3 |
| --- | --- | --- | --- | --- |
| lutando | 0,188 × 0,247 | 0,221 × 0,216 | 0,170 × 0,216 | 0,167 × 0,263 |
| andando | 0,153 × 0,222 | 0,31 × 0,18 (16 pares) | 0,12 × 0,18 | 0,238 × 0,232 |
| parado sem lutar | **0,302 × 0,212** | 0,25 × 0,13 (8 pares) | **0,31 × 0,13** | **0,399 × 0,207** |

Durante a luta, a sim aproxima mais que o real. Com o herói parado sem lutar (logo depois do abate, ou esperando),
aproxima menos. O desvio em luta curta e em luta longa vem daí, mais do que da borda.

## Hipóteses que sobram (F)

- **H5 — borda = 13 com perseguição só "acordada":** o selvagem entra em perseguição a uma distância menor e continua até
  13 (histerese). Explicaria poucas chegadas em luta curta, quando o herói passa e vai embora, e muitas em luta longa,
  quando os acordados têm tempo de chegar.
- **H6 — a borda acompanha o `view` do cliente**, e não um 13 fixo. Com o zoom padrão (0,5×), o `view` é 27×15; não
  testado com outro zoom.
- **H7 — a decisão de andar é tomada sobre a posição do herói de alguns ticks antes:** o real reage mais quando o herói
  fica parado e menos quando ele luta. Na tabela acima, o real se aproxima mais com o herói parado sem lutar.
- **H8 — o ms por tile do selvagem é amostragem**, e não regra. Precisa de uma gravação com todos os fields (Δseq = 2
  sempre).
- **H2 (coleira):** nenhum retorno ao spawn observado até agora.

## Gravações (no máximo 3, curtas)

Para todas: gravador ativo (`ferramentas/gravador/gravador_ws.user.js`, v1.2), Auto-Potion ligado ("Automatic (best)",
"Heal when HP ≤ 50%"), **Auto-Catch desligado**, sem trocar o líder e sem sair da hunt no meio. Ao terminar:
`python -I ferramentas/processar_gravacao.py <arquivo>` e `python -I ferramentas/fase4/comparar_movimento.py` (depois de
pôr o caso novo na lista `CASOS`).

| ID | Conta, líder | Hunt | Duração | Roteiro exato | Separa |
| --- | --- | --- | --- | --- | --- |
| **MV1 — luta média** | A, Venusaur (o mesmo do M1/M2) | `blastoise` (Kanto, nível 80; grade real em `dados/testes/field_init_blastoise.json`). Na sim, o Venusaur leva 11,5 s por abate (7,2 golpes); reserva: `feraligatr` (9,7 s) | 20 min | Cidade → mapa (Kanto) → clicar em **Blastoise** → deixar caçar 20 min sem mexer em nada → **Back to Cerulean** | H5 × borda 7: com histerese, as chegadas por minuto ficam entre o rhydon-1h (0,99) e o M1 (2,49) e crescem com o tempo de luta; com a borda 7 fixa, não crescem. Também dá o ponto em que o desvio muda de sinal (o antigo M6) |
| **MV2 — zoom** | A, Venusaur | `rhydon` (Kanto, 80, a mesma da rhydon-1h) | 2 × 10 min | Entrar na hunt **Rhydon** pelo mapa. 10 min com o zoom padrão (Configurações → **Zoom da câmera** em 0.5×). Sem sair da hunt, mudar o **Zoom da câmera** para o maior valor (ou clicar várias vezes em **Aumentar zoom**) e caçar mais 10 min. O gravador registra o `view {hc, hr}` novo | H6: se a borda acompanhar o `view`, a borda medida e as chegadas mudam entre as duas metades; se ficarem iguais, a borda é fixa (13) |
| **MV3 — herói lento num mapa aberto** (o antigo M4) | A, um Geodude nível ~10 (ou qualquer Pokémon que tire 1–2 golpes por Rattata) | `rattata` (Kanto, 1; grade real em `dados/testes/field_init_rattata.json`) | 20 min | Cidade → mapa → **Rattata** → 20 min sem mexer | H7 e H2: o herói para muito tempo (abates lentos) e anda entre alvos distantes, com muitos intervalos "parado sem lutar" e muitos selvagens saindo da caixa. Mostra se a aproximação com o herói parado é maior (H7) e se o selvagem que sai da caixa volta ao spawn (H2) |

H8 não pede gravação nova: basta que MV1–MV3 tenham trechos com todos os fields (o gravador grava o que chega; o
cliente recebe mais quando a aba fica em primeiro plano). Os trechos com Δseq = 2 contínuo dão o ms por tile sem viés.
