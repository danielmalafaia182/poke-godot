#!/usr/bin/env python3
"""Build Windows verificado, sem apagar builds anteriores ou acessar saves reais.

Uso: python ferramentas/build/montar_build.py refino --godot <executável>
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('poke_quality', ROOT / 'ferramentas/qualidade/verificar.py')
quality = importlib.util.module_from_spec(spec)
spec.loader.exec_module(quality)


def build_path(root: Path, name: str) -> Path:
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}', name):
        raise ValueError('Nome de build inválido; use letras, números, _ e -.')
    if name.upper() in {'CON', 'PRN', 'AUX', 'NUL'} or re.fullmatch(r'(COM|LPT)[1-9]', name.upper()):
        raise ValueError('Nome reservado pelo Windows.')
    base = (root / 'builds').resolve()
    destination = (base / name).resolve()
    if destination.parent != base or destination.exists():
        raise ValueError('O destino precisa ser um build novo dentro de builds/. Use outro nome.')
    return destination


def copy_export_template(isolated: Path) -> None:
    """Somente o template é lido do ambiente instalado; saves/configurações não são copiados."""
    template_root = Path(os.environ.get('APPDATA', '')) / 'Godot/export_templates'
    if not template_root.is_dir():
        raise FileNotFoundError('Templates oficiais não encontrados em APPDATA/Godot/export_templates.')
    for template in template_root.glob('*/windows_release_x86_64.exe'):
        destination = isolated / 'Godot/export_templates' / template.parent.name / template.name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(template, destination)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    parser.add_argument('--godot')
    args = parser.parse_args()
    target = build_path(ROOT, args.name)
    godot = quality.find_godot(args.godot)
    target.mkdir(parents=True)
    logs = ROOT / 'saida_testes/build' / args.name
    logs.mkdir(parents=True, exist_ok=True)
    iso = Path(tempfile.mkdtemp(prefix='poke_build_'))
    env = quality.isolated_env(iso)
    copy_export_template(iso)
    steps = []

    def execute(label, command, *, environment=env, cwd=ROOT, timeout=900):
        result = quality.run(command, environment, logs / f'{label}.log', timeout, require_summary=False, cwd=cwd)
        steps.append(dict(step=label, **result))
        (logs / 'resumo.json').write_text(json.dumps(steps, indent=2, ensure_ascii=False), encoding='utf-8')
        if not result['passed']:
            raise RuntimeError(f'{label} falhou. Consulte {result["log"]}')
        print(f'OK {label} ({result["seconds"]} s)', flush=True)

    execute('exportacao', [str(godot), '--headless', '--path', str(ROOT), '--export-release', 'Windows Desktop', str(target / 'PokeIdle.exe')])
    execute('pacote', [str(godot), '--headless', '--path', str(ROOT), '--script', 'res://ferramentas/build/gerar_pacote_jogo.gd', '--', str(target / 'jogo')], timeout=3600)
    for name in ('gerados', 'pacotes'):
        shutil.copytree(ROOT / 'dados' / name, target / 'dados' / name)
    shutil.copy2(ROOT / 'dados/corpos_por_especie.json', target / 'dados/corpos_por_especie.json')

    verifier = ROOT / 'ferramentas/build/verificar_build.gd'
    play_data = Path(tempfile.mkdtemp(prefix='poke_build_jogo_'))
    for phase in (1, 2, 3):
        if phase == 3:
            import_data = Path(tempfile.mkdtemp(prefix='poke_build_importacao_'))
            old_save = import_data / 'Godot/app_userdata/PokeIdle/progresso_v1.json'
            old_save.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(play_data / 'PokeIdle/progresso_v1.json', old_save)
        phase_env = quality.isolated_env(import_data if phase == 3 else play_data)
        phase_env.update(POKE_VERIFICAR=str(verifier), VERIF_SAIDA=str(logs), VERIF_FASE=str(phase))
        execute(f'fase{phase}', [str(target / 'PokeIdle.exe'), '--headless'], environment=phase_env, cwd=target, timeout=600)
        result_file = logs / f'resultado_fase{phase}.txt'
        result_text = result_file.read_text(encoding='utf-8') if result_file.is_file() else ''
        if f'RESULTADO [fase {phase}]: OK' not in result_text or re.search(r'^FALHA', result_text, re.M):
            raise RuntimeError(f'Fase {phase} não terminou com sucesso. Consulte {result_file}')
        print(result_text.strip(), flush=True)

    manifest = {'created_utc': datetime.now(timezone.utc).isoformat(), 'status': 'verificado', 'files': []}
    for file in sorted(target.rglob('*')):
        if file.is_file():
            with file.open('rb') as stream:
                digest = hashlib.file_digest(stream, 'sha256').hexdigest()
            manifest['files'].append({'path': file.relative_to(target).as_posix(), 'bytes': file.stat().st_size, 'sha256': digest})
    (target / 'manifesto.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(f'BUILD VERIFICADO: {target}')
    return 0


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    try:
        raise SystemExit(main())
    except (ValueError, FileNotFoundError, RuntimeError) as exc:
        print(f'FALHA: {exc}', file=sys.stderr)
        raise SystemExit(1)
