# Movimento de selvagens — decisão de implementação

Continua a referência CONHECIMENTO_CONFIRMADO.md do pacote anterior.
A referência histórica dizia que os selvagens locais permaneciam nos spawns.
Isso muda nesta etapa: agora se deslocam, mas não se afirma equivalência exata
com a IA do servidor original.

Dados originais utilizados: grid, minTx/minTy, mobStepMs1000 e mudanças de
row/col/walkFrom nas mensagens field de loogs.txt. Os logs não revelam os
raios de aquisição, chance de passeio, regras de retorno, prioridades nem
cooldowns completos. Os valores4/8/0.35 são parâmetros locais explicitados.

Integração: movimento_selvagens.gd coordena reservas/interpolação e decisões;
caca.gd coordena identidade, HP, alvo e encontros. caca_base.gd oferece um
ponto de extensão ao terminar uma célula do caminho. A animação original
animacao_geodude.gd é reutilizada; a direção acompanha o destino do passo.

O caminho é atualizado no centro da célula, preservando o segmento atual.
Uma recalculação não chama _selecionar_alvo e não restaura HP. O guardião
antes do ataque exige um alvo ativo, estacionário, em alcance, com passagem
livre entre células. O alvo para durante a troca de golpes. Essas regras são
uma integração local segura, não uma dedução da fórmula de combate original.

A posição lógica celula passa a indicar o destino reservado enquanto movendo
é verdadeiro. A posição visual resulta da interpolação entre origem_movimento
e destino_movimento. Respawn verifica ambos os extremos dos outros indivíduos.
Não usar celula como sinônimo de posição visual durante um passo.

A próxima coleta útil é uma sequência contínua field de um mesmo slot, desde
ociosidade até aproximação, golpe e respawn. Dano e loot continuam pendentes.
Não se deve bloquear avanço visual em outras áreas por falta dessas fórmulas.
