# Independent Adhan calculation reference

`GeneratePrayerReference.java` is an original test utility. It runs the public
MIT Adhan Kotlin JVM 0.0.5 library independently of SalaTime and its Dart port.
Its named presets, adjustments, rounding and recommended night bounds match
the ones inspected in Moatheni 3.0.5. This does not execute Moatheni's UI or
claim that its APK embeds exactly this Maven release.

The checked-in output is `test/fixtures/adhan_kotlin_0_0_5.csv`: 8 locations,
7 dates, 11 named methods and 2 schools, or 1,232 cases / 7,392 prayer times.
Dates include seasons and daylight-saving transitions. The Flutter test
converts the independent UTC instants into each location's time zone and
requires exact agreement of the six displayed hours/minutes; no extra
minute tolerance or freshly generated SalaTime expectations are used.

Download these published artifacts into a temporary directory from
`https://repo.maven.apache.org/maven2/`, preserving the filenames:

| Maven path | SHA-256 |
| --- | --- |
| `com/batoulapps/adhan/adhan2-jvm/0.0.5/adhan2-jvm-0.0.5.jar` | `0430ba8a677fc7861bc26e7c49c41d4f5cee35861f60efe573563ce42ce3d942` |
| `org/jetbrains/kotlin/kotlin-stdlib/1.9.22/kotlin-stdlib-1.9.22.jar` | `6abe146c27864138b874ccccfe5f534e3eb923c99a1b7b5d45494ee5694f3e0a` |
| `org/jetbrains/kotlinx/kotlinx-datetime-jvm/0.5.0/kotlinx-datetime-jvm-0.5.0.jar` | `bff0d35072d4fafb608052c0875597a0c3bc703ee795246250910f9caff85863` |

Run from the application root, adjusting the temporary directory if needed:

```bash
REFERENCE_CP=/tmp/salatime-calculation-reference/adhan2-jvm-0.0.5.jar:/tmp/salatime-calculation-reference/kotlin-stdlib-1.9.22.jar:/tmp/salatime-calculation-reference/kotlinx-datetime-jvm-0.5.0.jar
javac -cp "$REFERENCE_CP" -d /tmp/salatime-calculation-reference tool/adhan_reference/GeneratePrayerReference.java
java -cp "/tmp/salatime-calculation-reference:$REFERENCE_CP" GeneratePrayerReference > /tmp/adhan-reference.csv
cmp /tmp/adhan-reference.csv test/fixtures/adhan_kotlin_0_0_5.csv
flutter test test/helper/adhan_reference_alignment_test.dart
```

The source artifact is also public at
`com/batoulapps/adhan/adhan2-jvm/0.0.5/adhan2-jvm-0.0.5-sources.jar`, SHA-256
`4ff055ca12eed9429dbfb465282f2ee65db4d3b7467681432a94ed6ead821ef4`.
The fixture SHA-256 is
`dcb167b9c6342606f14acaf88ec2c8001d5f39084c2f00ba3f0bcf8f03a68e46`.

Upstream library: https://github.com/batoulapps/adhan-kotlin.
