> Atualização de 05/11/2026: os quatro itens solicitados de qualidade foram
> tratados no pacote `revisao_qualidade_v1.zip`. Consulte `ARQUITETURA_QUALIDADE.md`
> e `VALIDACAO_QUALIDADE.txt` para o estado atual. O texto abaixo registra o
> diagnóstico anterior; sua lista de prioridades não foi toda implementada.

# Revisão técnica dirigida — 05/11/2026

Base: scripts da cópia de trabalho com geodudes_movimento_perseguicao aplicado.
Escopo: leitura dirigida do controlador da caça, movimentação, dados individuais,
HUD e fluxos de persistência. Não é uma auditoria exaustiva de todos os scripts,
assets ou estados possíveis do jogo. Não afirma equivalência ao servidor original.

## Resultado

A base já permite continuar evoluindo. Não há motivo demonstrado para reescrever
em outra linguagem, adotar ECS, banco de dados, microsserviços ou framework novo.
O problema principal é a concentração de responsabilidades e de estado mutável,
não a escolha de GDScript ou Godot. Migrar tudo de uma vez aumentaria o risco.

## Corrigido neste pacote

1. **Espera por alvo em trânsito:** enquanto o aliado estava parado esperando o
   selvagem terminar um passo, recalcular_alvo_pendente podia disparar A* e
   reiniciar a aproximação a cada frame. Agora essa espera aguarda o término do
   passo. O recálculo durante aproximação continua nos centros das células.
2. **Contrato do JSON de navegação:** dados_navegacao.gd verifica o objeto,
   campos inteiros finitos, dimensões limitadas, formato retangular, células
   booleanas e tempos positivos antes de indexar ou dividir. Arquivo inválido
   interrompe a inicialização com mensagem; não substitui a grade silenciosamente.
3. **Leitura duplicada:** movimento_selvagens.gd não abre mais o mesmo JSON.
   A caça fornece o mobStepMs já validado. A grade é interpretada uma vez nessa
   inicialização; os metadados compartilhados não retêm uma segunda grade.
4. **Índice de alvo:** consultas de alcance e recálculo verificam também o limite
   superior do índice, antes de acessar o array.
5. **Comentário obsoleto:** experiencia_percentual está descrito como derivado
   do XP total; o campo foi mantido para compatibilidade com saves anteriores.

Nenhuma cena, caminho de recurso existente, nome de variável existente ou formato
de save foi renomeado. As alterações estão comentadas nos scripts.

## Prioridades para as próximas sessões

| Prioridade | Evidência / problema | Ação recomendada | Critério de pronto |
|---|---|---|---|
| P1 | caca_base.gd e caca.gd combinam navegação, combate, população, captura e UI | Extrair uma responsabilidade por etapa, mantendo adaptadores e nomes atuais | Mesmo ciclo cidade→caça→captura→depot→reabertura |
| P1 | indice_alvo, pokemon_selvagem, imagem_selvagem e HP representam o mesmo encontro em vários campos | Criar objeto de encontro com ID próprio e estado explícito | Trocar/recalcular alvo não cura, duplica XP ou reutiliza resultado antigo |
| P1 | População usa Dictionary com chaves de texto e Variant | Introduzir classe tipada para cada vaga/indivíduo em campo | Respawn e interpolação não dependem de grafia repetida das chaves |
| P1 | DadosPokemon é Resource mutável; identidade difere da referência em memória | Centralizar criação/registro, validar IDs únicos e rejeitar indivíduo inválido antes de mutar coleção | Duas referências com mesmo ID não geram save inválido |
| P1 | EstadoJogo agrega domínio, inventário, perfil, save e aviso visual | Mantê-lo como fachada, extrair inventário e depois repositório de progresso | Interfaces atuais continuam funcionando sem acessar estruturas internas |
| P2 | HUD recria cartões ao receber atualizações de Pokémon | Atualizar HP/XP nos controles existentes; reconstruir apenas ao mudar composição | Dano/poção não recriam o retrato e todos os membros do time |
| P2 | A* usa arrays e busca linear pelo menor custo | Medir tempo de recálculo; trocar estrutura somente se houver custo relevante | Métrica antes/depois com os15mobs e mesma grade |
| P2 | UI consulta e em alguns casos sincroniza XP | Fazer leitura da apresentação não alterar o domínio; sincronizar ao carregar/conceder XP | Abrir/fechar ficha não modifica estado persistido |
| P2 | Arquivos de teste e referências misturados à raiz | Mover testes para tests/ e documentação para docs/ em uma etapa de organização | Caminhos de testes atualizados; nada carregado pelo jogo foi removido |
| P2 | Regras confirmadas e locais ainda aparecem em scripts | Criar configuração versionada com origem de cada parâmetro | Fórmula original não se confunde com escolha do protótipo |
| P3 | Repetição de estilos, fontes e constantes visuais | Consolidar Theme e recursos compartilhados gradualmente | Menos duplicação, preservando aparência |
| P3 | Animação e apresentação chamam métodos por texto | Definir contratos tipados públicos onde isso reduzir erros reais | Chamada incompatível detectada cedo, sem circularidade entre scripts |

