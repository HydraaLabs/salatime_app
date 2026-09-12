/// Stable identifiers shared by local calculation, saved preferences and API.
class PrayerCalculationMethod {
  const PrayerCalculationMethod(this.id, this.fallbackName);

  final String id;
  final String fallbackName;
  String get nameKey => 'calculation_method_$id';
}

class PrayerCalculationMethods {
  static const defaultId = '1';

  static const all = <PrayerCalculationMethod>[
    PrayerCalculationMethod('3', 'Muslim World League (MWL)'),
    PrayerCalculationMethod('5', 'Egyptian General Authority of Survey'),
    PrayerCalculationMethod('1', 'University of Islamic Sciences, Karachi'),
    PrayerCalculationMethod('4', 'Umm Al-Qura University, Makkah'),
    PrayerCalculationMethod('16', 'United Arab Emirates — Dubai'),
    PrayerCalculationMethod('10', 'Qatar'),
    PrayerCalculationMethod('9', 'Kuwait'),
    PrayerCalculationMethod('15', 'Moonsighting Committee'),
    PrayerCalculationMethod(
      '11',
      'Singapore — Majlis Ugama Islam Singapura (MUIS)',
    ),
    PrayerCalculationMethod('2', 'Islamic Society of North America (ISNA)'),
    PrayerCalculationMethod('13', 'Turkey — Diyanet İşleri Başkanlığı'),
    PrayerCalculationMethod(
      '21',
      'Morocco — Ministry of Habous and Islamic Affairs',
    ),
    PrayerCalculationMethod(
      '12',
      'France — Union of Islamic Organisations (UOIF)',
    ),
    PrayerCalculationMethod('19', 'Algeria'),
    PrayerCalculationMethod('18', 'Tunisia'),
    PrayerCalculationMethod('8', 'Gulf Region'),
    PrayerCalculationMethod(
      '17',
      'Malaysia — Jabatan Kemajuan Islam Malaysia (JAKIM)',
    ),
    PrayerCalculationMethod('20', 'Indonesia — Kementerian Agama (KEMENAG)'),
    PrayerCalculationMethod('23', 'Jordan'),
    PrayerCalculationMethod('22', 'Portugal — Islamic Community of Lisbon'),
    PrayerCalculationMethod(
      '14',
      'Spiritual Administration of Muslims of Russia',
    ),
    PrayerCalculationMethod(
      '7',
      'Institute of Geophysics, University of Tehran',
    ),
    PrayerCalculationMethod(
      '0',
      'Shia Ithna-Ashari — Leva Institute, Qum (Jafari)',
    ),
  ];

  static final ids = Set<String>.unmodifiable(all.map((method) => method.id));

  static bool contains(String? id) => ids.contains(id);

  static PrayerCalculationMethod? byId(String? id) {
    for (final method in all) {
      if (method.id == id) return method;
    }
    return null;
  }
}
