// Models for the mp3quran.net API (https://mp3quran.net/ar/api).
// Audio URL pattern: {moshaf.server}{suraNumber padded to 3 digits}.mp3

class Mp3QuranResponse {
  List<Mp3QuranReciter>? reciters;

  Mp3QuranResponse({this.reciters});

  Mp3QuranResponse.fromJson(Map<String, dynamic> json) {
    if (json['reciters'] != null) {
      reciters = <Mp3QuranReciter>[];
      json['reciters'].forEach((v) {
        reciters!.add(Mp3QuranReciter.fromJson(v));
      });
    }
  }
}

class Mp3QuranReciter {
  int? id;
  String? name;
  String? letter;
  List<Moshaf>? moshaf;

  Mp3QuranReciter({this.id, this.name, this.letter, this.moshaf});

  Mp3QuranReciter.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    letter = json['letter'];
    if (json['moshaf'] != null) {
      moshaf = <Moshaf>[];
      json['moshaf'].forEach((v) {
        moshaf!.add(Moshaf.fromJson(v));
      });
    }
  }
}

class Moshaf {
  int? id;
  String? name;
  String? server;
  int? surahTotal;
  List<int> surahList = [];

  Moshaf({this.id, this.name, this.server, this.surahTotal});

  Moshaf.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    server = json['server'];
    surahTotal = json['surah_total'];
    if (json['surah_list'] != null) {
      surahList = json['surah_list']
          .toString()
          .split(',')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .where((e) => e > 0)
          .toList();
    }
  }

  /// URL of a sura mp3, e.g. https://server6.mp3quran.net/akdr/001.mp3
  String suraUrl(int suraNumber) =>
      '$server${suraNumber.toString().padLeft(3, '0')}.mp3';
}
