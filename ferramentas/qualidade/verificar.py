#!/usr/bin/env python3
"""Regressão reproduzível com logs completos e dados do jogador sempre isolados.

python ferramentas/qualidade/verificar.py --suite smoke --godot <executável>
python ferramentas/qualidade/verificar.py --suite full
python ferramentas/qualidade/verificar.py testes/test_regras_gm.gd

O exit code sozinho não basta: Godot pode imprimir SCRIPT ERROR e retornar zero.
Os testes que exigem fixtures externas têm seus próprios wrappers; --suite full
roda os testes GDScript autônomos atuais, inclusive os testes legados da raiz.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
SMOKE = [
    'test_regras_seguranca', 'test_regras_gm', 'test_recarga_regras',
    'test_novo_jogo_falhas', 'test_game_master_dock', 'test_painel_gm',
    'test_regressao_referencia', 'test_sim_regras', 'test_sim_determinismo',
    'test_caca_sim', 'test_save_fase3', 'test_ciclo_cidade',
]
# Estes precisam de argumentos/fixtures/duas execuções; não são testes autônomos.
WRAPPERS = {
    'test_novo_jogo_config', 'test_reabrir', 'test_todas_hunts',
    'test_render_interpolacao', 'test_render_regras', 'test_render_sombras', 'test_outfits',
}
ERROR = re.compile(r'(?im)^.*(?:SCRIPT ERROR|Parse Error|^ERROR:|^FALHA\b|^FALHOU\b|^FAIL\b|\bfalha:|leaked at exit|ObjectDB instances leaked|RIDs? .*leaked).*$')
SUMMARY = re.compile(r'(?im)^.*(?:RESULTADO:|COMPATIBILIDADE:|verificaç[õo]es.*falhas|^OK:).*$')


def find_godot(explicit: str | None = None) -> Path:
    candidates = [explicit, os.environ.get('GODOT'), shutil.which('godot'), shutil.which('godot4')]
    # Instalação ao lado do projeto é uma conveniência, sem nome de usuário fixo.
    candidates += sorted((ROOT.parent / 'Godot').glob('*console.exe'), reverse=True)
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate).resolve()
    raise FileNotFoundError('Informe --godot ou a variável GODOT com o executável do Godot 4.7.')


def isolated_env(folder: Path, profile: str = 'original') -> dict[str, str]:
    """Isola também configurações/cache; nunca aponta para APPDATA do jogador."""
    folder = folder.resolve()
    folder.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for key in ('POKE_VERIFICAR', 'VERIF_FASE', 'VERIF_SAIDA', 'POKE_NOVO_JOGO_SEM_REINICIAR'):
        env.pop(key, None)
    env.update(APPDATA=str(folder), LOCALAPPDATA=str(folder / 'local'),
               XDG_DATA_HOME=str(folder), XDG_CONFIG_HOME=str(folder / 'config'),
               XDG_CACHE_HOME=str(folder / 'cache'), PYTHONIOENCODING='utf-8')
    for relative in ('Godot/app_userdata/PokeIdle', 'godot/app_userdata/PokeIdle', 'PokeIdle'):
        marker = folder / relative / 'regras/perfil.txt'
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.write_text(profile, encoding='utf-8')
    return env


def assess(log: str, code: int, require_summary: bool = True) -> dict:
    log = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', log)
    errors = ERROR.findall(log)
    summaries = SUMMARY.findall(log)
    for passed, total in re.findall(r'(?im)RESULTADO:\s*(\d+)\s*/\s*(\d+)', log):
        if int(total) == 0 or int(passed) != int(total):
            errors.append(f'Contagem de testes incompleta: {passed}/{total}')
    # Vazamentos são erros, inclusive os antigos. O relatório não os mascara.
    return {'passed': code == 0 and not errors and (bool(summaries) or not require_summary),
            'code': code, 'errors': errors, 'summary': summaries}


def run(command: list[str], env: dict[str, str], log_path: Path, timeout: int, *, require_summary: bool = True, cwd: Path = ROOT) -> dict:
    start = time.monotonic()
    try:
        process = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, timeout=timeout)
        raw, code = process.stdout, process.returncode
    except subprocess.TimeoutExpired as exc:
        raw, code = exc.stdout or b'', 124
    log = raw.decode('utf-8', errors='replace')
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(log, encoding='utf-8')
    return dict(assess(log, code, require_summary), seconds=round(time.monotonic() - start, 2), log=str(log_path))


def scripts_for(suite: str) -> list[str]:
    if suite == 'smoke':
        return [f'testes/{name}.gd' for name in SMOKE]
    paths = [p for p in sorted((ROOT / 'testes').glob('test_*.gd'))
             if p.stem not in WRAPPERS and re.search(r'^extends SceneTree\s*$', p.read_text(encoding='utf-8'), re.M)]
    paths += [p for p in sorted(ROOT.glob('test_*.gd')) if p.stem != 'test_compatibilidade_save']
    return [p.relative_to(ROOT).as_posix() for p in paths]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scripts', nargs='*')
    parser.add_argument('--suite', choices=('smoke', 'full'), default='smoke')
    parser.add_argument('--godot')
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    godot = find_godot(args.godot)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ')
    output = args.output or ROOT / 'saida_testes/qualidade' / stamp
    output.mkdir(parents=True, exist_ok=True)
    results = []
    for name in args.scripts or scripts_for(args.suite):
        relative = name.removeprefix('res://')
        script = (ROOT / relative).resolve()
        if not script.is_relative_to(ROOT) or not script.is_file() or script.suffix != '.gd':
            parser.error(f'Teste inválido: {name}')
        ident = script.relative_to(ROOT).as_posix().replace('/', '_')
        iso = Path(tempfile.mkdtemp(prefix='poke_qualidade_'))
        result = run([str(godot), '--headless', '--path', str(ROOT), '--script', 'res://' + relative],
                     isolated_env(iso), output / f'{ident}.log', args.timeout)
        result.update(script=relative, isolated_data=str(iso))
        results.append(result)
        print(f'{"OK" if result["passed"] else "FALHA"} {relative} ({result["seconds"]} s)', flush=True)
        if not result['passed']:
            for error in result['errors'][:4]:
                print('  ' + error.strip(), flush=True)
        report = {'godot': str(godot), 'results': results, 'passed': all(r['passed'] for r in results)}
        (output / 'resumo.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f'RESULTADO: {sum(r["passed"] for r in results)}/{len(results)}; relatório: {output}')
    return 0 if results and all(r['passed'] for r in results) else 1


if __name__ == '__main__':
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    raise SystemExit(main())
