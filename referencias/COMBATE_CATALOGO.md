# Evolução: agenda de golpes separada do dano

agenda_golpes.gd é um RefCounted independente de nós, efeitos e persistência.
Recebe espécie/nível, mantém tempo de simulação e próximo uso por nome.
configurar preserva os cooldowns existentes ao atualizar os golpes disponíveis.
retirar_pronto reserva a recarga antes de devolver uma cópia do golpe.

Caca tem a agenda do aliado; cada EncontroSelvagem tem a agenda daquele nascimento.
O controlador avança o relógio com delta e processa ataques somente quando
as guardas de alcance/estado já existentes permitem. Não usa await para efeitos.

caca_base.gd conserva o modo de dano fixo anterior e adiciona o modo de catálogo,
ativado por padrão. O cálculo provisório continua especie.dano_base por uso.
Não há fórmula de dano do servidor nem uso de Power como se fosse dano.

O sinal golpe_executado contém encontro_id, slot, aliado, nome, tipo, categoria,
power, cooldown_ms, dano, dano_provisorio, origem e destino. Não carrega o Sprite
nem uma referência ao alvo atual. O sinal dano_aplicado antigo é preservado.

apresentacao_caca usa os dois spritesheets disponíveis. Quando não há um
spritesheet do tipo, usa número de dano em texto. A apresentação não determina
quando termina o cooldown, nem altera HP, coleção ou respawn.

O painel consulta resumos copiados da agenda a cada0.1s, sem reconstruir todos
os controles. Disponibilidade de golpe e momento de efetiva execução podem
diferir até a próxima verificação do timer de combate, que continua em1s.

Pendências do original: prioridade/equipamento/quantidade simultânea de golpes,
política de cooldown ao trocar de caça, fórmula de dano, efeitos adicionais e
spritesheets dos demais tipos. Esses itens não devem ser anunciados como iguais
ao original com base apenas no catálogo de ataques.
