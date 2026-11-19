# O alvo vem de fora da visão? (revisão do ciclo 1, 19/11/2026)

Ferramenta: `ferramentas/gravador/medir_alvo_fora.py` (A, todas as gravações; pares de fields com Δseq = 2, por aba).

| Fora da caixa | Quem | Pares | Aproximou | Parado | Outro movimento |
| --- | --- | --- | --- | --- | --- |
| 13x13 | alvo | 9120 | 0 (0.0%) | 9120 | 0 |
| 13x13 | outros | 233110 | 0 (0.0%) | 233110 | 0 |
| 13x7 | alvo | 14654 | 1150 (7.8%) | 12949 | 555 |
| 13x7 | outros | 260883 | 4022 (1.5%) | 254614 | 2247 |

- Fora da borda real 13×13, **o alvo nunca se mexe** (0 de 9.120 intervalos), como os outros (0 de 233.110). A regra do ciclo 1 (`alvo_vem_ao_encontro`, de qualquer distância) era ajuste de curva: revertida.
- Entre a caixa da sim (13×7) e a real (13×13), o alvo se aproxima em 7,8% dos intervalos e os outros em 1,5%: o alvo persegue até a borda real. Regra nova `visao_meia_altura_alvo` 13 (A); os outros seguem com 7 (classe 2).

| Versão | Validador (32 trechos) | Só ±10% |
| --- | --- | --- |
| Ciclo 1: alvo vem de qualquer distância (ajuste de curva) | 157/160 | 105/160 |
| Revertida (alvo como os outros, 13×7) | 155/160 | 102/160 |
| **Alvo até a borda real 13×13 (A)** | **157/160** | 103/160 |
