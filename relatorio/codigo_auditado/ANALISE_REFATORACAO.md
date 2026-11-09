# Análise da refatoração e próxima evolução

Foi inspecionada a base poke-idle(2).rar, não reaproveitado o controlador antigo
como ponto de partida. A cópia de teste teve nome/autoload ajustados apenas
localmente para isolar dados; project.godot e saves não são distribuídos.

## Avanços confirmados no código

EstadoJogo virou fachada de InventarioJogo, ColecaoPokemon,
ConfiguracaoAutoHelper, PerfilTreinador e CoordenadorSalvamento. Os getters
encaminham o estado dos módulos, sem duplicar estoques/coleção na fachada.

EncontroSelvagem é tipado, com identidade por nascimento, estados e reservas
para recompensa/captura. Caca mantém Array[EncontroSelvagem] e uma referência
ao encontro atual; HP e alvo são acessos derivados. É uma melhora concreta
sobre várias cópias de HP e índices independentes.

O HUD usa CartaoPokemonHud e individuo_alterado para atualizar o membro
correspondente. Preserva os controles existentes ao reconciliar a composição.
Isso atende ao objetivo de evitar reconstrução de todo o time por dano/poção.

A validação e o mecanismo de persistência foram preservados. A separação tem
limites explícitos: encontro ainda referencia Sprite2D, módulos são mutáveis
e propriedades da fachada permitem escrita para compatibilidade.

O teste_qualidade original passou56verificações na base antes da mudança.
Não foi realizada auditoria linha a linha de todos os526arquivos extraídos.

## Evolução entregue: falhar antes de modificar o estado

Antes, registrar_captura rejeitava null/referência repetida/ID duplicado,
mas aceitava, por exemplo, Quality não finita e ID fora do formato do save.
A consequência podia ser uma coleção em memória que o salvamento rejeitava.
O contrato de entrada agora recusa esses valores antes de normalizar, atribuir
identidade e emitir eventos. A checagem por ID existente continua na coleção.

Store all chamava transferências individuais e parava no primeiro erro. Se
um erro aparecesse depois da primeira pilha, havia resultado parcial. A nova
implementação valida planos e capacidade total antes de aplicar. Não há await
ou sinais entre as mutações; as notificações encontram o lote já concluído.
Isso é atomicidade em memória no fluxo síncrono local, não uma transação de
banco de dados ou garantia de persistência em queda de energia.

O teste de capacidade usa estoques sintéticos para atingir o limite200, pois
o catálogo atual tem menos tipos transferíveis. Ele verifica o comportamento
do limite e a futura expansão do catálogo; não afirma que o depot comum já
atinge200tipos diferentes nesta versão.

Consultas devolvem cópias dos metadados de bolas e poções. Assim, uma tela não
recebe a referência do objeto do catálogo por esse método.

## O que permanece

- Não reintroduzir Dictionary para representar os encontros tipados.
- Não passar a guardar cópias dos módulos na fachada.
- Não remover migração, backup ou validação do save para simplificar código.
- Não reaplicar pacotes antigos que substituam EstadoJogo por sua versão anterior.
- Manter a diferença entre regras locais e fatos extraídos do original.

## Próximas prioridades

1. Fazer os testes começarem com fixtures/perfis novos de forma padronizada.
   teste_qualidade não é repetível contra o próprio save deixado pela execução
   anterior: pode começar com TEAM cheio e estoques diferentes. Nesta análise,
   as execuções foram isoladas; não atribuir esse resultado ao código de jogo.
2. Reduzir mutações diretas via fachada gradualmente, mantendo um caminho
   separado para restauração validada. Não tornar arrays readonly de uma vez,
   pois isso quebra consumidores antigos e o restaurador.
3. Centralizar os limites comuns entre contrato de entrada e validação do save.
   A duplicação está explicitada; ao cadastrar espécie ou mudar IVs/níveis,
   atualizar ambos. Não usar um Resource fornecido por cliente online como
   definição autoritativa de espécie.
4. Separar resolução de captura/consumo em serviço de domínio se forem
   adicionadas moedas, limites de BOX, custos ou chamadas de rede. Hoje a
   resolução ainda acontece no controlador da caça.
5. Continuar evolução visual/jogável em cima dessa base, sem esperar a fórmula
   exata de dano. Os dados de referência continuam válidos e versionados.

Execução: Godot4.6.3 headless. Sem nova inspeção visual nem validação no4.7.2.
