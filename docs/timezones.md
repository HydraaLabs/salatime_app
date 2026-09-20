# Prayer clocks and changes to legal time

SalaTime previously used timezone 0.9.4's embedded 2024 data. That data still
assumed GMT+1 in Morocco after September 2026. Updating a phone's legal time did
not update this separate Dart database.

The [Moroccan decree 2.26.530](https://bdj.mmsp.gov.ma/Ar/Document/10664-D%C3%A9cret-n-2-26-530du-9-moharrem-1448-25-juin-2026.aspx)
sets clocks back at 02:00 on 20 September 2026 (01:00 UTC), then keeps GMT.
[IANA 2026d](https://data.iana.org/time-zones/tzdb/africa) includes this rule for
Africa/Casablanca and Africa/El_Aaiun.

## Sources of time

`PrayerTimeZones` is shared by calculation, alarm occurrences and widget data.
On Android/iOS it uses the operating system's local-time rules for the device's
current IANA zone. Each scheduled date is evaluated using its own offset, not
merely today's offset. The bounded native calendar covers the requested year
plus the preceding and following years and is cached until the next refresh.
It locates transitions to the second, including non-hour offsets and repeated
hours. Other zones and non-mobile platforms use the bundled IANA database.
Native `DateTime` does not expose a DST flag; the derived calendar relies on the
actual offset and abbreviation only, not an inferred DST label.

This follows the phone's clock and its timezone updates without waiting for a
SalaTime release. It cannot independently correct an incorrect system clock.
No network request or location permission is required to read these rules.

The prayer controller rereads the device zone even when it already has a saved
request. Calculation preferences, prayer-minute adjustments, chosen cities and
published timetables are preserved. Automatic calculations bypass old timetable
caches as before.

## Refresh and alarms

Startup, resume and midnight refresh prayer times and alarms. A foreground
30-second clock watcher additionally detects offset, zone-name and wall-clock
jumps, then recomputes the schedule and rearms the midnight timer. It stops when
the app is paused/disposed. Solar events for upcoming dates already include
known future timezone transitions.

One-off notifications are passed to native plugins in UTC. This avoids a second
interpretation of local clock strings using an older native timezone database.
`scheduleVersion: 2` triggers one migration of existing prayer/extra reminders;
stable IDs and normal reconciliation prevent duplicates. Display payloads keep
the user's local prayer times and zone. Widget epochs use the same clock source.
The OS still controls background execution; an unannounced change while the app
is closed is reconciled at the next allowed refresh.

## Offline data refresh

The application retains its notification-compatible timezone runtime. Data is
regenerated separately from a pinned official IANA archive:

```bash
python3 scripts/refresh_timezones.py --version 2026d --dart /path/to/dart
```

Requires `zic`, the locked timezone package's encoder and a resolved Flutter
package configuration. `lib/data/timezone/provenance.json` records source and
encoded-data SHA-256 hashes; the IANA license accompanies the generated data.
No data is downloaded at app runtime.

Regression coverage includes the exact Moroccan boundary, historical Ramadan,
permanent GMT in subsequent years, Azrou Dohr at 12:14, before/adhan/after alarm
instants, future native rules unknown to the embedded database, both Paris DST
transitions, clock changes while foregrounded, cached-zone replacement, UTC
plugin arguments, and idempotent migration of previously scheduled reminders.
