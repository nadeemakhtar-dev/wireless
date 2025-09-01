import 'package:flutter/material.dart';

class FooterBar extends StatelessWidget {
  final bool scanning;
  final int count;

  const FooterBar({Key? key, required this.scanning, required this.count})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = scanning
        ? 'Scanning… $count beacon${count == 1 ? '' : 's'} found'
        : '$count beacon${count == 1 ? '' : 's'} total';

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
