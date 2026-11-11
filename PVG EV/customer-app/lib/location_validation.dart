import 'dart:math' as math;

const chennaiMapLatitude = 13.0827, chennaiMapLongitude = 80.2707;
const chennaiPinError =
    'This pin is far from Chennai or is invalid. Retry GPS at your charging address, choose the correct pin on the map, or remove the pin and continue with your address.';

/// A broad sanity check for an obviously mismatched pin, not service coverage.
bool isChennaiPin(num latitude, num longitude) {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    return false;
  }
  const radians = math.pi / 180;
  final lat = latitude * radians, centre = chennaiMapLatitude * radians;
  final dLat = (latitude - chennaiMapLatitude) * radians;
  final dLon = (longitude - chennaiMapLongitude) * radians;
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat) * math.cos(centre) * math.pow(math.sin(dLon / 2), 2);
  final km = 6371 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  return km <= 150;
}

String? chargingPinValidationError(num? latitude, num? longitude) {
  if (latitude == null && longitude == null) return null;
  return latitude != null &&
          longitude != null &&
          isChennaiPin(latitude, longitude)
      ? null
      : chennaiPinError;
}
