# Próxima calibração: ritmo original

A correção de concorrência está implementada. O padrão local de1,5s foi mantido;
o vídeo mostra múltiplos atacantes, mas não permite atribuir com precisão cada
número flutuante a um slot e medir todos os intervalos.

Para calibrar, coletar mensagens WebSocket por15–20 segundos em duas situações:

1. Um selvagem atacando sozinho.
2. Três ou mais selvagens ao redor, incluindo a chegada de um novo inimigo e,
   se possível, a morte de um dos atacantes.

Manter os horários, seq, serverNow, heroHp, mobs (slot, HP e posição) e o array hits
INTEIRO. Incluir mensagens separadas de ataque/dano, se existirem; não supor um
nome de campo de atacante sem observar o payload. Se a conexão enviar field-init,
incluir seus parâmetros de ataque. Não é necessário repetir catálogo ou assets.

Compararemos ataques por identidade/slot, nunca apenas o intervalo entre todos
os números de dano. Três monstros com o mesmo ritmo podem produzir várias
mensagens no mesmo instante ou golpes intercalados, sem que cada um seja mais rápido.

No Firefox, usar a aba de mensagens da conexão WS já utilizada na coleta anterior.
A lista de mensagens é a evidência necessária; somente o HAR HTTP pode não conter
os frames WebSocket. Não é necessário desconectar a internet.

Pontos a confirmar: intervalo base por espécie, fase inicial ao entrar em alcance,
relação entre ataque básico e cooldown de golpe, ataque durante um passo e ordem
dos hits simultâneos no servidor. A ordem local de desempate é aliado primeiro e,
para os selvagens prontos no mesmo frame, ordem dos slots.
