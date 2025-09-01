import 'dart:convert';

enum WriteFormat{hex,String,byteCsv}

class BleCodec{


  static List<int> encode(String input, WriteFormat fmt) {
    switch (fmt) {
      case WriteFormat.hex:
        return _hexToBytes(input);
      case WriteFormat.String:
        return utf8.encode(input);
      case WriteFormat.byteCsv:
        return _csvToBytes(input);
    }
  }


  static String prettyHex(List<int> data) => data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  static List<int> _hexToBytes(String s) {
    final cleaned = s.replaceAll(RegExp(r"[^0-9a-fA-F]"), '');
    if (cleaned.length % 2 != 0) {
      throw FormatException('Hex string must have even length');
    }
    final out = <int>[];
    for (var i = 0; i < cleaned.length; i += 2) {
      out.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  static List<int> _csvToBytes(String s) {
    final parts = s.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
    final out = <int>[];
    for (final p in parts) {
      final v = int.parse(p);
      if (v < 0 || v > 255) throw FormatException('Byte $v out of range 0..255');
      out.add(v);
    }
    return out;
  }



  // 👇 NEW: safe UTF-8 decode (malformed → �)
  static String utf8Safe(List<int> bytes) =>
      utf8.decode(bytes, allowMalformed: true);

  // 👇 Optional: show printables; replace control bytes with dots
  static String asciiPreview(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      final ch = b & 0xFF;
      if (ch >= 32 && ch <= 126) {
        sb.writeCharCode(ch);
      } else {
        sb.write('·'); // middle dot for non-printable
      }
    }
    return sb.toString();
  }

  // --- private decoders you likely already have ---
  static List<int> _decodeHex(String t) {
    final cleaned = t.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final out = <int>[];
    for (var i = 0; i < cleaned.length; i += 2) {
      out.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  static List<int> _decodeCsv(String t) {
    return t
        .split(',')
        .map((s) => int.parse(s.trim()))
        .toList(growable: false);
  }


}