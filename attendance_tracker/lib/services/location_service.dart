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
    int width = 720,
    int height = 320,
    int zoom = 16,
  }) {
    final markers = <String>['$officeLatitude,$officeLongitude,lightblue1'];

    if (currentLatitude != null && currentLongitude != null) {
      markers.add('$currentLatitude,$currentLongitude,red-pushpin');
    }

    return 'https://staticmap.openstreetmap.de/staticmap.php?'
        'center=$officeLatitude,$officeLongitude&'
        'zoom=$zoom&size=${width}x$height&maptype=mapnik&'
        'markers=${markers.join('|')}';
  }
}
