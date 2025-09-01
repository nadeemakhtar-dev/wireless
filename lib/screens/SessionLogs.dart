// lib/screens/session_logs_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SessionType { scan, test }
enum SessionStatus { success, warning, error }

class SessionLog {
  final String id;
  final String title;
  final SessionType type;
  final DateTime startedAt;
  final DateTime endedAt;
  final SessionStatus status;
  final int devicesSeen;
  final int beaconsSeen;
  final int errors;
  final List<String> tags;
  final String notes;

  const SessionLog({
    required this.id,
    required this.title,
    required this.type,
    required this.startedAt,
    required this.endedAt,
    required this.status,
    required this.devicesSeen,
    required this.beaconsSeen,
    required this.errors,
    this.tags = const [],
    this.notes = '',
  });

  Duration get duration => endedAt.difference(startedAt);

  SessionLog copyWith({
    String? id,
    String? title,
    SessionType? type,
    DateTime? startedAt,
    DateTime? endedAt,
    SessionStatus? status,
    int? devicesSeen,
    int? beaconsSeen,
    int? errors,
    List<String>? tags,
    String? notes,
  }) {
    return SessionLog(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      devicesSeen: devicesSeen ?? this.devicesSeen,
      beaconsSeen: beaconsSeen ?? this.beaconsSeen,
      errors: errors ?? this.errors,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'status': status.name,
    'durationSec': duration.inSeconds,
    'devicesSeen': devicesSeen,
    'beaconsSeen': beaconsSeen,
    'errors': errors,
    'tags': tags,
    'notes': notes,
  };

  String toCsvHeader() =>
      'id,title,type,startedAt,endedAt,status,durationSec,devicesSeen,beaconsSeen,errors,tags,notes';

  String toCsvRow() {
    String esc(String s) =>
        '"${s.replaceAll('"', '""').replaceAll('\n', ' ')}"';
    return [
      id,
      title,
      type.name,
      startedAt.toIso8601String(),
      endedAt.toIso8601String(),
      status.name,
      duration.inSeconds.toString(),
      devicesSeen.toString(),
      beaconsSeen.toString(),
      errors.toString(),
      tags.join(';'),
      notes,
    ].map(esc).join(',');
  }
}

class SessionLogStore extends ChangeNotifier {
  final List<SessionLog> _logs = [];

  List<SessionLog> get logs => List.unmodifiable(_logs);

  void seedDemo() {
    if (_logs.isNotEmpty) return;
    final now = DateTime.now();
    _logs.addAll([
      SessionLog(
        id: 'S-001',
        title: 'Lobby Scan',
        type: SessionType.scan,
        startedAt: now.subtract(const Duration(minutes: 35)),
        endedAt: now.subtract(const Duration(minutes: 33, seconds: 10)),
        status: SessionStatus.success,
        devicesSeen: 18,
        beaconsSeen: 12,
        errors: 0,
        tags: const ['lobby', 'ibeacon'],
        notes: 'Strong signals near the entrance.',
      ),
      SessionLog(
        id: 'S-002',
        title: 'Kiosk Firmware Test',
        type: SessionType.test,
        startedAt: now.subtract(const Duration(hours: 2, minutes: 10)),
        endedAt: now.subtract(const Duration(hours: 1, minutes: 58)),
        status: SessionStatus.warning,
        devicesSeen: 5,
        beaconsSeen: 2,
        errors: 1,
        tags: const ['kiosk', 'qa'],
        notes: 'One advertiser dropped packets intermittently.',
      ),
      SessionLog(
        id: 'S-003',
        title: 'Warehouse Sweep',
        type: SessionType.scan,
        startedAt: now.subtract(const Duration(days: 1, hours: 5)),
        endedAt: now.subtract(const Duration(days: 1, hours: 4, minutes: 43)),
        status: SessionStatus.error,
        devicesSeen: 0,
        beaconsSeen: 0,
        errors: 2,
        tags: const ['warehouse'],
        notes: 'Bluetooth was off initially; repeated after enabling.',
      ),
    ]);
    notifyListeners();
  }

  void add(SessionLog log) {
    _logs.insert(0, log);
    notifyListeners();
  }

  void remove(String id) {
    _logs.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}

class SessionLogsScreen extends StatefulWidget {
  const SessionLogsScreen({Key? key}) : super(key: key);

  @override
  State<SessionLogsScreen> createState() => _SessionLogsScreenState();
}

class _SessionLogsScreenState extends State<SessionLogsScreen> {
  final store = SessionLogStore();

