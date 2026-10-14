#!/usr/bin/env python3
import json, os, pathlib, subprocess

root = pathlib.Path(__file__).resolve().parents[1]
artifacts = root.parent / 'artifacts'
artifacts.mkdir(exist_ok=True)
lock = json.loads((root / 'Toolchain.lock.json').read_text())
def run(*args):
    return subprocess.check_output(args, text=True).strip()
if lock['developerDirectory']:
    os.environ['DEVELOPER_DIR'] = lock['developerDirectory']
version = run('xcodebuild', '-version')
sdk = run('xcodebuild', '-showsdks')
sim = json.loads(run('xcrun', 'simctl', 'list', '-j'))
runtimes = [x for x in sim['runtimes'] if x.get('isAvailable') and x['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-26-')]
if not runtimes:
    raise SystemExit('No iOS 26 runtime installed. Run xcodebuild -downloadPlatform iOS, then rerun the probe.')
runtime = next((x for x in runtimes if x['identifier'] == lock['runtimeID']), None) if lock['runtimeID'] else sorted(runtimes,key=lambda x: tuple(int(p) for p in x['version'].split('.')))[-1]
if not runtime:
    raise SystemExit('Locked runtime is unavailable.')
available = [x['deviceTypeIdentifier'] for x in sim['devices'].get(runtime['identifier'],[]) if x.get('isAvailable') and x.get('name','').startswith('iPhone')]
supported = {x['identifier'] for x in runtime.get('supportedDeviceTypes',[]) if x.get('productFamily') == 'iPhone'} or set(available)
if lock['deviceTypeIDs']:
    devices = lock['deviceTypeIDs']
    if not set(devices).issubset(supported):
        raise SystemExit('A locked device type is unsupported by the selected runtime.')
else:
    preferred = ['com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation',
                 'com.apple.CoreSimulator.SimDeviceType.iPhone-17',
                 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max']
    devices = preferred if set(preferred).issubset(supported) else sorted(set(available))
    if not devices:
        raise SystemExit('No compatible iPhone device type discovered for runtime.')
    devices = list(dict.fromkeys([devices[0],devices[len(devices)//2],devices[-1]]))
if lock['xcodeVersion'] and lock['xcodeVersion'] != version:
    raise SystemExit('Xcode changed from locked version.')
if 'Xcode 26.' not in version and 'Xcode 26\n' not in version:
    raise SystemExit('Xcode 26 required.')
actual = dict(lock, status='probe-only-awaiting-simulator-and-device-validation', xcodeVersion=version,
              developerDirectory=os.environ.get('DEVELOPER_DIR') or run('xcode-select','-p'), runtimeID=runtime['identifier'], deviceTypeIDs=devices)
(artifacts / 'Toolchain.candidate.json').write_text(json.dumps(actual,indent=2)+'\n')
(artifacts / 'environment.json').write_text(json.dumps({'xcode':version,'swift':run('swift','--version'),'sdks':sdk,'simulators':sim,'selectedRuntime':runtime,'deviceTypeIDs':devices},indent=2)+'\n')
print(version)
print('Runtime:',runtime['identifier'])
print('Device types:',devices)
