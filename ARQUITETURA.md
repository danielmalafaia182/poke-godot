# Arquitetura e manutenção

O jogo offline continua em Godot 4.7, com Game Master no editor e no executável.
Esta revisão fortalece os limites existentes sem mudar os valores de balanceamento.

## Responsabilidades

| Camada | Responsabilidade | Entrada e saída |
| --- | --- | --- |
| `sim/simulacao_hunt.gd`, regras e serviços `RefCounted` | Combate e operações do domínio | Dados, parâmetros, relógio e RNG; mensagens do protocolo |
| `sim/regras_jogo.gd` | Repositório de configuração e perfis | Resources confiáveis do pacote e dados externos validados |
| `sim/validacao_regras.gd` | Contratos de configuração | Tipos, faixas, nomes, opções e alterações de tabelas |
| `infra/` | Leitura de perfis como dados e escrita com temporário | Resultado ou erro explícito; sem UI |
| `ponte_cidade.gd`, `estado_jogo.gd` | Composição, serviços e estado da sessão | Adaptam domínio ao cliente e à persistência |
| Cenas, HUD e painéis | Apresentação e comandos do jogador/GM | Exibem resultados; não implementam fórmulas de combate |
| `coordenador_salvamento.gd`, `salvamento_local.gd` | Persistência e recuperação | Save validado, backup e comunicação das falhas |

O repositório de regras tem I/O e cache; ele é um adaptador de configuração, não parte
do cálculo determinístico de cada tick. A hunt recebe uma instância de dados e seus
parâmetros ao começar. Não consultar cenas, relógio de parede ou arquivos dentro das
fórmulas; usar o RNG e o tempo fornecidos pela simulação.

## Configuração e Game Master

1. Os scripts de `dados/regras/scripts/` definem os defaults da referência local `original`.
2. Para um perfil, `user://regras/<perfil>/` tem precedência sobre `res://dados/regras/<perfil>/`.
3. Cada Resource substitui o grupo correspondente; campos omitidos usam os defaults do script.
4. Tabelas grandes mantêm alterações em `alteracoes.tres`; o lote inteiro é validado antes de aplicar.
5. A seleção local do editor (`dados/regras/perfil.txt`) não entra no build. O executável novo inicia no `original`.

Um `.tres` externo é lido como dados: o leitor ignora sua associação a script e recusa
objetos, referências, tipos incorretos, valores não finitos e estruturas excessivas.
`ResourceLoader` só lê os Resources confiáveis empacotados, inclusive a conversão
`.tres` → `.res/.remap` feita pelo exportador. Isso não é uma sandbox para executar mods:
perfis externos aceitam somente os tipos de dados documentados.

Gravações usam temporário e substituição do arquivo após conferência. Erros chegam ao
dock ou painel. Os chamadores serializam as gravações; editar o mesmo perfil por dois
processos simultaneamente não é um fluxo suportado. Restaurar grava explicitamente os
defaults, evitando que apagar um override revele outro valor alterado no pacote.

`EstadoJogo.recarregar_regras()` é o único ponto de invalidação da composição. Reinicia
os caches dos dez serviços, da ponte e dos dados; emite `regras_recarregadas` para o mapa
já aberto. A hunt em andamento mantém seu snapshot. Regras de combate alteradas passam
a valer na próxima hunt, evitando trocar as condições de uma luta pela metade.

O painel F12 permanece disponível: ativo no desenvolvimento e habilitável nas
Configurações do executável. A revisão não remove comandos de nível, ouro, itens, tempo,
shiny, esperas, VIP ou seleção de perfil. O GM é uma ferramenta local deliberadamente
privilegiada; não representa um modelo de autorização para um futuro servidor online.

## Ciclo de vida e saves

Todo nó criado deve pertencer a uma cena ou ter liberação explícita. Painéis ocultos
também precisam de dono na árvore. O painel legado de captura pertence ao HUD e é
liberado junto com a hunt; não manter árvores invisíveis órfãs entre viagens.

Novo jogo exige salvar o progresso atual e conferir todas as cópias de backup antes
de remover os candidatos a save. Se salvar, preparar o marcador ou copiar falhar,
a operação é cancelada. Se a remoção falhar parcialmente, tenta restaurar os arquivos
removidos e mantém os backups. Falha na recuperação bloqueia novas gravações.
Não prometer atomicidade de uma transação com vários arquivos contra queda de energia:
os backups são a salvaguarda para esse caso.

## Verificação reproduzível

Executar da raiz do projeto, com Python e o Godot instalado. `--godot` ou a variável
`GODOT` permitem apontar o executável; também há descoberta na pasta `Godot` ao lado do projeto.

```text
python ferramentas/qualidade/verificar.py --suite smoke
python ferramentas/qualidade/verificar.py --suite full
python ferramentas/qualidade/verificar_fluxos.py
python testes/test_save_thread.py --vezes 15
python -m unittest discover -s ferramentas/qualidade -p test_verificar.py
python -m unittest discover -s ferramentas/regras -p test_catalogo.py
python -m unittest discover -s ferramentas/build -p test_montar_build.py
python ferramentas/build/montar_build.py nome_novo_do_build
```

Os runners novos isolam APPDATA, configurações e caches; fixam o perfil `original`;
guardam logs completos e relatórios em `saida_testes/`. Nunca apontar testes para o
save real. A suíte `full` enumera os testes GDScript autônomos; os fluxos que precisam
de fixtures e mais de um processo têm runners separados. Testes visuais e medições
de FPS precisam de execução com renderização e não são certificados pelo modo headless.

O critério exige código de saída correto, conclusão registrada e ausência de erros
de script, asserções ou vazamentos. Imprimir `RESULTADO` não neutraliza um erro de execução.
O gabarito de três simulações em `testes/referencia_sim.json` foi capturado antes desta
revisão; alterá-lo exige justificar a mudança de regra, não apenas atualizar hashes.

O build exige nome novo, nunca apaga builds existentes e só produz `manifesto.json`
com hashes SHA-256 depois de exportação, pacote e três fases de verificação aprovadas.
As fases exercitam início, caça, reabertura, importação e GM/F12 em saves descartáveis.
Logs de build ficam em `saida_testes/build/<nome>/`. Gravações, HARs, saves, snapshot
bruto, testes e relatórios de desenvolvimento não integram o pacote distribuído.

## Evidência e continuidade

`REGRAS.md` e o catálogo descrevem origem declarada, não uma auditoria automática da
fidelidade. A significa observação registrada; B, Pokepedia; C, cliente; D, teste local;
E, decisão; F, hipótese. Um comentário A não prova uma fórmula escondida no servidor.
O nome `original` identifica a referência local de restauração, que também contém E/F.

Os 202 valores do catálogo e as declarações executáveis dos 22 scripts de regras foram
preservados nesta revisão. A classificação e as unidades dos comentários foram corrigidas.
As questões de Orre, Larvitar e parâmetros de classe 3 continuam sendo questões de produto
e calibração; nenhuma foi encerrada apenas por esta revisão estrutural.

Há fachadas e painéis legados grandes. Continuar extraindo responsabilidades quando uma
mudança funcional justificar, com testes de contrato; não mover centenas de arquivos ou
reformatar todo o projeto sem benefício verificável. O futuro online precisará de uma
camada explícita de transporte e autorização dos comandos; não conectar o F12 ao servidor.
