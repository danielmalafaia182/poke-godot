# Prioridades restantes da hunt

## P1 — animação específica por golpe

Identificar no cliente/HAR qual efeito corresponde a Seed Bomb e aos demais
golpes: ID do asset, direção, camadas, dimensões, frames, intervalos e âncora.
O vídeo de 3,53 s mostra um efeito verde/vermelho sobre a área do combate; não
basta pintar o impacto NORMAL de verde. Esta atualização conserva apenas os
impactos NORMAL e DARK já integrados. Para outros tipos, nome e dano funcionam.
A próxima integração deve mapear **nome do golpe → efeito**, em vez de somente tipo.

## P1 — reação ao dano recebido

Conferir o futuro vídeo de recebimento de dano para acertar âncora, deslocamento,
temporização e sobreposição. A cor já segue a efetividade contra o defensor,
inclusive nos ataques dos selvagens. O movimento/fade atual é uma aproximação
local fluida; não é uma medição exata de toda a animação do servidor/cliente.

## P1 — dano calculado

O evento contém agora um snapshot da efetividade. Cores são funcionais, mas os
valores continuam vindo da regra provisória de dano. Confirmar fórmula, atributos,
Power/category, bônus e imunidades antes de integrar modificadores numéricos.
Não se multiplicou o dano por uma fórmula inventada nesta etapa.

## P2 — acabamento em diferentes escalas

Conferir o retrato reduzido em outros monitores e o fluxo dos chips quando todos
os tipos de bola estiverem disponíveis. O fundo não atravessa os olhos do asset:
a perda visual vinha da amostragem ao reduzir os pixels brancos.
O ajuste é exclusivo dos ícones pequenos do resultado; os sprites do mundo foram
preservados. Os nomes usam o atlas original e as barras têm preenchimento fino.

## Regras já fechadas por solicitação

- Um painel de derrota por vez, sem fila, acumulação ou extensão por outros abates.
- Novo painel apenas em abate posterior ao fim completo do anterior; máximo 30.
- Limite e contagem de capturados pertencem à instância, nunca ao save global.
- Contador wilds mostra sucessos nesta entrada, não captura pendente do original.
- Painel Capture sem Shop ou mensagens; bolas continuam com quantidades reais.
- XP/loot/captura não dependem de a apresentação estar habilitada.
