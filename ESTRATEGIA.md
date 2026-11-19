# Estratégia do projeto (desde 19/11/2026)

O objetivo é ter o **melhor poke idle possível**:
- fiel no que o jogador percebe;
- desenhado com cuidado no resto;
- completo.

Gravações não bloqueiam mais nada.

## Política de decisão

| Classe | O que é | Critério |
| --- | --- | --- |
| **1 — exata** | O jogador vê o número ou compara com a Pokepedia: curva de XP, stats, IV teto 32, Quality, preços, loot, evolução, nível das hunts | Igual ao original |
| **2 — equivalente no resultado** | O jogador sente o efeito, não a fórmula: movimento, dano nos extremos, chegada de selvagens | Pronto quando abates/min, XP/h, ouro/h, mortes/h e capturas/h ficam a ±10% do real em cada trecho das gravações existentes (`ferramentas/validar_resultado.py`) |
| **3 — desenhada** | Dado só no servidor, sem gravação, ou original incoerente | Decidida pelo melhor design (ritmo, clareza, sem muros de progressão), documentada em uma linha, com o valor em `dados/balanceamento.json`, nunca fixo no código |

Regras do dia a dia:
- **Nunca parar esperando gravação.** As gravações livres chegam em `poke har/gravacoes/livre/` e servem para conferir.
  Se contradisserem uma decisão, a decisão é corrigida.
- **Perguntar só decisões de produto** (o que o jogo deve ser), juntas num bloco no fim do ciclo. Detalhe técnico ou de
  balanceamento, decidir e documentar.
- **Conteúdo trocável:** sprites, nomes e sons ficam em pacotes trocáveis. O conteúdo atual é o pacote "original", para uma
  versão pública poder usar criaturas próprias sem reescrever o jogo.

## Onde está cada coisa

- Placar por classe: `PLACAR_ESCOPO.md`.
- Valores de classe 3: `dados/balanceamento.json` (lidos por `sim/balanceamento.gd`).
- Validador da classe 2: `ferramentas/validar_resultado.py` → `dados/relatorios/validar_resultado.md`.
- Backlog de telas e textos do cliente original: `INVENTARIO_CLIENTE.md`.
- Campanha e muros de progressão: `dados/relatorios/campanha_metas_2026-11-19.md`.
