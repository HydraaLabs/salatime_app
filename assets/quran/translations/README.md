# Published Quran translations and Arabic tafsir

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