  // UI state
  final TextEditingController _searchCtrl = TextEditingController();
  SessionType? _typeFilter; // null = all
  SessionStatus? _statusFilter; // null = all
  _DateRange _dateFilter = _DateRange.last7d;
  _SortBy _sortBy = _SortBy.timeDesc;

  @override
  void initState() {
    super.initState();
    store.seedDemo();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters(store.logs);
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        backgroundColor: Color(0xFF2C5364),
        title: const Text('Session Logs',style: TextStyle(color: Colors.white),),
        actions: [
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: store.logs.isEmpty
                ? null
                : () async {
              final ok = await _confirm(context, 'Delete all logs?');
              if (ok != true) return;
              setState(store.clear);
            },
          ),
          IconButton(
            tooltip: 'Export (CSV to clipboard)',
            icon: const Icon(Icons.table_view_outlined),
            onPressed: filtered.isEmpty ? null : () => _copyCsv(filtered),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _FabNewSession(onNew: _mockAddSession),
      body: Column(
        children: [
          _SearchAndFilters(
            searchCtrl: _searchCtrl,
            typeFilter: _typeFilter,
            statusFilter: _statusFilter,
            dateFilter: _dateFilter,
            onTypeChanged: (t) => setState(() => _typeFilter = t),
            onStatusChanged: (s) => setState(() => _statusFilter = s),
            onDateChanged: (d) => setState(() => _dateFilter = d),
            sortBy: _sortBy,
            onSortChanged: (s) => setState(() => _sortBy = s),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const _EmptyState()
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final log = filtered[i];
                return Dismissible(
                  key: ValueKey(log.id),
                  background: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  secondaryBackground: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  onDismissed: (_) => setState(() => store.remove(log.id)),
                  child: _SessionTile(
                    log: log,
                    onOpen: () => _openDetails(log),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<SessionLog> _applyFilters(List<SessionLog> src) {
    final q = _searchCtrl.text.trim().toLowerCase();
    DateTime? after;
    final now = DateTime.now();
    switch (_dateFilter) {
      case _DateRange.today:
        after = DateTime(now.year, now.month, now.day);
        break;
      case _DateRange.last7d:
        after = now.subtract(const Duration(days: 7));
        break;
      case _DateRange.last30d:
        after = now.subtract(const Duration(days: 30));
        break;
      case _DateRange.all:
        after = null;
        break;
    }

    var list = src.where((e) {
      final matchesQ = q.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          e.notes.toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
      final matchesType = _typeFilter == null || e.type == _typeFilter;
      final matchesStatus = _statusFilter == null || e.status == _statusFilter;
      final matchesDate = after == null || e.startedAt.isAfter(after);
      return matchesQ && matchesType && matchesStatus && matchesDate;
    }).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case _SortBy.timeDesc:
          return b.startedAt.compareTo(a.startedAt);
        case _SortBy.timeAsc:
          return a.startedAt.compareTo(b.startedAt);
        case _SortBy.durationDesc:
          return b.duration.compareTo(a.duration);
        case _SortBy.durationAsc:
          return a.duration.compareTo(b.duration);
      }
    });
    return list;
  }

  Future<void> _copyCsv(List<SessionLog> rows) async {
    final header = rows.first.toCsvHeader();
    final body = rows.map((r) => r.toCsvRow()).join('\n');
    final csv = '$header\n$body';
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copied to clipboard')),
    );
  }

  Future<void> _openDetails(SessionLog log) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => _SessionDetailsSheet(log: log),
    );
  }

  Future<void> _mockAddSession() async {
    // In real app, push a screen that runs a session, then add on return.
    final now = DateTime.now();
    final id = 'S-${(store.logs.length + 1).toString().padLeft(3, '0')}';
    final demo = SessionLog(
      id: id,
      title: 'New Scan ${store.logs.length + 1}',
      type: SessionType.scan,
      startedAt: now.subtract(const Duration(minutes: 2)),
      endedAt: now,
      status: SessionStatus.success,
      devicesSeen: 9,
      beaconsSeen: 6,
      errors: 0,
      tags: const ['demo'],
      notes: 'Auto-added sample session.',
    );
    setState(() => store.add(demo));
  }

  Future<bool?> _confirm(BuildContext context, String text) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
  }
}

class _FabNewSession extends StatelessWidget {
  final Future<void> Function() onNew;
  const _FabNewSession({Key? key, required this.onNew}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: Color(0xFF2C5364),
      onPressed: onNew,
      icon: const Icon(Icons.add,color: Colors.white,),

      label: const Text('New Session',style: TextStyle(color: Colors.white),),
    );
  }
}

// -------------------- Filters/Search Bar --------------------

enum _DateRange { today, last7d, last30d, all }
enum _SortBy { timeDesc, timeAsc, durationDesc, durationAsc }

class _SearchAndFilters extends StatelessWidget {
  final TextEditingController searchCtrl;
  final SessionType? typeFilter;
  final SessionStatus? statusFilter;
  final _DateRange dateFilter;
  final ValueChanged<SessionType?> onTypeChanged;
  final ValueChanged<SessionStatus?> onStatusChanged;
  final ValueChanged<_DateRange> onDateChanged;
  final _SortBy sortBy;
  final ValueChanged<_SortBy> onSortChanged;

