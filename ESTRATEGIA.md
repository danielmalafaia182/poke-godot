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

### Critério da classe 2 (formal, desde o ciclo 2)

Para cada trecho de hunt de uma gravação (≥ 5 min, líder conhecido), a sim roda o mesmo trecho (mesmo time, Auto-Helper,
VIP, inventário, HP de cada selvagem gravado) com N = 3 sementes. Para cada métrica m (abates/min, XP/h, ouro/h,
mortes/h, capturas/h), com r = valor real e s = média das sementes, o trecho **passa** se:

1. |s − r| ≤ 0,10 · r (±10%); **ou**
2. a diferença cabe no intervalo de 95% do ruído da amostra:
   - **Contagens** (abates, XP, mortes, capturas): Poisson. Com n eventos reais no trecho, o desvio da taxa é r/√n, e
     passa se |s − r| ≤ 1,96 · (r/√n) · √(1 + 1/N). O √(1 + 1/N) soma a incerteza da média das N sementes. Para XP, o n
     são os abates, porque o XP por abate é fixo por espécie (classe 1).
   - **Ouro:** o loot raro deixa a distribuição assimétrica, então não se usa desvio. A tabela de loot (classe 1) é
     sorteada 2.000 vezes para os abates da sim, com a mistura de espécies do real, e passa se r cair entre os
     percentis 2,5 e 97,5.
   - **Perto de zero:** mortes/h e capturas/h passam se r e s ficarem abaixo de 0,5/h.

O relatório (`dados/relatorios/validar_resultado.md`) mostra as duas contagens: a estrita (só ±10%) e a com o ruído. A
classe 2 está pronta quando todo trecho passa no critério com ruído. Pelo acaso, espera-se ~5% de trechos fora; um
desvio que se repete no mesmo sentido em vários trechos é sistemático e tem de ser corrigido.

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
