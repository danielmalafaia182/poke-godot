"""Executa testes em cópia temporária, com perfil exclusivo por teste.
Evolução: histórico JSON/Markdown, timeout, conclusão explícita e repetição.
Mantém o comando anterior: python validacao_qualidade/executar.py CAMINHO_GODOT
Somente biblioteca padrão do Python; nunca usa shell=True.
"""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid

TESTES = {
    'test_preparo_ataque': 'PREPARO ATAQUE',
    'test_auditoria_geracao': 'AUDITORIA GERACAO',
    'test_perfis_respawn': 'PERFIS RESPAWN',
    'test_nivel_formula_selvagem': 'NIVEL FORMULA SELVAGEM',
    'test_validacao_1x1': 'VALIDACAO 1X1',
    'test_ofensiva_selvagens': 'OFENSIVA SELVAGENS',
    'test_vida_selvagem_candidato': 'VIDA SELVAGEM CANDIDATO',
    'test_dano_candidato': 'DANO CANDIDATO',
    'test_laboratorio_pareado': 'LABORATORIO PAREADO',
    'test_comparador_combate': 'COMPARADOR COMBATE',
    'test_cooldown_troca': 'COOLDOWN TROCA',
    'test_troca_hunt_barras': 'TROCA HUNT E BARRAS',
    'test_calibracao_combate': 'CALIBRACAO COMBATE',
    'test_laboratorio_combate': 'LABORATORIO COMBATE',
    'test_registro_combate': 'REGISTRO COMBATE',
    'test_evolucao_pokemon': 'EVOLUCAO POKEMON',
    'test_loot_hunts': 'LOOT HUNTS',
    'test_progressao_treinador': 'PROGRESSAO TREINADOR',
    'test_dificuldade_hunts': 'DIFICULDADE HUNTS',
    'test_mapa_entre_hunts': 'MAPA ENTRE HUNTS',
    'test_melhor_golpe': 'MELHOR GOLPE',
    'test_togepi_last_resort': 'TOGEPI LAST RESORT',
    'test_cerco_acesso': 'CERCO E ACESSO',
    'test_importacao_especies': 'IMPORTACAO ESPECIES',
    'test_configuracao_hunts': 'CONFIGURACAO HUNTS',
    'test_hunt_generica': 'HUNT GENERICA',
    'test_hunt_larvitar': 'ATAQUES INDEPENDENTES',
    'test_mapa_fiel': 'MAPA FIEL',
    'test_ataques_independentes': 'ATAQUES INDEPENDENTES',
    'test_dano_atributos': 'DANO ATRIBUTOS',
    'test_ajustes_hunt': 'AJUSTES HUNT',
    'test_loot_combate_fiel': 'LOOT COMBATE FIEL',
    'test_depot_cidade_fiel': 'DEPOT CIDADE FIEL',
    'test_team_fiel': 'TEAM FIEL',
    'test_ui_fiel': 'UI FIEL',
    'test_revisao': 'REVISÃO',
    'test_movimento_selvagens': 'MOVIMENTO SELVAGENS',
    'test_hunt_referencias': 'HUNT REFERÊNCIAS',
    'test_qualidade': 'QUALIDADE',
    'test_cidade_qualidade': 'CIDADE',
    'test_compatibilidade_save': 'COMPATIBILIDADE',
    'test_consistencia': 'CONSISTÊNCIA',
    'test_golpes_combate': 'GOLPES COMBATE',
    'test_combate_rapido': 'COMBATE RÁPIDO',
}


