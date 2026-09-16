class PrayerTimeModel {
  bool? status;
  String? message;
  Data? data;
  bool calculatedLocally;

  PrayerTimeModel({
    this.status,
    this.message,
    this.data,
    this.calculatedLocally = false,
  });

  PrayerTimeModel.fromJson(Map<String, dynamic> json)
    : calculatedLocally = json['calculated_locally'] == true {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (calculatedLocally) data['calculated_locally'] = true;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  String? date;
  bool? isJumma;
  String? imsak;
  String? fajrStart;
  String? sunrise;
  String? zuhrStart;
  String? asrStart;
  String? maghribStart;
  String? ishaStart;
  // Explicit only for a calculated override whose clock can precede the raw
  // Maghrib clock after a personal correction. Older/server data has no hint.
  int? ishaDayOffset;
  String? sehriEnd;
  String? iftarStart;

  Data({
    this.date,
    this.isJumma,
    this.imsak,
    this.fajrStart,
    this.sunrise,
    this.zuhrStart,
    this.asrStart,
    this.maghribStart,
    this.ishaStart,
    int? ishaDayOffset,
    this.sehriEnd,
    this.iftarStart,
  }) : ishaDayOffset = _validDayOffset(ishaDayOffset);

  static int? _validDayOffset(Object? value) =>
      value is int && value >= -1 && value <= 2 ? value : null;

  Data.fromJson(Map<String, dynamic> json) {
    date = json['date'];
    isJumma = json['is_jumma'];
    imsak = json['imsak'];
    fajrStart = json['fajr_start'];
    sunrise = json['sunrise'];
    zuhrStart = json['zuhr_start'];
    asrStart = json['asr_start'];
    maghribStart = json['maghrib_start'];
    ishaStart = json['isha_start'];
    ishaDayOffset = _validDayOffset(json['isha_day_offset']);
    sehriEnd = json['sehri'];
    iftarStart = json['iftar'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['date'] = date;
    data['is_jumma'] = isJumma;
    data['imsak'] = imsak;
    data['fajr_start'] = fajrStart;
    data['sunrise'] = sunrise;
    data['zuhr_start'] = zuhrStart;
    data['asr_start'] = asrStart;
    data['maghrib_start'] = maghribStart;
    data['isha_start'] = ishaStart;
    if (_validDayOffset(ishaDayOffset) != null) {
      data['isha_day_offset'] = ishaDayOffset;
    }
    data['sehri'] = sehriEnd;
    data['iftar'] = iftarStart;
    return data;
  }
}
