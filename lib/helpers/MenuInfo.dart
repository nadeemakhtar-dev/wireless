import 'dart:typed_data';

class MenuInfo {
  MenuInfo({required this.label, this.payloadHex});
  final String label;
  final String? payloadHex;
}

MenuInfo parseManufacturer(Uint8List data) {
  if (data.isEmpty) return MenuInfo(label: '—');

  // First 2 bytes = Company Identifier (Bluetooth SIG), little-endian
  int companyId = 0;
  if (data.length >= 2) {
    companyId = data[0] | (data[1] << 8);
  }

  final payload = (data.length > 2) ? data.sublist(2) : Uint8List(0);
  final companyName = _companyName(companyId); // best-effort mapping
  final label = companyName != null
      ? '$companyName (0x${companyId.toRadixString(16).padLeft(4, '0').toUpperCase()})'
      : 'Company ID 0x${companyId.toRadixString(16).padLeft(4, '0').toUpperCase()}';

  return MenuInfo(
    label: label,
    payloadHex: payload.isNotEmpty ? _hex(payload) : null,
  );
}

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();

/// Minimal mapping for common Company IDs. Extend as needed.
String? _companyName(int id) {
  switch (id) {
    case 0x004C:
      return 'Apple, Inc.';
    case 0x0006:
      return 'Microsoft';
    case 0x00E0:
      return 'Google';
    case 0x0131:
      return 'Samsung Electronics';
    case 0x000F:
      return 'Broadcom';
    case 0x01DA:
      return 'Xiaomi';
  // Add more as you need…
    default:
      return null;
  }
}
