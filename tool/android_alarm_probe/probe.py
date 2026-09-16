#!/usr/bin/env python3
"""Build-only by default; every device action is an explicit subcommand.

No Gradle changes or third-party test dependencies. Device observations output
only SalaTime schedule aggregates and a whitelist of notification health keys.
"""
import argparse
import collections
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

TARGET = "net.salatime.app.preview"
RUNNER = "net.salatime.alarmprobe/net.salatime.alarmprobe.AlarmProbeInstrumentation"
HERE = Path(__file__).resolve().parent


def run(command, **kwargs):
    return subprocess.run(command, check=True, capture_output=True, text=True, **kwargs).stdout


def build(args):
    sdk = Path(args.sdk).expanduser()
    version = lambda path: tuple(int(n) for n in re.findall(r"\d+", path.name))
    build_tools = sorted((sdk / "build-tools").iterdir(), key=version)[-1]
    platform = sorted((sdk / "platforms").glob("android-*"), key=version)[-1]
    android = platform / "android.jar"
    out = Path(args.out).resolve() if args.out else Path(tempfile.mkdtemp(prefix="salatime-alarm-probe-"))
    out.mkdir(parents=True, exist_ok=True)
    os.chmod(out, 0o700)
    classes, dex = out / "classes", out / "dex"
    classes.mkdir(exist_ok=True)
    dex.mkdir(exist_ok=True)
    run(["javac", "-source", "8", "-target", "8", "-bootclasspath", str(android),
         "-d", str(classes), str(HERE / "AlarmProbeInstrumentation.java")])
    jar = out / "probe-classes.jar"
    run(["jar", "cf", str(jar), "-C", str(classes), "."])
    run([str(build_tools / "d8"), "--min-api", "24", "--lib", str(android),
         "--output", str(dex), str(jar)])
    unsigned, aligned, apk = out / "unsigned.apk", out / "aligned.apk", out / "alarm-probe.apk"
    run([str(build_tools / "aapt"), "package", "-f", "-M", str(HERE / "AndroidManifest.xml"),
         "-I", str(android), "-F", str(unsigned)])
    with zipfile.ZipFile(unsigned, "a", zipfile.ZIP_DEFLATED) as archive:
        archive.write(dex / "classes.dex", "classes.dex")
    run([str(build_tools / "zipalign"), "-f", "4", str(unsigned), str(aligned)])
    # Android's conventional debug keystore only; never read release signing settings.
    run([str(build_tools / "apksigner"), "sign", "--ks", str(Path(args.debug_keystore).expanduser()),
         "--ks-key-alias", "androiddebugkey", "--ks-pass", "pass:android",
         "--key-pass", "pass:android", "--out", str(apk), str(aligned)])
    certificate = run([str(build_tools / "apksigner"), "verify", "--print-certs", str(apk)])
    digest = re.search(r"Signer #1 certificate SHA-256 digest: (\w+)", certificate)
    return {"apk": str(apk), "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
            "signer_sha256": digest.group(1) if digest else None,
            "device_action": "none; APK built locally only"}


def adb(args, *command):
    return run([args.adb, "-s", args.serial, "shell", *command])


def read_preferences(args, filename):
    allowed = {"FlutterSharedPreferences", "scheduled_notifications", "salatime_alarm_delivery",
               "salatime_alarm_window", "salatime_alarm_probe"}
    if filename not in allowed:
        raise ValueError("Preference file outside probe scope")
    try:
        xml = adb(args, "run-as", TARGET, "cat", "shared_prefs/" + filename + ".xml")
    except subprocess.CalledProcessError:
        return {}
    return {element.attrib["name"]: element.attrib.get("value", element.text or "")
            for element in ET.fromstring(xml)}


def stamp(milliseconds):
    return datetime.datetime.fromtimestamp(milliseconds / 1000, datetime.timezone.utc).isoformat()


def schedule_summary(rows, now, payload=False):
    parsed = []
    for row in rows:
        try:
            item = json.loads(row.get("payload", "{}")) if payload else row
            if isinstance(item, dict) and isinstance(item.get("at"), (float, int)):
                parsed.append(item)
        except (ValueError, TypeError):
            continue
    future = [item for item in parsed if item["at"] > now]
    return {"rows": len(rows), "future": len(future), "past": len(parsed) - len(future),
            "kinds": dict(collections.Counter(item.get("kind") for item in future)),
            "first_utc": stamp(min(item["at"] for item in future)) if future else None,
            "last_utc": stamp(max(item["at"] for item in future)) if future else None,
            "within_72h": sum(item["at"] <= now + 3 * 86400000 for item in future),
            "probe_present": any(row.get("id") == 1999000001 for row in rows)}


