# p99 com a janela em foco, sombras ligadas — 18/11/2026

Medição feita pelo usuário: PC parado, janela do Godot na frente. Configuração: 1920×1080, RTX 4060, vsync, 60 s a 1×,
`POKE_MODO_FUNDO=0`, sombras ligadas (padrão). Comando:
`POKE_MODO_FUNDO=0 python -I testes/test_todas_hunts.py --velocidade 1 --segundos 60 --slugs nightmare_raichu,nightmare_elekid,rapidash,ancient_pinsir,nightmare_luxray`
Saídas: `saida_testes/p99_foco_r{1,2,3}.json` / `.log` (fora do git).

**Foco conferido:** 9.808–10.537 quadros por hunt em 60 s, ou seja, 163–176 quadros/s. Nenhuma corrida foi limitada pelo
sistema. Nas corridas sem foco de 15/11 eram 600–900 quadros.

| Hunt | p99 r1 · r2 · r3 (ms) | **Mediana** | Pior quadro (ms) | Quadros > 12 ms | Render CPU p99 | GPU p99 | Draw calls |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ancient_pinsir | 10,07 · 9,44 · 12,55 | **10,07** | 43,4 · 11,7 · 26,1 | 3 · 0 · 189 | 3,3 | 2,9 | 166 |
| nightmare_luxray | 9,83 · 9,84 · 10,05 | **9,84** | 18,5 · 19,4 · 18,5 | 3 · 5 · 6 | 4,0 | 2,9 | 169 |
| nightmare_elekid | 8,80 · 9,83 · 9,56 | **9,56** | 19,0 · 19,7 · 19,0 | 3 · 6 · 11 | 3,3 | 2,9 | 187 |
| nightmare_raichu | 9,74 · 9,14 · 9,09 | **9,14** | 20,4 · 27,6 · 16,8 | 6 · 6 · 5 | 3,7 | 2,5 | 171 |
| rapidash | 7,60 · 7,34 · 7,56 | **7,56** | 39,6 · 26,0 · 14,5 | 1 · 2 · 1 | 3,4 | 2,7 | 170 |

Os valores de render CPU, GPU e draw calls são da rodada 1.

**Critério (mediana dos 3 p99 ≤ 16,7 ms): 5/5.** O pior p99 de todas as 15 corridas foi 12,55 ms.

Referência sem sombra (10/11, mesma lista, máquina limpa): pinsir 10,3, luxray 10,3, elekid 11,0, raichu 9,1, rapidash 7,1.
Os valores com sombra ficam iguais a esses dentro do ruído. A comparação não foi pareada, porque a sim e a HUD mudaram
desde 10/11.

Quadros isolados lentos (pior de 14 a 43 ms, poucos por minuto) vêm de três fontes:
- o script no 1º tick: carga, `sim_msgs` cerca de 10 ms;
- o abate: `field-kill` com cerca de 9 ms de mensagens;
- a drenagem ou a animação de chunks: 3–5 ms.

Esses quadros não pesam no p99. A rodada 3 do ancient_pinsir teve 189 quadros acima de 12 ms (p99 12,55), contra 0 e 3 nas
outras rodadas. A causa provável é a máquina, não o jogo.

Observação à parte: o nightmare_elekid fez 0 abates em 60 s nas rodadas 2 e 3 (12 na 1ª). É o time de teste da varredura
(E). Isso não afeta o quadro, mas fica registrado.
