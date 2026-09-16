/// A city suggestion returned by the Nominatim (OpenStreetMap) search API.
class CitySuggestionModel {
  final String name;
  final String country;
  final String? countryCode;
  final double lat;
  final double lng;

  CitySuggestionModel({
    required this.name,
    required this.country,
    this.countryCode,
    required this.lat,
    required this.lng,
  });

  /// Short display label: "City, Country".
  String get displayName => country.isEmpty ? name : '$name, $country';

  factory CitySuggestionModel.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    String name = (json['name'] ?? '').toString();
    if (name.isEmpty) {
      name =
          (address['city'] ??
                  address['town'] ??
                  address['village'] ??
                  address['municipality'] ??
                  address['state'] ??
                  '')
              .toString();
    }
    return CitySuggestionModel(
      name: name,
      country: (address['country'] ?? '').toString(),
      countryCode: address['country_code']?.toString(),
      lat: double.tryParse((json['lat'] ?? '').toString()) ?? 0,
      lng: double.tryParse((json['lon'] ?? '').toString()) ?? 0,
    );
  }
}
