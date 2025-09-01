// lib/utils/prefs.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/FavouriteModel.dart';

class Prefs {
  // Private constructor
  Prefs._internal();

  // The single instance (lazy loaded)
  static final Prefs _instance = Prefs._internal();

  // Getter to access it
  static Prefs get I => _instance;

  SharedPreferences? _prefs;

  /// Call once at app start (e.g. main())
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ------------------------------
  // Generic helpers
  // ------------------------------

  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  String? getString(String key) => _prefs?.getString(key);

  Future<void> setStringList(String key, List<String> value) async {
    await _prefs?.setStringList(key, value);
  }

  List<String> getStringList(String key) =>
      _prefs?.getStringList(key) ?? [];

  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  Future<void> clear() async {
    await _prefs?.clear();
  }

  // ------------------------------
  // Custom app keys (favourites etc.)
  // ------------------------------

  static const _favouritesKey = 'favourites';

  /// Save a device
  Future<void> addFavourite(FavouriteDevice device) async {
    final favs = getFavourites();
    if (!favs.any((d) => d.id == device.id)) {
      favs.add(device);
      final encoded = favs.map((d) => jsonEncode(d.toJson())).toList();
      await _prefs?.setStringList(_favouritesKey, encoded);
    }
  }

  /// Remove device by ID
  Future<void> removeFavourite(String id) async {
    final favs = getFavourites()..removeWhere((d) => d.id == id);
    final encoded = favs.map((d) => jsonEncode(d.toJson())).toList();
    await _prefs?.setStringList(_favouritesKey, encoded);
  }

  /// Get all saved devices
  List<FavouriteDevice> getFavourites() {
    final list = _prefs?.getStringList(_favouritesKey) ?? [];
    return list
        .map((s) {
      try {
        return FavouriteDevice.fromJson(jsonDecode(s));
      } catch (_) {
        return null;
      }
    })
        .whereType<FavouriteDevice>()
        .toList();
  }

  bool isFavourite(String id) {
    return getFavourites().any((d) => d.id == id);
  }
}