def alarm_summary(text, now):
    head = re.compile(r"^\s*(RTC_WAKEUP|RTC|ELAPSED_WAKEUP|ELAPSED)\s+#\d+: "
                      r"Alarm\{(\w+) type (\d+) origWhen (\d+) whenElapsed (\d+) ([^}]+)\}")
    records = []
    lines = text.splitlines()
    for index, line in enumerate(lines):
        match = head.match(line)
        if not match or match.group(6) != TARGET:
            continue
        block = []
        for following in lines[index + 1:index + 20]:
            if head.match(following):
                break
            block.append(following)
        block = "\n".join(block)
        tag = re.search(r"tag=(.*)", block)
        records.append({"id": match.group(2), "type": match.group(1), "at": int(match.group(4)),
                        "receiver": tag.group(1).split("/")[-1] if tag else "(none)",
                        "alarm_clock": "Alarm clock:" in block})
    records = list({record["id"]: record for record in records}.values())
    # RTC values are wall-clock milliseconds; elapsed alarms use another clock.
    rtc = [record for record in records if record["type"].startswith("RTC")]
    return {"total": len(records), "types": dict(collections.Counter(r["type"] for r in records)),
            "receivers": dict(collections.Counter(r["receiver"] for r in records)),
            "alarm_clock": sum(r["alarm_clock"] for r in records),
            "first_rtc_utc": stamp(min(r["at"] for r in rtc)) if rtc else None,
            "last_rtc_utc": stamp(max(r["at"] for r in rtc)) if rtc else None,
            "rtc_within_72h": sum(now < r["at"] <= now + 3 * 86400000 for r in rtc)}


def observe(args):
    now = int(adb(args, "date", "+%s").strip()) * 1000
    result = {"observed_at_utc": stamp(now),
              "device_local_time": adb(args, "date", "+%Y-%m-%dT%H:%M:%S%z").strip()}
    try:
        result["running_process_ids"] = adb(args, "pidof", TARGET).strip().split()
    except subprocess.CalledProcessError:
        result["running_process_ids"] = []
    native = read_preferences(args, "scheduled_notifications")
    rows = json.loads(native.get("scheduled_notifications", "[]"))
    result["native_cached"] = schedule_summary(rows, now, payload=True)
    flutter = read_preferences(args, "FlutterSharedPreferences")
    for name in ("prayer_alarm_schedule_v2", "additional_reminder_schedule_v1"):
        result[name] = schedule_summary(json.loads(flutter.get("flutter." + name, "[]")), now)
    result["scheduling_flags"] = {key: flutter.get("flutter." + key) for key in
                                  ("prayer_alarm_inexact_v2", "prayer_alarm_failed_v2")}
    delivery = read_preferences(args, "salatime_alarm_delivery")
    result["delivery"] = {key: delivery[key] for key in
                           ("plannedAt", "deliveredAt", "delayMs", "outcome") if key in delivery}
    window = read_preferences(args, "salatime_alarm_window")
    result["window"] = {key: window[key] for key in
                         ("windowEnd", "timeZone", "exact", "failed", "lastRenewalAt", "nextRenewalAt")
                         if key in window}
    probe = read_preferences(args, "salatime_alarm_probe")
    result["probe_at"] = probe.get("at")
    result["delivery_is_probe"] = bool(probe.get("at") and probe.get("at") == delivery.get("plannedAt"))
    if args.alarms:
        result["armed"] = alarm_summary(adb(args, "dumpsys", "alarm"), now)
    return result


def invoke(args):
    command = ["am", "instrument", "-w", "-r", "-e", "mode", args.mode]
    if args.mode == "schedule":
        command += ["-e", "delay", str(args.delay), "-e", "sound", args.sound]
    output = adb(args, *command, RUNNER)
    # Runner output contains only the deliberately whitelisted probe result.
    return {"instrumentation_output": output.strip()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    builder = subcommands.add_parser("build", help="Local compilation only; never installs")
    builder.add_argument("--sdk", default=os.environ.get("ANDROID_SDK_ROOT", str(Path.home() / "android_sdk")))
    builder.add_argument("--out")
    builder.add_argument("--debug-keystore", default=str(Path.home() / ".android/debug.keystore"))
    builder.set_defaults(action=build)
    for name, action in (("observe", observe), ("invoke", invoke)):
        device = subcommands.add_parser(name)
        device.add_argument("--serial", required=True)
        device.add_argument("--adb", default=shutil.which("adb") or "adb")
        device.add_argument("--output", help="Optional sanitized JSON snapshot under /tmp")
        device.set_defaults(action=action)
        if name == "observe":
            device.add_argument("--alarms", action="store_true", help="Include aggregate native AlarmManager counts")
        else:
            device.add_argument("--mode", choices=("schedule", "status", "renew", "cleanup"), required=True)
            device.add_argument("--delay", type=int, choices=range(30, 121), default=60, metavar="30..120")
            device.add_argument("--sound", choices=("noti_1", "noti_beep", "noti_beep_beep"), default="noti_beep_beep")
    args = parser.parse_args()
    output = Path(args.output).resolve() if getattr(args, "output", None) else None
    if output and not output.is_relative_to(Path("/tmp")):
        raise ValueError("Device snapshots must stay under /tmp")
    result = args.action(args)
    text = json.dumps(result, ensure_ascii=False, indent=2)
    if output:
        output.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as stream:
            stream.write(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
