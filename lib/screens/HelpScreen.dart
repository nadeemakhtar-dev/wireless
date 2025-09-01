import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white
        ),
        title: const Text("Help & Support",style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF2C5364),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Icon(Icons.help_outline_rounded, size: 80, color: Color(0xFF2C5364)),
                const SizedBox(height: 12),
                const Text(
                  "Need Assistance?",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "Find answers to common questions and get help with the Wireless app.",
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // FAQ Section
          _SectionTitle(title: "Frequently Asked Questions"),
          const SizedBox(height: 8),
          _FaqTile(
            question: "How do I scan for BLE devices?",
            answer:
            "Tap the search icon on the home screen. Make sure Bluetooth and Location services are enabled.",
          ),
          _FaqTile(
            question: "Why can't I connect to my device?",
            answer:
            "Ensure the device is powered on, within range, and not already connected to another phone.",
          ),
          _FaqTile(
            question: "What does RSSI mean?",
            answer:
            "RSSI (Received Signal Strength Indicator) tells you how strong the signal is. Closer to 0 = stronger connection.",
          ),

          const SizedBox(height: 24),

          // Guides Section
          _SectionTitle(title: "Quick Guides"),
          const SizedBox(height: 8),
          _GuideCard(
            icon: Icons.bluetooth_searching,
            title: "Scanning Devices",
            description: "Learn how to discover nearby BLE devices.",
          ),
          _GuideCard(
            icon: Icons.link_rounded,
            title: "Connecting",
            description: "Step-by-step guide to connect to your BLE device.",
          ),
          _GuideCard(
            icon: Icons.data_array_rounded,
            title: "Reading & Writing Data",
            description: "Understand how to read sensor data and send commands.",
          ),

          const SizedBox(height: 24),

          // Contact Section
          _SectionTitle(title: "Still Need Help?"),
          const SizedBox(height: 8),
          Card(

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            color: Color(0xFF2C5364),
            child: ListTile(
              leading: const Icon(Icons.email, color: Colors.white),
              title: const Text("Contact Support", style: TextStyle(color: Colors.white)),
              subtitle: const Text("support@aerofitinc.com", style: TextStyle(color: Colors.white70)),
              onTap: () {
                // you can integrate email launcher here
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(

      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: const Icon(Icons.question_answer_outlined, color: Colors.blue),
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(answer, style: TextStyle(color: Colors.grey.shade700)),
        )
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _GuideCard({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(0xFF2C5364),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // you can navigate to detailed guide pages
        },
      ),
    );
  }
}
