# Content-source evidence — 17 September 2026

Prepared for SalaTime 1.0.22 (28), App Review guideline 2.1.

## Public permission sources

- MP3Quran: https://www.mp3quran.net/eng/privacy — its Copyrights section permits visitors and developers to copy materials and use site links. Checked live on 17 September 2026.
- QuranEnc: https://quranenc.com/en/home/api — permits republication subject to preservation, source/publisher attribution, version identification, retained metadata, reporting translation observations, updates, and avoiding inappropriate advertisements. Checked live on 17 September 2026.

These are public provider permissions, not private agreements or an endorsement. The owner confirms these are the sources relied upon.

## Bundled editions

Manifest matches release source commit 4e25332 byte for byte. SHA-256: `eef9cb9b3953b4dedc22fcdbeee00df7b97fd9ced237870b476ed49999ef1b46`.

| Language | Edition | Version | Publisher | Source |
|---|---|---|---|---|
| fr | french_hameedullah | 1.0.2 | Muhammad Hamidullah · Rowwad Translation Center | [QuranEnc](https://quranenc.com/en/browse/french_hameedullah) |
| en | english_rwwad | 1.0.19 | Rowwad Translation Center | [QuranEnc](https://quranenc.com/en/browse/english_rwwad) |
| ar | arabic_moyassar | 1.0.0 | King Fahd Complex for Printing the Holy Quran in Madinah | [QuranEnc](https://quranenc.com/en/browse/arabic_moyassar) |
| es | spanish_garcia | 1.0.2 | Muhammad Isa Garcia | [QuranEnc](https://quranenc.com/en/browse/spanish_garcia) |
| tr | turkish_rwwad | 1.0.4 | Rowwad Translation Center | [QuranEnc](https://quranenc.com/en/browse/turkish_rwwad) |
| id | indonesian_affairs | 1.0.1 | Indonesian Ministry of Religious Affairs · Rowwad Translation Center | [QuranEnc](https://quranenc.com/en/browse/indonesian_affairs) |
| ms | malay_basumayyah | 1.0.0 | Abdullah Basumayyah | [QuranEnc](https://quranenc.com/en/browse/malay_basumayyah) |
| fa | persian_ih | 1.1.3 | Rowwad Translation Center | [QuranEnc](https://quranenc.com/en/browse/persian_ih) |
| ur | urdu_junagarhi | 1.1.3 | Muhammad Ibrahim Junagarhi · Rowwad Translation Center | [QuranEnc](https://quranenc.com/en/browse/urdu_junagarhi) |
| bn | bengali_zakaria | 1.1.1 | Dr. Abu Bakr Muhammad Zakaria | [QuranEnc](https://quranenc.com/en/browse/bengali_zakaria) |

Each edition contains 6,236 entries across 114 chapters. Translations and footnotes are bundled; MP3Quran audio is retrieved from the provider.

## Implementation and provenance

- `lib/service/quran/quran_translation_repository.dart`: bundled text/notes, edition and version validation.
- `lib/view/screens/quran/widget/quran_translation_source_card.dart`: source title, publisher/version and link.
- `lib/view/screens/quran/widget/quran_translation_text.dart`: reader attribution.
- `assets/quran/translations/manifest.json`: edition metadata and source archive/chapter hashes.
- `assets/quran/translations/README.md`: source import and preservation process.
- `tools/import_quranenc_translations.py --verify-only`: local coverage/hash verification.

The historical upstream texts mentioned in THIRD_PARTY_NOTICES.md must not be confused with the QuranEnc editions selected by the submitted reader. The public permissions cited here apply to their respective source materials; they do not license unrelated fonts, libraries or assets.
