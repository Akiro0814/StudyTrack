#!/usr/bin/env python3
"""Independent metadata, JSON schema, XML and OOXML validation. Requires openpyxl/PyYAML/jsonschema."""
import json, pathlib, plistlib, zipfile
import jsonschema, openpyxl, yaml
root=pathlib.Path(__file__).resolve().parents[2]
for path in [root/'ios/project.yml', *sorted((root/'.github/workflows').glob('ios-*.yml'))]:
    with path.open() as f: yaml.safe_load(f)
for path in [root/'ios/Toolchain.lock.json',root/'ios/Package.resolved',root/'ios/StudyTrack/Resources/Localizable.xcstrings']:
    json.loads(path.read_text())
plistlib.loads((root/'ios/StudyTrack/Resources/PrivacyInfo.xcprivacy').read_bytes())
schema=json.loads((root/'shared-spec/backup-v1.schema.json').read_text())
jsonschema.Draft202012Validator.check_schema(schema)
for path in [root/'ios/StudyTrackTests/Fixtures/golden.studytrackbackup',root/'artifacts/ios-export.studytrackbackup']:
    if not path.exists(): raise SystemExit(f'Missing generated artifact: {path}')
    with zipfile.ZipFile(path) as z:
        for filename,ref in [('data.json',None),('manifest.json','manifest'),('preferences.json','preferences')]:
            item=json.loads(z.read(filename))
            subschema=schema if ref is None else {'$schema':schema['$schema'],'$defs':schema['$defs'],'$ref':f'#/$defs/{ref}'}
            jsonschema.Draft202012Validator(subschema,format_checker=jsonschema.FormatChecker()).validate(item)
book=openpyxl.load_workbook(root/'artifacts/ios-export.xlsx')
sheet=book['Grades']
assert sheet['C2'].value=='=文字' and sheet['C2'].data_type=='s'
assert sheet['E2'].value==89.5 and sheet['H2'].value is None and sheet['I2'].value==1
assert sheet['K2'].value=='中文\n第二行'
assert [c.value for c in sheet[1]]==['学期','科目','考试名称','时间','分数','满分','分类','班排','年排','区排','反思']
print('PASS: workflow YAML, config JSON, privacy plist, v1 JSON schemas and independent XLSX reader')
