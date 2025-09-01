import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:wireless/services/ConnectionManager.dart';
import 'BLEcodec.dart';

class CharacteristicTile extends StatefulWidget {
  const CharacteristicTile({
    super.key,
    required this.deviceId,
    required this.serviceId,
    required this.ch,
    required this.ble,
  });

  final String deviceId;
  final Uuid serviceId;
  final DiscoveredCharacteristic ch;
  final ConnectionManager ble;

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  List<int>? _lastRead;
  StreamSubscription<List<int>>? _notifySub;

  final _writeCtl = TextEditingController();
  WriteFormat _fmt = WriteFormat.hex; // assumes your enum has hex, String, byteCsv
  String? _writeError;

  @override
  void dispose() {
    _notifySub?.cancel();
    _writeCtl.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    try {
      final data = await widget.ble.readCharacteristic(
        deviceID: widget.deviceId,
        serviceID: widget.serviceId,
        characteristicID: widget.ch.characteristicId,
      );
      setState(() => _lastRead = data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Read ${data.length} bytes')),
      );
    } catch (e) {
      _toast('Read failed: $e');
    }
  }

  Future<void> _write({required bool withoutResponse}) async {
    try {
      // simple validation for nicer UX
      _validateInput();
      if (_writeError != null) {
        setState(() {}); // show error text
        return;
      }
      final value = BleCodec.encode(_writeCtl.text, _fmt);
      await widget.ble.writeCharacteristic(
        deviceID: widget.deviceId,
        serviceID: widget.serviceId,
        characteristicID: widget.ch.characteristicId,
        value: value,
        withoutResponse: withoutResponse,
      );
      if (!mounted) return;
      _toast('Wrote ${value.length} bytes (${_fmt.name})');
    } catch (e) {
      _toast('Write failed: $e');
    }
  }

  void _validateInput() {
    final t = _writeCtl.text.trim();
    String? err;
    switch (_fmt) {
      case WriteFormat.hex:
        final cleaned = t.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
        if (cleaned.isEmpty) {
          err = 'Enter hex like: A1 B2 0F';
        } else if (cleaned.length.isOdd) {
          err = 'Hex requires an even number of nibbles';
        }
        break;
      case WriteFormat.String:
      // usually safe; no validation
        err = null;
        break;
      case WriteFormat.byteCsv:
        if (t.isEmpty) {
          err = 'Enter CSV bytes like: 1,2,255';
        } else if (!RegExp(r'^\s*\d{1,3}(\s*,\s*\d{1,3})*\s*$').hasMatch(t)) {
          err = 'Use numbers 0-255 separated by commas';
        }
        break;
    }
    _writeError = err;
  }

