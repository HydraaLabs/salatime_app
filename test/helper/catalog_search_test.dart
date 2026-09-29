import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/catalog_search.dart';

void main() {
  test('matches French accents, case and transliteration separators', () {
    expect(matchesCatalogSearch('ouverture', ['L’Ouverture']), isTrue);
    expect(matchesCatalogSearch('RECITATEUR', ['Récitateur']), isTrue);
    expect(matchesCatalogSearch('albaqarah', ['Al-Baqarah']), isTrue);
    expect(matchesCatalogSearch('e\u0301le\u0300ve', ['Élève']), isTrue);
    expect(matchesCatalogSearch('ISIK', ['Işık']), isTrue);
  });

  test('matches Arabic vocalization, tatweel, alif and Persian letters', () {
    expect(matchesCatalogSearch('الفاتحه', ['ٱلْفَاتِحَة']), isTrue);
    expect(matchesCatalogSearch('احمد', ['أَحْـمَد']), isTrue);
    expect(matchesCatalogSearch('علي', ['علی']), isTrue);
    expect(matchesCatalogSearch('الكهف', ['الکهف']), isTrue);
    expect(normalizeCatalogSearch('١٢٣ ۴۵۶'), '123 456');
  });

  test('combines words across localized and Arabic names, ignoring blanks', () {
    const names = ['La vache', 'البقرة', 'Al-Baqarah', null];
    expect(matchesCatalogSearch('vache البقره', names), isTrue);
    expect(matchesCatalogSearch('   ', names), isTrue);
    expect(matchesCatalogSearch('vache عمران', names), isFalse);
    expect(matchesCatalogSearch('unmatched', []), isFalse);
  });

  test('keeps Bengali vowel signs and script-specific letters intact', () {
    expect(normalizeCatalogSearch('সূরা'), 'সূরা');
    expect(matchesCatalogSearch('সূরা', ['সূরা আল ফাতিহা']), isTrue);
    expect(matchesCatalogSearch('سوره', ['سور']), isFalse);
  });
}