## Arquitetura de destino, sem ruptura

Manter EstadoJogo como entrada usada pelas cenas. Internamente:

- **Catálogos:** espécies, golpes, itens, tipos e animações; dados de referência
  somente leitura. Evitar armazenar HP ou indivíduo em um catálogo de espécie.
- **Domínio:** indivíduo Pokémon, equipe, inventário e encontro. Contém regras e
  validação; não instancia Sprite2D, Label ou efeitos.
- **Simulação da caça:** população/respawn, navegação e combate. Produz eventos
  com ID do encontro e valores finais. Não precisa esperar animações.
- **Apresentação:** HUD, retratos, impactos, captura e cartões. Recebe eventos e
  exibe; não decide se a captura deu certo nem quantos itens foram consumidos.
- **Persistência:** serializa snapshots validados e restaura o domínio. Mantém
  migração, temporário, principal e backup. Não recebe caminhos arbitrários
  vindos de um save.

Primeira extração sugerida: o objeto tipado de vaga no lugar dos Dictionary de
selvagens. Depois, objeto de encontro. Evitar extrair combate, inventário e save
simultaneamente: fica difícil localizar uma regressão.

Os estados do encontro podem ser uma enumeração pequena: buscando, aproximando,
em_combate, resolvido. Respawn é estado da vaga, não precisa ser misturado ao
estado do aliado. Hoje há combinações possíveis entre aproximando,
batalha_encerrada, timer ativo e indice_alvo; reduzir essas combinações é mais
útil do que apenas dividir arquivos em pastas.

## Limpeza: o que remover e o que preservar

**Pode ser organizado depois:** logs verbosos atrás de uma opção de diagnóstico;
testes soltos; documentos e capturas fora dos diretórios de runtime; comentários
históricos que contradizem o código. Manter os comentários que distinguem regra
local de regra confirmada e os que explicam migração.

**Candidato a exclusão, ainda não comprovado:** batalha.gd/batalha.tscn do
protótipo anterior, componentes antigos de navegação e assets aparentemente
repetidos. Antes de excluir, rastrear referências em .tscn, .tres, preload/load,
chamadas por string e entradas do projeto. Ausência de uma chamada explícita em
um .gd não demonstra que o editor não referencia o recurso.

**Não remover agora:** .gd.uid, migração de XP/HP, normalização dos saves,
compatibilidade com saves antigos, backups, guardas de navegação/alcance,
identificadores persistentes e separação dos efeitos por sinais. Nada disso é
lixo apenas por existir uma implementação mais recente.

Não foi excluído asset ou script de funcionalidade neste pacote.

## Segurança e confiabilidade

O salvamento existente já valida estrutura, espécies permitidas e valores;
verifica o arquivo temporário; mantém backup da última versão válida; e tenta
salvar no fechamento normal. Preservar esses mecanismos. O hash SHA-256 detecta
inconsistência do conteúdo, mas um usuário pode editar e recalcular o hash:
não é assinatura nem mecanismo antitrapaça.

Dados do cliente não podem ser autoridade em uma versão online. O servidor terá
que validar tempo, posição, dano, consumo, recompensa, propriedade e captura.
Não colocar uma chave secreta no executável para tentar tornar o save confiável.

Melhorias futuras de persistência: teste de recuperação após interrupção entre
as etapas de gravação, testes multiplataforma de renomeação, limite explícito
para coleção/contadores antes de esgotar o limite do arquivo e validação de
indivíduo no ponto de entrada. Não afirmar que o mecanismo atual cobre todas
as formas de queda de energia só por usar arquivo temporário.

O limite512×512 da grade é uma proteção local de contrato, não uma propriedade
do mapa original. Ainda são lidos arquivos locais empacotados, não uploads de
usuários. Se isso mudar, limitar também bytes antes de interpretar JSON.

## Regras do jogo que continuam pendentes

Dano, chance de captura, loot, distribuição de XP do time, curva da conta,
IA exata, respawn original e variantes de shiny. Não trocar essas pendências
por números que pareçam plausíveis. A fórmula de sorteio de Quality atual
contém faixas e pesos locais e não pode ser anunciada como distribuição original
sem fonte correspondente. A faixa de IV e classificações também precisa de
reconciliação com o contrato original, não de alteração automática baseada em
outros jogos Pokémon.

## Testes e continuidade

Foram executados o teste novo do contrato/espera e a simulação integrada de
movimento da etapa anterior. Os relatórios estão no pacote. Execução em Godot
4.6.3 headless; não houve inspeção visual nova nem teste do executável4.7.2.

Antes da próxima refatoração maior, criar um commit da versão que o usuário
validou. Manter este diagnóstico, referências originais, instruções e testes
junto do projeto permite retomar com pouco contexto. Não é necessário manter
todas as respostas do chat para entender as próximas prioridades.
