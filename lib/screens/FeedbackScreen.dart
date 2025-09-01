import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _msgCtl = TextEditingController();
  String _category = 'Bug report';
  int _rating = 0;
  bool _includeLogs = true;
  bool _includeDeviceInfo = true;
  bool _consent = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _msgCtl.dispose();
    super.dispose();
  }

  // ---- Send via email (replace with your backend if needed) ----
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept consent to continue.')),
      );
      return;
    }
    setState(() => _submitting = true);

    final subject = Uri.encodeComponent('[Wireless] $_category (${_rating}★)');
    final deviceInfo = _includeDeviceInfo
        ? 'Device: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n'
        : '';
    final logsInfo = _includeLogs ? '(logs attached or referenced)' : '(no logs)';
    final body = Uri.encodeComponent('''
Name: ${_nameCtl.text.trim().isEmpty ? '-' : _nameCtl.text.trim()}
Email: ${_emailCtl.text.trim().isEmpty ? '-' : _emailCtl.text.trim()}
Category: $_category
Rating: $_rating/5
$deviceInfo
Details:
${_msgCtl.text.trim()}

$logsInfo
''');

    final to = 'support@aerofit.example';
    final uri = Uri.parse('mailto:$to?subject=$subject&body=$body');

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('Could not open email client.');
      if (!mounted) return;
      _showSuccess();
      _formKey.currentState!.reset();
      _rating = 0;
      _includeLogs = true;
      _includeDeviceInfo = true;
      _consent = true;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccess() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thanks for the feedback!'),
        content: const Text(
          'We appreciate your time. Our team will review your message soon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF2C5364),
        iconTheme: IconThemeData(
            color: Colors.white
        ),
        title: const Text('Send Feedback',style: TextStyle(color: Colors.white),),
      ),
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ Color(0xFF203A43), Color(0xFF2C5364)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.feedback_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Help us improve Wireless',
                        style: TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Share bugs, ideas, and compliments. Logs and device info help us debug faster.',
                    style: TextStyle(color: Colors.white.withOpacity(.85)),
                  ),
                ],
              ),
            ),
          ),

          // Form card
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Card(
                elevation: 0,
                surfaceTintColor: Color(0xFF2C5364),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Category & Rating
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _category,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'Bug report', child: Text('Bug report')),
                                  DropdownMenuItem(value: 'Feature request', child: Text('Feature request')),
                                  DropdownMenuItem(value: 'General feedback', child: Text('General feedback')),
                                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                                ],
                                onChanged: (v) => setState(() => _category = v ?? _category),
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StarRating(
                              value: _rating,
                              onChanged: (v) => setState(() => _rating = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Name & Email
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameCtl,
                                decoration: InputDecoration(
                                  labelText: 'Name (optional)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emailCtl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email (optional)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  isDense: true,
                                ),
                                validator: (v) {
                                  final t = v?.trim() ?? '';
                                  if (t.isEmpty) return null;
                                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(t);
                                  return ok ? null : 'Invalid email';
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Message
                        TextFormField(
                          controller: _msgCtl,
                          minLines: 5,
                          maxLines: 12,
                          decoration: InputDecoration(
                            labelText: 'Describe your issue or idea',
                            hintText: 'What happened? Steps to reproduce? What did you expect?',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return 'Please write a short message';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Toggles
                        Row(
                          children: [
                            Expanded(
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Include logs'),
                                subtitle: const Text('Attach/mention recent app logs'),
                                value: _includeLogs,
                                onChanged: (v) => setState(() => _includeLogs = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Device info'),
                                subtitle: const Text('OS & app version'),
                                value: _includeDeviceInfo,
                                onChanged: (v) => setState(() => _includeDeviceInfo = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Consent
                        CheckboxListTile(
                          value: _consent,
                          onChanged: (v) => setState(() => _consent = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'I consent to Aerofit Inc. processing this feedback to improve the app.',
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Submit
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Icon(Icons.send_rounded),
                            label: Text(_submitting ? 'Sending…' : 'Submit Feedback'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small widgets ──────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  const _StarRating({required this.value, required this.onChanged});
  final int value; // 0..5
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final stars = List.generate(5, (i) {
      final filled = i < value;
      return IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        onPressed: () => onChanged(i + 1),
        icon: Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: filled ? Colors.amber : Theme.of(context).colorScheme.outline,
          size: 28,
        ),
      );
    });
    return Row(children: stars);
  }
}
