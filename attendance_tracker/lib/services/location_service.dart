import 'package:geolocator/geolocator.dart';

class LocationService {
  static const officeLatitude = 14.03820;
  static const officeLongitude = 100.61732;
  static const maxDistanceMeters = 200.0;

  static Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  static double distanceFromOffice({
    required double latitude,
    required double longitude,
  }) {
    return Geolocator.distanceBetween(
      officeLatitude,
      officeLongitude,
      latitude,
      longitude,
    );
  }

  static bool isWithinOfficeRadius({
    required double latitude,
    required double longitude,
  }) {
    final distance = distanceFromOffice(
      latitude: latitude,
      longitude: longitude,
    );

    return distance <= maxDistanceMeters;
  }

  static String buildStaticMapUrl({
    double? currentLatitude,
    double? currentLongitude,
    int width = 650,
    int height = 300,
    int zoom = 16,
  }) {
    final officePoint = '$officeLongitude,$officeLatitude,pm2blm';
    final currentPoint = currentLatitude != null && currentLongitude != null
        ? '~$currentLongitude,$currentLatitude,pm2rdm'
        : '';

    return 'https://static-maps.yandex.ru/1.x/?'
        'lang=en_US&l=map&z=$zoom&size=${width},$height&'
        'll=$officeLongitude,$officeLatitude&pt=$officePoint$currentPoint';
  }
}
