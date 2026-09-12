#!/usr/bin/env python3
"""Import the audio collection from an explicitly supplied decoded Android APK.

Usage: python3 tool/import_notification_sounds.py /path/to/decoded/res
MP3s remain byte-identical. iOS notifications use IMA4 AIFF clips under 30s.
"""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve()
ALIASES = {'ali_mullah': 'azan_1', 'abolbaset': 'azan_2', 'dookaly': 'azan_3',
           'short1': 'noti_beep', 'short2': 'noti_beep_beep', 'eqama1': 'noti_1'}
ADHANS = {'ali_mullah', 'abolbaset', 'dookaly', 'albany', 'alsurihy', 'hamd',
          'hijazi', 'naser', 'qasas', 'salah', 'salah_fajr'}
LANGUAGES = ['en', 'fr', 'ar', 'bn', 'es', 'fa', 'id', 'ms', 'tr', 'ur']
LABELS = {}
for lang in LANGUAGES:
    directory = 'values' if lang == 'ar' else 'values-in' if lang == 'id' else 'values-' + lang
    file = SOURCE / directory / 'strings.xml'
    LABELS[lang] = {e.attrib.get('name'): ''.join(e.itertext()) for e in ET.parse(file).getroot()} if file.exists() else {}
FALLBACK = {
    'en': {'before_lastthird': 'Before the last third of the night', 'ring5': 'Fajr alarm 5', 'silent_switch': 'Silent mode tone', 'salah_fajr': 'Salah Al-Dhib — Fajr'},
    'fr': {'before_lastthird': 'Avant le dernier tiers de la nuit', 'ring5': 'Réveil du Fajr 5', 'silent_switch': 'Tonalité du mode silencieux', 'salah_fajr': 'Salah Al-Dhib — Fajr'},
    'ar': {'before_lastthird': 'قبل الثلث الأخير من الليل', 'ring5': 'منبه الفجر 5', 'silent_switch': 'نغمة الوضع الصامت', 'salah_fajr': 'صلاح الذيب — الفجر'},
}
PRAYERS = {
    'en': ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', 'Jumuah', 'sunrise'],
    'fr': ['Fajr', 'Dohr', 'Asr', 'Maghrib', 'Icha', 'vendredi', 'lever du soleil'],
}
for lang, names in PRAYERS.items():
    for prayer, name in zip(['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'jumaa', 'sunrise'], names):
        FALLBACK[lang]['before_prayer_' + prayer] = ('Before ' if lang == 'en' else 'Avant : ') + name
        FALLBACK[lang]['on_prayer_' + prayer] = name + (' time' if lang == 'en' else ' : c’est l’heure')
        FALLBACK[lang]['after_prayer_' + prayer] = (('After ' if lang == 'en' else 'Après : ') if prayer == 'sunrise' else ('Iqama: ' if lang == 'en' else 'Iqama : ')) + name
FALLBACK['fr'].update({'bird': 'Oiseau', 'water': 'Eau', 'telephone': 'Téléphone', 'short_sound': 'Double tonalité',
    'silent_sound': 'Enregistrement silencieux', 'fajr_alarm': 'Annonce du Fajr', 'duha': 'Prière de Duha',
    'last_third': 'Dernier tiers de la nuit', 'midnight': 'Milieu de la nuit', 'jumaa_hour': 'Rappel du vendredi',
    'monday_fasting': 'Jeûne du lundi', 'thursday_fasting': 'Jeûne du jeudi', 'white_days': 'Jours blancs',
    'sleep_azkar': 'Invocations avant de dormir', 'fasting_hadeath': 'Hadith sur le jeûne',
    'morning_azkar1': 'Invocations du matin 1', 'morning_azkar2': 'Invocations du matin 2',
    'evening_azkar1': 'Invocations du soir 1', 'evening_azkar2': 'Invocations du soir 2',
    'eqama1': 'Iqama 1', 'eqama2': 'Iqama 2', 'heya_salah': 'Hayya ‘ala s-salah', 'heya_falah': 'Hayya ‘ala l-falah'})
for number in range(1, 6):
    FALLBACK['fr']['ring' + str(number)] = 'Réveil du Fajr ' + str(number)
    if number < 5:
        FALLBACK['fr']['short' + str(number)] = 'Tonalité ' + str(number)

def encode(file):
    name = file.stem
    key = ALIASES.get(name, 'moatheni_' + name)
    for target in [ROOT / 'assets/audio', ROOT / 'android/app/src/main/res/raw']:
        target.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, target / (key + '.mp3'))
    out = ROOT / 'ios/Runner/Resources' / (key + '.aiff')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(file), '-t', '29', '-ac', '1', '-ar', '22050', '-c:a', 'adpcm_ima_qt', '-f', 'aiff', str(out)], check=True)
    duration = float(subprocess.check_output(['ffprobe', '-v', 'quiet', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(file)], text=True))
    labels = {}
    for lang in LANGUAGES:
        label = FALLBACK.get(lang, {}).get(name) or LABELS[lang].get(name) or FALLBACK['en'].get(name) or LABELS['en'].get(name) or name.replace('_', ' ').title()
        labels[lang] = label
    return {'key': key, 'source': name + '.mp3', 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'durationSeconds': duration,
            'category': 'adhan' if name in ADHANS else 'reminder', 'labels': labels}