def rodar(godot, projeto, destino, nome, argumentos, timeout, marcador=None):
    inicio = time.monotonic()
    comando = [godot, '--headless', '--path', str(projeto), *argumentos]
    motivo = ''
    codigo = None
    try:
        r = subprocess.run(comando, capture_output=True, text=True,
                           encoding='utf-8', errors='replace', timeout=timeout)
        codigo = r.returncode
        log = r.stdout + r.stderr
        if codigo:
            motivo = f'Processo terminou com código {codigo}.'
        elif re.search(r'(?m)(SCRIPT ERROR:|ERROR:)', log):
            motivo = 'Godot registrou erro, mesmo com saída zero.'
        elif marcador and not re.search(marcador, log):
            motivo = 'Mensagem final de conclusão ausente ou inválida.'
    except subprocess.TimeoutExpired as erro:
        def texto(valor):
            return valor.decode('utf-8', 'replace') if isinstance(valor, bytes) else (valor or '')
        log = texto(erro.stdout) + texto(erro.stderr)
        motivo = f'Tempo limite de {timeout}s excedido.'
    except OSError as erro:
        log = str(erro)
        motivo = 'Não foi possível iniciar o executável.'
    arquivo = destino / (nome + '.txt')
    arquivo.write_text(log, encoding='utf-8')
    resultado = {'etapa': nome, 'aprovado': not motivo, 'codigo_saida': codigo,
                 'duracao_segundos': round(time.monotonic()-inicio, 3),
                 'motivo': motivo, 'log': arquivo.name}
    print(f"{nome}: {'OK' if not motivo else 'FALHOU — '+motivo}", flush=True)
    return resultado


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('godot', help='Caminho do executável do editor Godot, inclusive .exe no Windows')
    parser.add_argument('--teste', action='append', choices=list(TESTES), help='Pode repetir para selecionar testes')
    parser.add_argument('--repeticoes', type=int, default=1)
    parser.add_argument('--timeout', type=float, default=180, help='Limite por processo em segundos')
    args = parser.parse_args()
    if args.repeticoes < 1 or args.repeticoes > 20 or args.timeout <= 0:
        parser.error('Use 1 a 20 repetições e timeout positivo.')
    caminho = shutil.which(args.godot) or args.godot
    godot = str(Path(caminho).expanduser().resolve())
    if not Path(godot).is_file():
        parser.error('Executável do Godot não encontrado.')
    origem = Path(__file__).resolve().parent.parent
    if not (origem / 'project.godot').is_file():
        parser.error('Execute o arquivo dentro de validacao_qualidade no projeto.')
    testes = list(dict.fromkeys(args.teste or TESTES))
    for teste in testes:
        if not (origem / (teste+'.gd')).is_file():
            parser.error('Teste não encontrado: '+teste+'.gd')
    identificador = datetime.now().astimezone().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
    resultados = origem / 'validacao_qualidade' / 'resultados' / identificador
    resultados.mkdir(parents=True)
    config_original = (origem / 'project.godot').read_bytes()
    resumo = {'execucao': identificador, 'godot': godot, 'testes_selecionados': testes,
              'repeticoes': args.repeticoes, 'etapas': []}
    try:
        with tempfile.TemporaryDirectory(prefix='pokeidle_qa_') as temp:
            projeto = Path(temp) / 'projeto'
            shutil.copytree(origem, projeto, ignore=shutil.ignore_patterns(
                '.godot', '.git', '__pycache__', 'resultados'))
            config = (projeto / 'project.godot').read_text(encoding='utf-8')
            config = re.sub(r'^EstadoJogo=.*$', 'EstadoJogo="*res://estado_jogo.gd"', config, flags=re.M)
            config = re.sub(r'^run/main_scene=.*$', 'run/main_scene="res://cidade.tscn"', config, flags=re.M)
            config = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n?', '', config, flags=re.M)
            if not re.search(r'^config/name=', config, flags=re.M):
                raise ValueError('config/name ausente: não é seguro iniciar sem isolamento.')

            def preparar_nome():
                nome = 'PokeIdle_QA_'+uuid.uuid4().hex
                texto = re.sub(r'^config/name=.*$', 'config/name="'+nome+'"', config, flags=re.M)
                (projeto / 'project.godot').write_text(texto, encoding='utf-8')
                return nome

            preparar_nome()
            etapa = rodar(godot, projeto, resultados, 'importacao', ['--editor', '--import', '--quit'], args.timeout)
            resumo['etapas'].append(etapa)
            if etapa['aprovado']:
                for repeticao in range(1, args.repeticoes+1):
                    for teste in testes:
                        perfil = preparar_nome()
                        prefixo = f'{repeticao:02d}_{teste}'
                        if teste == 'test_compatibilidade_save':
                            preparacao = rodar(godot, projeto, resultados, prefixo+'_fixture',
                                ['--script', 'res://validacao_qualidade/preparar_save.gd'], args.timeout,
                                r'FIXTURE ANTERIOR PREPARADA')
                            resumo['etapas'].append(preparacao)
                            if not preparacao['aprovado']:
                                continue
                        # Seed global somente no processo de teste, sem mudar scripts de produção.
                        wrapper = projeto / '_qa_execucao.gd'
                        wrapper.write_text(f'extends "res://{teste}.gd"\nfunc _initialize() -> void:\n\tseed(20261105)\n\tsuper._initialize()\n', encoding='utf-8')
                        marcador = re.escape(TESTES[teste])+r':\s*\d+ verificações;\s*0 falhas'
                        etapa = rodar(godot, projeto, resultados, prefixo,
                            ['--script', 'res://_qa_execucao.gd'], args.timeout, marcador)
                        etapa['perfil_isolado'] = perfil
                        resumo['etapas'].append(etapa)
    except (OSError, ValueError, shutil.Error) as erro:
        resumo['erro_executor'] = str(erro)
    finally:
        resumo['config_original_preservada'] = hashlib.sha256(config_original).digest() == hashlib.sha256(
            (origem / 'project.godot').read_bytes()).digest()
        esperado = len(testes)*args.repeticoes
        concluidos = sum('perfil_isolado' in e for e in resumo['etapas'])
        resumo['aprovado'] = (not resumo.get('erro_executor') and resumo['config_original_preservada']
                              and concluidos == esperado and all(e['aprovado'] for e in resumo['etapas']))
        (resultados / 'resumo.json').write_text(json.dumps(resumo, ensure_ascii=False, indent=2), encoding='utf-8')
        linhas = ['# Resultado dos testes', '', '**'+('APROVADO' if resumo['aprovado'] else 'REPROVADO')+'**', '',
                  '| Etapa | Resultado | Segundos |', '|---|---|---:|']
        for etapa in resumo['etapas']:
            linhas.append(f"| {etapa['etapa']} | {'OK' if etapa['aprovado'] else 'FALHOU'} | {etapa['duracao_segundos']} |")
        linhas += ['', 'Configuração original preservada: '+str(resumo['config_original_preservada']), '',
                   'Aprovação cobre os testes executados; não comprova fidelidade visual ou todas as regras do original.']
        (resultados / 'RESUMO.md').write_text('\n'.join(linhas), encoding='utf-8')
    print('Relatório:', resultados, flush=True)
    return 0 if resumo['aprovado'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
