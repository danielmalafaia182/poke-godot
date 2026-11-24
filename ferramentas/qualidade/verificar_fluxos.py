#!/usr/bin/env python3
"""Fluxos com reinício em processos separados; nenhum save real é usado."""
import json
from pathlib import Path
import re
import sys
import tempfile
from verificar import ROOT, find_godot, isolated_env, run


def main():
    base = Path(tempfile.mkdtemp(prefix='poke_fluxos_'))
    logs = ROOT / 'saida_testes/qualidade' / base.name
    logs.mkdir(parents=True)
    results = []
    godot = str(find_godot())
    command = [godot, '--headless', '--path', str(ROOT)]

    def execute(name, args, env):
        result = run(args, env, logs / (name + '.log'), 300, require_summary=False)
        result['name'] = name
        results.append(result)
        if not result['passed']:
            raise RuntimeError(f'{name}: consulte {result["log"]}')
        return result

    env = isolated_env(base / 'compatibilidade')
    execute('preparar_save_antigo', command + ['--script', 'res://validacao_qualidade/preparar_save.gd'], env)
    result = execute('compatibilidade', command + ['--script', 'res://test_compatibilidade_save.gd'], env)
    if not result['summary']:
        raise RuntimeError('Compatibilidade não informou conclusão.')

    for phase in (1, 2):
        env = isolated_env(base / 'novo_jogo')
        env.update(POKE_VERIFICAR=str(ROOT / 'testes/test_novo_jogo_config.gd'),
                   POKE_NOVO_JOGO_SEM_REINICIAR='1', FASE=str(phase), SAIDA=str(logs))
        execute(f'novo_jogo_{phase}', command, env)
        report = logs / f'novo_jogo_fase{phase}.txt'
        content = report.read_text(encoding='utf-8') if report.exists() else ''
        if re.search(r'^FALHA', content, re.M) or len(re.findall(r'^OK\b', content, re.M)) != (7 if phase == 1 else 5):
            raise RuntimeError(f'Novo jogo, fase {phase}: relatório incompleto ou falha em {report}')
    (logs / 'resumo.json').write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f'RESULTADO: compatibilidade e novo jogo em duas execuções OK; logs: {logs}')
    return 0


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    raise SystemExit(main())