  const _SearchAndFilters({
    Key? key,
    required this.searchCtrl,
    required this.typeFilter,
    required this.statusFilter,
    required this.dateFilter,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onDateChanged,
    required this.sortBy,
    required this.onSortChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget chip<T>({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      IconData? icon,
    }) {
      return ChoiceChip(
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
          Text(label),
        ]),
        selected: selected,
        onSelected: (_) => onTap(),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => searchCtrl.clear(),
                tooltip: 'Clear',
              ),
              hintText: 'Search title, tags, notes…',
              filled: true,
              fillColor: cs.surfaceVariant.withOpacity(0.4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              chip(
                label: typeFilter == null ? 'Type: All' : 'Type: ${typeFilter!.name}',
                selected: typeFilter != null,
                icon: Icons.category_outlined,
                onTap: () => _pickType(context),
              ),
              const SizedBox(width: 8),
              chip(
                label: statusFilter == null ? 'Status: All' : 'Status: ${statusFilter!.name}',
                selected: statusFilter != null,
                icon: Icons.flag_outlined,
                onTap: () => _pickStatus(context),
              ),
              const SizedBox(width: 8),
              chip(
                label: switch (dateFilter) {
                  _DateRange.today => 'Today',
                  _DateRange.last7d => 'Last 7 days',
                  _DateRange.last30d => 'Last 30 days',
                  _DateRange.all => 'All time',
                },
                selected: dateFilter != _DateRange.all,
                icon: Icons.calendar_month_outlined,
                onTap: () => _pickDate(context),
              ),
              const SizedBox(width: 8),
              chip(
                label: switch (sortBy) {
                  _SortBy.timeDesc => 'Sort: Time ↓',
                  _SortBy.timeAsc => 'Sort: Time ↑',
                  _SortBy.durationDesc => 'Sort: Duration ↓',
                  _SortBy.durationAsc => 'Sort: Duration ↑',
                },
                selected: true,
                icon: Icons.sort,
                onTap: () => _pickSort(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickType(BuildContext context) async {
    final choice = await showMenu<SessionType?>(
      context: context,
      position: const RelativeRect.fromLTRB(20, 120, 20, 0),
      items: const [
        PopupMenuItem(value: null, child: Text('All types')),
        PopupMenuItem(value: SessionType.scan, child: Text('Scan')),
        PopupMenuItem(value: SessionType.test, child: Text('Test')),
      ],
    );
    if (choice is SessionType? Function()) return; // no-op safeguard
    onTypeChanged(choice);
  }

  Future<void> _pickStatus(BuildContext context) async {
    final choice = await showMenu<SessionStatus?>(
      context: context,
      position: const RelativeRect.fromLTRB(20, 120, 20, 0),
      items: const [
        PopupMenuItem(value: null, child: Text('All statuses')),
        PopupMenuItem(value: SessionStatus.success, child: Text('Success')),
        PopupMenuItem(value: SessionStatus.warning, child: Text('Warning')),
        PopupMenuItem(value: SessionStatus.error, child: Text('Error')),
      ],
    );
    onStatusChanged(choice);
  }

  Future<void> _pickDate(BuildContext context) async {
    final choice = await showMenu<_DateRange>(
      context: context,
      position: const RelativeRect.fromLTRB(20, 120, 20, 0),
      items: const [
        PopupMenuItem(value: _DateRange.today, child: Text('Today')),
        PopupMenuItem(value: _DateRange.last7d, child: Text('Last 7 days')),
        PopupMenuItem(value: _DateRange.last30d, child: Text('Last 30 days')),
        PopupMenuItem(value: _DateRange.all, child: Text('All time')),
      ],
    );
    if (choice != null) onDateChanged(choice);
  }

  Future<void> _pickSort(BuildContext context) async {
    final choice = await showMenu<_SortBy>(
      context: context,
      position: const RelativeRect.fromLTRB(20, 120, 20, 0),
      items: const [
        PopupMenuItem(value: _SortBy.timeDesc, child: Text('Time ↓ (newest first)')),
        PopupMenuItem(value: _SortBy.timeAsc, child: Text('Time ↑')),
        PopupMenuItem(value: _SortBy.durationDesc, child: Text('Duration ↓ (longest first)')),
        PopupMenuItem(value: _SortBy.durationAsc, child: Text('Duration ↑')),
      ],
    );
    if (choice != null) onSortChanged(choice);
  }
}

// -------------------- Tiles / Details --------------------

class _SessionTile extends StatelessWidget {
  final SessionLog log;
  final VoidCallback onOpen;
  const _SessionTile({Key? key, required this.log, required this.onOpen}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color statusColor(SessionStatus s) {
      switch (s) {
        case SessionStatus.success:
          return Colors.teal;
        case SessionStatus.warning:
          return Colors.amber;
        case SessionStatus.error:
          return cs.error;
      }
    }

    final duration = _fmtDuration(log.duration);
    final date = _fmtDateTime(log.startedAt);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onOpen,
        leading: CircleAvatar(
          backgroundColor: cs.surfaceVariant,
          child: Icon(
            log.type == SessionType.scan ? Icons.wifi_tethering : Icons.build_outlined,
            color: cs.onSurfaceVariant,
          ),
        ),
        title: Text(log.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Pill(text: date, icon: Icons.calendar_today_outlined),
              _Pill(text: 'Duration $duration', icon: Icons.timer_outlined),
              _Pill(text: '${log.devicesSeen} devices', icon: Icons.devices_other_outlined),
              _Pill(text: '${log.beaconsSeen} beacons', icon: Icons.place_outlined),
              if (log.errors > 0) _Pill(text: '${log.errors} errors', icon: Icons.error_outline),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor(log.status).withOpacity(.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor(log.status).withOpacity(.4)),
          ),
          child: Text(
            log.status.name.toUpperCase(),
            style: TextStyle(color: statusColor(log.status), fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
class _EmptyState extends StatelessWidget {
  const _EmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined,
                size: 72, color: cs.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              'No session logs yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a scan or test session and your logs will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SessionDetailsSheet extends StatelessWidget {
  final SessionLog log;
  const _SessionDetailsSheet({Key? key, required this.log}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 4, width: 40, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(log.type == SessionType.scan ? Icons.wifi_tethering : Icons.build_outlined),
            title: Text(log.title, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text('${_fmtDateTime(log.startedAt)}  •  ${_fmtDuration(log.duration)}'),
            trailing: _StatusBadge(status: log.status),
          ),
          const SizedBox(height: 8),
          _MetricRow(log: log),
          const SizedBox(height: 8),
          if (log.tags.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: log.tags.map((t) => Chip(label: Text(t))).toList(),
              ),
            ),
          const SizedBox(height: 8),
          if (log.notes.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(log.notes, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final jsonStr = const JsonEncoder.withIndent('  ').convert(log.toJson());
                    Clipboard.setData(ClipboardData(text: jsonStr));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON copied')));
                  },
                  icon: const Icon(Icons.data_object),
                  label: const Text('Copy JSON'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final csv = '${log.toCsvHeader()}\n${log.toCsvRow()}';
                    Clipboard.setData(ClipboardData(text: csv));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied')));
                  },
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Copy CSV'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Close'),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final SessionLog log;
  const _MetricRow({Key? key, required this.log}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final boxes = [
      _MetricBox(icon: Icons.devices_other_outlined, label: 'Devices', value: '${log.devicesSeen}'),
      _MetricBox(icon: Icons.place_outlined, label: 'iBeacons', value: '${log.beaconsSeen}'),
      _MetricBox(icon: Icons.error_outline, label: 'Errors', value: '${log.errors}'),
    ];
    return Row(
      children: boxes
          .map((b) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: b)))
          .toList(),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetricBox({Key? key, required this.icon, required this.label, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SessionStatus status;
  const _StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case SessionStatus.success:
        c = Colors.teal;
        break;
      case SessionStatus.warning:
        c = Colors.amber;
        break;
      case SessionStatus.error:
        c = Theme.of(context).colorScheme.error;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(.4)),
      ),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Pill({Key? key, required this.text, required this.icon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

// -------------------- Helpers --------------------

String _fmtDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

String _fmtDateTime(DateTime t) {
  final y = t.year;
  final mo = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  final h = t.hour.toString().padLeft(2, '0');
  final mi = t.minute.toString().padLeft(2, '0');
  return '$y-$mo-$d $h:$mi';
}