  void _toggleNotify() async {
    if (_notifySub != null) {
      await _notifySub!.cancel();
      setState(() => _notifySub = null);
      return;
    }
    try {
      final stream = widget.ble.subscribeCharacteristic(
        deviceID: widget.deviceId,
        serviceID: widget.serviceId,
        characteristicID: widget.ch.characteristicId,
      );
      _notifySub = stream.listen((data) {
        setState(() => _lastRead = data);
      }, onError: (e) => _toast('Notify error: $e'));
      setState(() {});
    } catch (e) {
      _toast('Subscribe failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showWriteDialog({required bool canWriteResp, required bool canWriteNoResp}) async {
    final cs = Theme.of(context).colorScheme;

    // local state for the dialog
    final controller = TextEditingController(text: _writeCtl.text);
    WriteFormat fmt = _fmt;
    String? error;

    String hintFor(WriteFormat f) => switch (f) {
      WriteFormat.hex      => 'Hex: e.g. A1 B2 0F or a1b20f',
      WriteFormat.String   => 'String: UTF-8 text',
      WriteFormat.byteCsv  => 'Bytes CSV: e.g. 1, 2, 255',
    };

    String? validate(String text, WriteFormat f) {
      final t = text.trim();
      switch (f) {
        case WriteFormat.hex:
          final cleaned = t.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
          if (cleaned.isEmpty) return 'Enter hex like: A1 B2 0F';
          if (cleaned.length.isOdd) return 'Hex requires an even number of nibbles';
          return null;
        case WriteFormat.String:
          return null;
        case WriteFormat.byteCsv:
          if (t.isEmpty) return 'Enter CSV bytes like: 1,2,255';
          if (!RegExp(r'^\s*\d{1,3}(\s*,\s*\d{1,3})*\s*$').hasMatch(t)) {
            return 'Use numbers 0–255 separated by commas';
          }
          return null;
      }
    }

    Future<void> doWrite({required bool withoutResponse}) async {
      final e = validate(controller.text, fmt);
      if (e != null) {
        error = e;
        (context as Element).markNeedsBuild();
        return;
      }
      try {
        final bytes = BleCodec.encode(controller.text, fmt);
        await widget.ble.writeCharacteristic(
          deviceID: widget.deviceId,
          serviceID: widget.serviceId,
          characteristicID: widget.ch.characteristicId,
          value: bytes,
          withoutResponse: withoutResponse,
        );
        // persist last used in the tile
        _writeCtl.text = controller.text;
        _fmt = fmt;
        if (!mounted) return;
        Navigator.of(context).pop(); // close dialog
        _toast('Wrote ${bytes.length} bytes (${fmt.name})');
      } catch (e) {
        error = 'Write failed: $e';
        (context as Element).markNeedsBuild();
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true, // 👈 lets content scroll when keyboard shows
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Write Characteristic'),
          content: Padding(
            // 👇 pushes content up above the keyboard on small screens
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              width: 380, // optional; dialog width on large screens
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<WriteFormat>(
                    value: fmt,
                    // 👇 compact visual layout
                    isExpanded: true,
                    iconSize: 18,
                    menuMaxHeight: 280,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      labelText: 'Format',
                      isDense: true, // 👈 reduces height
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: WriteFormat.hex,
                        child: _FmtItem(icon: Icons.hexagon_outlined, label: 'Hex', size: 16),
                      ),
                      DropdownMenuItem(
                        value: WriteFormat.String,
                        child: _FmtItem(icon: Icons.text_fields_rounded, label: 'String', size: 16),
                      ),
                      DropdownMenuItem(
                        value: WriteFormat.byteCsv,
                        child: _FmtItem(icon: Icons.data_array_rounded, label: 'Bytes CSV', size: 16),
                      ),
                    ],
                    onChanged: (v) {
                      fmt = v ?? WriteFormat.hex;
                      error = validate(controller.text, fmt);
                      (ctx as Element).markNeedsBuild();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusScope.of(ctx).unfocus(),
                    decoration: InputDecoration(
                      labelText: 'Value',
                      hintText: hintFor(fmt),
                      errorText: error,
                      isDense: true, // 👈 reduces height
                      prefixIcon: const Icon(Icons.edit_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    style: const TextStyle(fontSize: 13.5),
                    onChanged: (t) {
                      error = validate(t, fmt);
                      (ctx as Element).markNeedsBuild();
                    },
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            if (canWriteNoResp)
              TextButton.icon(
                onPressed: () => doWrite(withoutResponse: true),
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text('Write (no resp)'),
              ),
            if (canWriteResp)
              FilledButton.icon(
                onPressed: () => doWrite(withoutResponse: false),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Write (with resp)'),
              ),
          ],
        );
      },
    );

  }


  @override
  Widget build(BuildContext context) {
    final canRead = widget.ch.isReadable;
    final canWriteResp = widget.ch.isWritableWithResponse;
    final canWriteNoResp = widget.ch.isWritableWithoutResponse;
    final canNotify = widget.ch.isNotifiable || widget.ch.isIndicatable;

    final props = <String>[
      if (canRead) 'read',
      if (canWriteResp) 'write',
      if (canWriteNoResp) 'writeNR',
      if (widget.ch.isNotifiable) 'notify',
      if (widget.ch.isIndicatable) 'indicate',
    ];

    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // color: cs.surfaceVariant.withOpacity(.3),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune_rounded),
          ),
          title: Text(
            widget.ch.characteristicId.toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Wrap(
            spacing: 6,
            runSpacing: -6,
            children: props.map((p) => _propChip(p, cs)).toList(),
          ),
          children: [
            // READ & NOTIFY ROW
            Row(
              children: [
                if (canRead)
                  FilledButton.icon(
                    onPressed: _read,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Read'),
                  ),
                if (canRead) const SizedBox(width: 8),
                if (canNotify)
                  FilledButton.tonalIcon(
                    onPressed: _toggleNotify,
                    icon: Icon(_notifySub == null
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined),
                    label: Text(_notifySub == null ? 'Subscribe' : 'Unsubscribe'),
                  ),
                const Spacer(),
                if (_lastRead != null) ...[
                  // IconButton(
                  //   tooltip: 'Copy Hex',
                  //   onPressed: () => Clipboard.setData(
                  //       ClipboardData(text: BleCodec.prettyHex(_lastRead!))),
                  //   icon: const Icon(Icons.copy_rounded),
                  // ),
                  IconButton(
                    tooltip: 'Copy UTF-8',
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: BleCodec.utf8Safe(_lastRead!))),
                    icon: const Icon(Icons.content_copy_rounded),
                  ),
                ],
              ],
            ),

            if (_lastRead != null) ...[
              const SizedBox(height: 8),
              _sectionLabel('Last value (Hex)'),
              const SizedBox(height: 6),
              _lastValuePreview(BleCodec.prettyHex(_lastRead!), cs),

              const SizedBox(height: 12),
              _sectionLabel('Last value (UTF-8)'),
              const SizedBox(height: 6),
              _lastValuePreview(BleCodec.utf8Safe(_lastRead!), cs),

              // Optional: add ASCII fallback line
              // const SizedBox(height: 12),
              // _sectionLabel('ASCII preview'),
              // const SizedBox(height: 6),
              // _lastValuePreview(BleCodec.asciiPreview(_lastRead!), cs),
            ],


            const SizedBox(height: 16),

            // WRITE BLOCK
            if (canWriteResp || canWriteNoResp)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canWriteResp)
                    FilledButton.icon(
                      onPressed: () => _showWriteDialog(canWriteResp: true, canWriteNoResp: canWriteNoResp),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Write…'),
                    ),
                  if (!canWriteResp && canWriteNoResp) // only NR available
                    FilledButton.tonalIcon(
                      onPressed: () => _showWriteDialog(canWriteResp: false, canWriteNoResp: true),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Write…'),
                    ),
                ],
              ),
              // _writeBlock(cs, canWriteResp: canWriteResp, canWriteNoResp: canWriteNoResp),
          ],
        ),
      ),
    );
  }
  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13.5,
    ),
  );


  Widget _writeBlock(ColorScheme cs, {required bool canWriteResp, required bool canWriteNoResp}) {
    final hint = switch (_fmt) {
      WriteFormat.hex => 'e.g. A1 B2 0F or a1b20f',
      WriteFormat.String => 'Plain text (UTF-8)',
      WriteFormat.byteCsv => 'e.g. 1, 2, 255',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Write', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _writeCtl,
                onChanged: (_) {
                  if (_writeError != null) {
                    _validateInput();
                    setState(() {});
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Value',
                  hintText: hint,
                  errorText: _writeError,
                  prefixIcon: const Icon(Icons.edit_rounded),
                  filled: true,
                  fillColor: cs.surface.withOpacity(.7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Paste',
                        icon: const Icon(Icons.content_paste_rounded),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text case final t? when t.isNotEmpty) {
                            _writeCtl.text = t;
                            _validateInput();
                            setState(() {});
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _writeCtl.clear();
                          _validateInput();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<WriteFormat>(
                value: _fmt,
                decoration: InputDecoration(
                  labelText: 'Format',

                  labelStyle: TextStyle(color: Colors.blueGrey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(
                    value: WriteFormat.hex,
                    child: _FmtItem(icon: Icons.hexagon_outlined, label: 'Hex',size: 18,),
                  ),
                  DropdownMenuItem(
                    value: WriteFormat.String,
                    child: _FmtItem(icon: Icons.text_fields_rounded, label: 'String',size: 18,),
                  ),
                  DropdownMenuItem(
                    value: WriteFormat.byteCsv,
                    child: _FmtItem(icon: Icons.data_array_rounded, label: 'Bytes CSV',size: 18,),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _fmt = v ?? WriteFormat.hex;
                    _validateInput();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (canWriteResp)
              FilledButton.icon(
                onPressed: () => _write(withoutResponse: false),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Write (with resp)'),
              ),
            if (canWriteNoResp)
              FilledButton.tonalIcon(
                onPressed: () => _write(withoutResponse: true),
                icon: const Icon(Icons.flash_on_rounded),
                label: const Text('Write (no resp)'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _lastValuePreview(String text, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5),
      ),
    );
  }

  Widget _propChip(String label, ColorScheme cs) {
    final icon = switch (label) {
      'read' => Icons.download_rounded,
      'write' => Icons.upload_rounded,
      'writeNR' => Icons.bolt_rounded,
      'notify' => Icons.notifications_active_outlined,
      'indicate' => Icons.wifi_tethering_rounded,
      _ => Icons.tune_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withOpacity(.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: cs.primary),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _FmtItem extends StatelessWidget {
  const _FmtItem({required this.icon, required this.label, required int size});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(label,style: TextStyle(color: Colors.blueGrey),),
      ],
    );
  }
}