files = sorted((SOURCE / 'raw').glob('*.mp3'))
if len(files) != 68:
    raise SystemExit('Expected the reviewed collection of 68 audio files')
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    rows = list(pool.map(encode, files))
rows.sort(key=lambda row: (row['category'] != 'adhan', row['labels']['en']))
manifest = {'sourceApplication': 'com.mahmoud.android.Adani', 'sourceVersion': '3.0.5 (63)',
    'sourceApkSha256': '24ab1a89bede8d9a31ac77a105e94349bf76c3318b356a477f7d0dd7637169f4', 'sounds': rows}
(ROOT / 'assets/audio/catalog.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')

def dart(value):
    return json.dumps(value, ensure_ascii=False).replace('$', '\\$')

lines = ['// Generated by tool/import_notification_sounds.py. Keep stable keys for saved preferences.', 'class NotificationSoundCatalog {', '  static const List<Map<String, String>> sounds = [',
         '    {"key": "silent", "name": "Silent", "labelKey": "notification_silent", "path": "silent", "category": "silent"},']
for row in rows:
    item = {'key': row['key'], 'name': row['labels']['en'], 'labelKey': 'sound_' + row['key'], 'path': 'assets/audio/' + row['key'] + '.mp3', 'category': row['category']}
    lines.append('    {' + ', '.join(dart(k) + ': ' + dart(v) for k, v in item.items()) + '},')
lines.extend(['  ];', '  static final keys = sounds.map((sound) => sound["key"]!).toSet();', '  static bool contains(String key) => keys.contains(key);',
             '  static bool isAdhan(String key) => sounds.any((sound) => sound["key"] == key && sound["category"] == "adhan");', '}'])
(ROOT / 'lib/helper/notification_sound_catalog.dart').write_text('\n'.join(lines) + '\n')
keys = [row['key'] for row in rows]
java = '''package com.example.zabi;

/** Stable allow-list generated by tool/import_notification_sounds.py. */
public final class BundledNotificationSounds {
    private BundledNotificationSounds() {}
    private static final java.util.Set<String> KEYS = new java.util.HashSet<>(java.util.Arrays.asList(
        ''' + ',\n        '.join(json.dumps(k) for k in keys) + '''));
    public static boolean contains(String key) { return key != null && KEYS.contains(key); }
}
'''
target = ROOT / 'android/app/src/main/java/com/example/zabi/BundledNotificationSounds.java'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(java)

for lang in LANGUAGES:
    target = ROOT / 'assets/language' / (lang + '.json')
    data = json.loads(target.read_text())
    for row in rows:
        data['sound_' + row['key']] = row['labels'][lang]
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

# Explicit Xcode resource entries, deterministic IDs; preserves all existing entries.
project = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
content = project.read_text()
new = [key for key in keys if f'/* {key}.aiff */' not in content]
def xid(kind, key):
    return hashlib.sha256(('salatime:notification:' + kind + ':' + key).encode()).hexdigest()[:24].upper()
build = []; refs = []; group = []; resources = []
for key in new:
    file_id, build_id = xid('file', key), xid('build', key)
    build.append(f'\t\t{build_id} /* {key}.aiff in Resources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {key}.aiff */; }};')
    refs.append(f'\t\t{file_id} /* {key}.aiff */ = {{isa = PBXFileReference; lastKnownFileType = audio.aiff; path = {key}.aiff; sourceTree = "<group>"; }};')
    group.append(f'\t\t\t\t{file_id} /* {key}.aiff */,')
    resources.append(f'\t\t\t\t{build_id} /* {key}.aiff in Resources */,')
for marker, entries in [('/* End PBXBuildFile section */', build), ('/* End PBXFileReference section */', refs)]:
    if entries:
        content = content.replace(marker, '\n'.join(entries) + '\n' + marker)
if new:
    content = content.replace('\t\t\t\tD0864F8C2DA32BF80064535A /* azan_1.aiff */,', '\n'.join(group) + '\n\t\t\t\tD0864F8C2DA32BF80064535A /* azan_1.aiff */,')
    content = content.replace('\t\t\t\tD0864F922DA32BF80064535A /* azan_1.aiff in Resources */,', '\n'.join(resources) + '\n\t\t\t\tD0864F922DA32BF80064535A /* azan_1.aiff in Resources */,')
project.write_text(content)
print(f'Imported {len(rows)} sounds with Android, Flutter and iOS resources and translated names.')
