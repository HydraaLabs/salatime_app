#!/usr/bin/env python3
"""Import published QuranEnc editions without changing translations or notes.

Uses only Python 3.11+ standard libraries. Existing manifest hashes pin imports;
--refresh explicitly accepts a newer publisher archive/version. --verify-only
checks installed assets without network access or writes.
"""

import argparse
import concurrent.futures
import datetime
import hashlib
from html.parser import HTMLParser
import io
import json
from pathlib import Path
import re
import sqlite3
import tempfile
import time
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[1]
HOME_URL = "https://quranenc.com/en/home"
CATALOG_URL = "https://quranenc.com/api/v1/translations/list?localization=en"
TERMS_URL = "https://quranenc.com/en/home/api/"
USER_AGENT = "SalaTime-Translation-Import/1.0"
EDITIONS = {
    "fr": ("french_hameedullah", "Muhammad Hamidullah · Rowwad Translation Center"),
    "en": ("english_rwwad", "Rowwad Translation Center"),
    "ar": ("arabic_moyassar", "King Fahd Complex for Printing the Holy Quran in Madinah"),
    "es": ("spanish_garcia", "Muhammad Isa Garcia"),
    "tr": ("turkish_rwwad", "Rowwad Translation Center"),
    "id": ("indonesian_affairs", "Indonesian Ministry of Religious Affairs · Rowwad Translation Center"),
    "ms": ("malay_basumayyah", "Abdullah Basumayyah"),
    "fa": ("persian_ih", "Rowwad Translation Center"),
    "ur": ("urdu_junagarhi", "Muhammad Ibrahim Junagarhi · Rowwad Translation Center"),
    "bn": ("bengali_zakaria", "Dr. Abu Bakr Muhammad Zakaria"),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(raw):
    return hashlib.sha256(raw).hexdigest()


def encode(value):
    return (json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")


def download(url):
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=45) as response:
                require(response.status == 200, "Download did not return HTTP 200")
                raw = response.read(100 * 1024 * 1024 + 1)
                require(len(raw) <= 100 * 1024 * 1024, "Source exceeds 100 MiB")
                return raw
        except Exception:
            if attempt == 2:
                raise
            time.sleep(0.5 * (attempt + 1))


class PublisherCards(HTMLParser):
    """Read publisher metadata for editions omitted from the JSON index."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.cards = []
        self.card = None
        self.depth = 0
        self.in_title = False
        self.in_description = False

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == "div" and "tab_card" in attrs.get("class", "").split():
            require(self.card is None, "Unexpected nested publisher card")
            self.card = {"text": [], "title": [], "description": [], "links": []}
            self.depth = 1
        elif self.card is not None and tag == "div":
            self.depth += 1
        if self.card is not None:
            if tag == "h2":
                self.in_title = True
            if tag == "small":
                self.in_description = True
            if tag == "a":
                self.card["links"].append(attrs.get("href", ""))

    def handle_data(self, data):
        if self.card is not None:
            self.card["text"].append(data)
            if self.in_title:
                self.card["title"].append(data)
            if self.in_description:
                self.card["description"].append(data)

    def handle_endtag(self, tag):
        if tag == "h2":
            self.in_title = False
        if tag == "small":
            self.in_description = False
        if self.card is not None and tag == "div":
            self.depth -= 1
            if self.depth == 0:
                self.cards.append(self.card)
                self.card = None

    def metadata(self, key):
        url = "https://quranenc.com/en/browse/" + key
        matches = [card for card in self.cards if url in card["links"]]
        require(len(matches) == 1, "Expected one publisher card for " + key)
        card = matches[0]
        version = re.search(r"(\d{2}/\d{2}/\d{4})\s*-\s*V(\d+(?:\.\d+)+)", "".join(card["text"]))
        require(version is not None, "Missing publisher version for " + key)
        title = "".join(card["title"]).strip()
        description = "".join(card["description"]).strip()
        require(title and description, "Missing publisher attribution for " + key)
        return {"title": title, "description": description, "version": version[2], "publicationDate": version[1]}


def verse_counts():
    source = ROOT / "assets/quran/surah_list.json"
    raw = source.read_bytes()
    data = json.loads(raw)["data"]
    counts = {int(row["id"]): int(row["verses_count"]) for row in data}
    require(len(data) == len(counts) == 114, "Expected 114 canonical chapters")
    require(sorted(counts) == list(range(1, 115)) and sum(counts.values()) == 6236, "Invalid canonical verse counts")
    return counts, sha256(raw)


def read_archive(raw, key, counts):
    require(raw[:2] == b"PK", "Expected a ZIP archive: " + key)
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        members = archive.namelist()
        databases = [name for name in members if name.rsplit("/", 1)[-1] == key + ".sqlite"]
        require(len(databases) == 1, "Expected exactly one edition database: " + key)
        require(archive.getinfo(databases[0]).file_size <= 100 * 1024 * 1024, "Database exceeds 100 MiB")
        sqlite_bytes = archive.read(databases[0])
    with sqlite3.connect(":memory:") as database:
        database.deserialize(sqlite_bytes)
        database.execute("PRAGMA trusted_schema=OFF")
        require(database.execute("PRAGMA quick_check").fetchone() == ("ok",), "Invalid source SQLite database")
        tables = database.execute("SELECT name FROM sqlite_master WHERE type = 'table'").fetchall()
        require(tables == [("translations",)], "Source added transcript tables; preserve and review them before import")
        rows = database.execute("SELECT id, sura, aya, translation, footnotes FROM translations ORDER BY sura, aya").fetchall()
    require(len(rows) == 6236, "Expected 6236 source verses: " + key)
    verses = {surah: {} for surah in counts}
    ids = set()
    for identifier, surah, aya, translation, footnotes in rows:
        require(type(identifier) is int and identifier not in ids, "Invalid duplicate source row ID")
        ids.add(identifier)
        require(type(surah) is int and surah in counts, "Invalid source chapter")
        require(type(aya) is int and 1 <= aya <= counts[surah], "Invalid source verse")
        require(str(aya) not in verses[surah], "Duplicate source verse")
        require(type(translation) is str and translation.strip(), "Empty or invalid source translation")
        require(type(footnotes) is str, "Non-string footnotes require review; never silently replace content")
        # Copy the SQLite strings exactly. No strip, normalization, HTML
        # removal, generated translation or interpolation is applied.
        verses[surah][str(aya)] = {"translation": translation, "footnotes": footnotes}
    for surah, count in counts.items():
        require(list(verses[surah]) == [str(aya) for aya in range(1, count + 1)], "Missing verse in source corpus")
    return verses, sqlite_bytes, members


def verify_assets(output, counts, manifest=None):
    if manifest is None:
        manifest = json.loads((output / "manifest.json").read_bytes())
    require(manifest["schemaVersion"] == 1 and set(manifest["sources"]) == set(EDITIONS), "Invalid source manifest")
    expected_files = {"manifest.json", "README.md"}
    for language, source in manifest["sources"].items():
        require(source["languageCode"] == language and source["editionKey"] == EDITIONS[language][0], "Unexpected edition selection")
        total = 0
        for surah, count in counts.items():
            name = f"{language}/{surah}.json"
            expected_files.add(name)
            raw = (output / name).read_bytes()
            require(sha256(raw) == source["surahSha256"][str(surah)], "Asset hash mismatch: " + name)
            document = json.loads(raw)
            require(document["schemaVersion"] == 1 and document["languageCode"] == language
                    and document["editionKey"] == source["editionKey"]
                    and document["version"] == source["version"] and document["surah"] == surah, "Mismatched asset metadata")
            require(list(document["verses"]) == [str(aya) for aya in range(1, count + 1)], "Invalid asset coverage: " + name)
            for entry in document["verses"].values():
                require(set(entry) == {"translation", "footnotes"} and type(entry["translation"]) is str
                        and entry["translation"].strip() and type(entry["footnotes"]) is str, "Invalid asset content")
            total += count
        require(total == 6236, "Incomplete edition")
    present = {str(path.relative_to(output)) for path in output.rglob("*") if path.is_file()}
    require(present == expected_files, "Unexpected or missing generated files")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "assets/quran/translations")
    parser.add_argument("--cache-dir", type=Path, default=Path("/tmp/salatime-official-translations"))
    parser.add_argument("--refresh", action="store_true", help="Accept newer publisher versions and hashes")
    parser.add_argument("--verify-only", action="store_true", help="Verify installed files without network or writes")
    args = parser.parse_args()
    counts, index_hash = verse_counts()
    if args.verify_only:
        verify_assets(args.output, counts)
        print("Verified: 10 editions, 114 chapters each, 6236 verses each; stored SHA256 values match.")
        return
    old = None
    if (args.output / "manifest.json").exists():
        old = verify_assets(args.output, counts)
    elif args.output.exists():
        require(not any(args.output.iterdir()), "Refusing to replace a non-generated output directory")
    args.cache_dir.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        home_task = pool.submit(download, HOME_URL)
        catalog_task = pool.submit(download, CATALOG_URL)
        terms_task = pool.submit(download, TERMS_URL)
        home, catalog_raw, terms_raw = home_task.result(), catalog_task.result(), terms_task.result()
    (args.cache_dir / "quranenc-home.html").write_bytes(home)
    (args.cache_dir / "quranenc-api-catalog.json").write_bytes(catalog_raw)
    (args.cache_dir / "quranenc-api-and-terms.html").write_bytes(terms_raw)
    cards = PublisherCards()
    cards.feed(home.decode("utf-8"))
    api = {row["key"]: row for row in json.loads(catalog_raw)["translations"]}
    checked_at = datetime.datetime.now(datetime.timezone.utc).isoformat()

    def prepare(language):
        key, publisher = EDITIONS[language]
        metadata = cards.metadata(key)
        if key in api:
            require(api[key]["version"] == metadata["version"] and api[key]["language_iso_code"] == language, "Publisher metadata changed during import")
        previous = old["sources"][language] if old and not args.refresh else None
        if previous:
            require(previous["version"] == metadata["version"], "Publisher version changed; review and run --refresh: " + key)
        archive_url = f"https://quranenc.com/downloads/sqlite/{key}.zip"
        raw = download(archive_url)
        archive_hash = sha256(raw)
        if previous:
            require(previous["archiveSha256"] == archive_hash, "Pinned publisher archive changed: " + key)
        verses, sqlite_bytes, members = read_archive(raw, key, counts)
        archive_name = f"{key}-v{metadata['version']}-{archive_hash}.zip"
        (args.cache_dir / archive_name).write_bytes(raw)
        (args.cache_dir / f"{key}.sqlite").write_bytes(sqlite_bytes)
        source = {
            "languageCode": language, "editionKey": key, "title": metadata["title"],
            "publisher": publisher, "version": metadata["version"],
            "sourceUrl": "https://quranenc.com/en/browse/" + key,
            "isTafsir": language == "ar", "provider": "QuranEnc.com",
            "description": metadata["description"], "archiveUrl": archive_url,
            "archiveSha256": archive_hash, "sqliteSha256": sha256(sqlite_bytes),
            "archiveBytes": len(raw), "sqliteBytes": len(sqlite_bytes), "verseCount": 6236,
            "metadataProvenance": {
                "sourceUrl": HOME_URL, "sourceSha256": sha256(home), "htmlMetadata": metadata,
                "apiUrl": CATALOG_URL, "apiMetadata": api.get(key),
                "apiCatalogSha256": sha256(catalog_raw), "archiveMembers": members,
                "checkedAt": checked_at,
            },
            "surahSha256": {},
        }
        files = {}
        for surah, content in verses.items():
            document = {"schemaVersion": 1, "languageCode": language, "editionKey": key,
                        "version": source["version"], "surah": surah, "verses": content}
            encoded = encode(document)
            require(json.loads(encoded)["verses"] == content, "Serialization changed source strings")
            files[f"{language}/{surah}.json"] = encoded
            source["surahSha256"][str(surah)] = sha256(encoded)
        source["assetBytes"] = sum(map(len, files.values()))
        print(json.dumps({"language": language, "edition": key, "version": source["version"],
                          "verses": 6236, "assetBytes": source["assetBytes"], "archiveSha256": archive_hash}), flush=True)
        return language, source, files

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        editions = list(pool.map(prepare, EDITIONS))
    manifest = {
        "schemaVersion": 1, "provider": "QuranEnc.com", "sourceTermsUrl": TERMS_URL,
        "termsSnapshotSha256": sha256(terms_raw), "canonicalIndexSha256": index_hash,
        "sources": {language: source for language, source, _ in editions},
    }
    readme = """# Published Quran translations and Arabic tafsir

These files reproduce the published QuranEnc editions listed in `manifest.json`.
They contain 114 surahs and 6,236 verses per language. Arabic uses At-Tafsir
Al-Muyassar; it is an explanatory tafsir, not a translation of the Arabic Quran.
No verse or note was written, translated, normalized, trimmed or edited by the
importer. JSON values preserve the source SQLite text and footnotes exactly,
including punctuation, whitespace, HTML, footnote markers and diacritics.

The manifest preserves every edition's full publisher title and description,
version, source links, available API metadata, HTML publication metadata, archive
members, and SHA256 hashes of source archives, SQLite databases and surah files.
The source SQLite archives contain only the translations table; the importer
refuses an archive with additional transcript tables until these are reviewed.

## Attribution and reuse conditions

Source and conditions: https://quranenc.com/en/home/api/
Publisher catalogue: https://quranenc.com/en/home
API documentation: https://quranenc.com/en/home/api/

QuranEnc explicitly permits downloading and republication subject to preserving
the content, attributing its publisher and QuranEnc.com, identifying the edition
version, retaining transcript information, reporting translation remarks to the
source, following the source's published updates, and avoiding inappropriate
advertisements alongside Quran translations. This is a conditional permission,
not a claim that all these editions are public domain or under a Creative Commons
license. Show the edition title, publisher, QuranEnc.com source and version in the
reader; retain the footnotes and this provenance when redistributing the assets.
Do not replace or paraphrase unavailable content with generated translations.

Some public editions are omitted from the JSON catalogue but remain published on
the official website and available as official SQLite exports and surah API
responses. Their metadata is taken from the website's corresponding edition card,
not invented from an internal identifier. In particular, the English key
`english_saheeh` currently names Noor International, so it must not automatically
be attributed to Sahih International. This package uses `english_rwwad` instead.

## Reproduction and validation

From the Flutter repository, Python 3.11+ with its standard libraries is enough:

```sh
python3 tools/import_quranenc_translations.py --verify-only
python3 tools/import_quranenc_translations.py
```

The first command is offline and read-only. The second downloads the official
archives and requires their hashes and versions to match the existing manifest.
Use `--refresh` only after reviewing a new publisher version; it replaces the
generated assets and their pinned hashes. Every import checks exact canonical
surah/verse coverage, unique source IDs, nonempty translation strings, footnote
types, source SQLite integrity, and byte hashes. Each serialized translation and
footnote is compared with its original SQLite value before installation. Files
are partitioned per surah so readers do not load an entire annotated edition.

Original archives, SQLite databases and metadata/terms snapshots are kept outside
the repository in `/tmp/salatime-official-translations` by default. They are
verification evidence, not additional app assets. Generated local assets are
validated before writing to the output directory; no build or publication occurs.
"""
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="quranenc-stage-", dir=args.cache_dir) as stage_path:
        stage = Path(stage_path)
        for _, _, files in editions:
            for relative, raw in files.items():
                destination = stage / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(raw)
        (stage / "README.md").write_text(readme, encoding="utf-8")
        (stage / "manifest.json").write_bytes(encode(manifest))
        verify_assets(stage, counts, manifest)
        # Keep the manifest last; never delete unrelated files or directories.
        for source in sorted(stage.rglob("*")):
            if not source.is_file() or source.name == "manifest.json":
                continue
            destination = args.output / source.relative_to(stage)
            destination.parent.mkdir(parents=True, exist_ok=True)
            temporary = destination.with_suffix(destination.suffix + ".importing")
            temporary.write_bytes(source.read_bytes())
            temporary.replace(destination)
        temporary = args.output / "manifest.json.importing"
        temporary.write_bytes((stage / "manifest.json").read_bytes())
        temporary.replace(args.output / "manifest.json")
    verify_assets(args.output, counts, manifest)
    print("Imported and verified 10 published editions / 1140 surah files / 62360 verse records.")


if __name__ == "__main__":
    main()
