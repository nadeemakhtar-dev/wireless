import 'dart:convert';

class FavouriteDevice {
  final String id;
  final String name;

  FavouriteDevice({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory FavouriteDevice.fromJson(Map<String, dynamic> json) =>
      FavouriteDevice(id: json['id'], name: json['name'] ?? '');
}
