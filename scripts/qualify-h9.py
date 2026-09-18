"""Run current H9 qualification and retain every historical result.

Requires Python 3, PowerShell 7, Node.js and installed Chrome/Edge. Outputs stay
under ignored receipts/. A qualified result permits only the exact documented
historical presentation failures; it never changes their exit codes or logs.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
OUT = ROOT / 'receipts' / ('h9-qualification-' + stamp)
OUT.mkdir(parents=True, exist_ok=False)
sys.stdout.reconfigure(encoding='utf-8')

def run(command, log):
    result = subprocess.run(command, cwd=ROOT, capture_output=True)
    output = (result.stdout + result.stderr).decode('utf-8', errors='replace')
    (OUT / log).write_text(output, encoding='utf-8')
    return result.returncode, output

def sha(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()

def tree(directory):
    return {p.relative_to(directory).as_posix(): sha(p)
            for p in sorted(directory.rglob('*')) if p.is_file()}

report = {'startedAt': datetime.now(timezone.utc).isoformat(),
          'output': str(OUT), 'tests': [], 'failures': []}
try:
    code, output = run(['pwsh', '-NoProfile', '-File', 'scripts/build-site.ps1'], 'build.log')
    report['buildExitCode'] = code
    if code:
        raise RuntimeError('Build failed; see build.log')
    built_before = tree(ROOT / 'public')
    binding_path = ROOT / 'scripts/fixtures/h9/historical-guard-binding.json'
    bindings = json.loads(binding_path.read_text(encoding='utf-8-sig'))
    expected = {(row['script'], row['failure'].strip()) for row in bindings}
    if len(expected) != len(bindings) or any(row['classification'] != 'SUPERSEDED_DESIGN_CONTRACT' or not row['replacement'] for row in bindings):
        raise RuntimeError('Historical failure binding is malformed')
    report['historicalBindingSha256'] = sha(binding_path)
    contract_path = ROOT / 'scripts/fixtures/h9/qualification-contract.json'
    contract = json.loads(contract_path.read_text(encoding='utf-8-sig'))
    expected_scripts = {row['script']: row for row in contract['tests']}
    if len(expected_scripts) != len(contract['tests']) or sha(binding_path) != contract['historicalBindingSha256']:
        raise RuntimeError('Qualification contract has duplicate tests or an unbound historical mapping')
    report['qualificationContractSha256'] = sha(contract_path)
    actual = set()
    scripts = sorted((ROOT / 'scripts').glob('test-*.ps1'))
    if {s.name for s in scripts} != set(expected_scripts) or len(expected_scripts) != 18:
        raise RuntimeError('The required 18-script qualification roster has changed')
    for script in scripts:
        code, output = run(['pwsh', '-NoProfile', '-File', str(script)], script.stem + '.log')
        passes = re.findall(r'^\s*PASS:.*$', output, re.M)
        failures = [m.strip() for m in re.findall(r'^\s*FAIL:.*$', output, re.M)]
        row = {'script': script.name, 'exitCode': code, 'assertions': len(passes) + len(failures),
               'passed': len(passes), 'failed': len(failures), 'failures': failures}
        report['tests'].append(row)
        actual.update((script.name, failure) for failure in failures)
        footers = re.findall(r'^===.*RESULT: (\d+) passed, (\d+) failed ===\s*$', output, re.M)
        expected_row = expected_scripts[script.name]
        complete = len(footers) == 1 and tuple(map(int, footers[0])) == (len(passes), len(failures))
        if not complete or any(row[key] != expected_row[key] for key in ('assertions', 'passed', 'failed', 'exitCode')):
            report['failures'].append(script.name + ': incomplete execution or unexpected process/assertion totals')
        print(f"{script.name}: {len(passes)}/{row['assertions']} (exit {code})", flush=True)
    report['unexpectedHistoricalFailures'] = sorted(actual - expected)
    report['staleHistoricalBindings'] = sorted(expected - actual)
    if actual != expected:
        report['failures'].append('Historical failures do not match the exact reviewed replacement mapping')
    current = next((t for t in report['tests'] if t['script'] == 'test-h9-binding.ps1'), None)
    if not current or current['failed'] or current['exitCode']:
        report['failures'].append('Current binding guard failed or did not run')
    if tree(ROOT / 'public') != built_before:
        report['failures'].append('Tests changed built output')
    browser_dir = OUT / 'browser'
    code, output = run(['node', 'scripts/capture-h9-binding.mjs', str(browser_dir)], 'browser.log')
    report['browserExitCode'] = code
    browser_path = browser_dir / 'capture-report.json'
    if not browser_path.is_file():
        raise RuntimeError('Browser report missing; see browser.log')
    browser = json.loads(browser_path.read_text(encoding='utf-8-sig'))
    report['browserSummary'] = browser.get('summary')
    report['browserReportSha256'] = sha(browser_path)
    if code or not browser.get('passed') or browser.get('failures'):
        report['failures'].append('Current browser/HTTP qualification failed')
    if len(browser.get('checks', [])) != contract['expectedBrowserAssertions'] or not all(check['passed'] for check in browser.get('checks', [])):
        report['failures'].append('Browser/HTTP assertion roster did not complete')
    if tree(ROOT / 'public') != built_before:
        report['failures'].append('Browser run changed built output')
    report['builtHashes'] = built_before
except Exception as error:
    report['failures'].append(str(error))
finally:
    report['finishedAt'] = datetime.now(timezone.utc).isoformat()
    report['passed'] = not report['failures']
    (OUT / 'qualification.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'passed': report['passed'], 'report': str(OUT / 'qualification.json'),
                      'failures': report['failures']}, indent=2), flush=True)
sys.exit(0 if report['passed'] else 1)
