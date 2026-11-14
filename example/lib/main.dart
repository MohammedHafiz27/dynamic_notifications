import 'package:dynamic_notifications/dynamic_notifications.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

const _red = Color(0xFFE9232E);
const _ink = Color(0xFF0F0F0F);

const _videos = [
  (
    image: 'alps',
    title: '48 hours in the Japanese Alps',
    channel: 'Field Notes',
    metadata: '184K views · 3 days ago',
    duration: '18:42',
    color: Color(0xFF305A4A),
    icon: Icons.landscape_outlined,
  ),
  (
    image: 'desk',
    title: 'Building a desk I actually want to work at',
    channel: 'Studio Sunday',
    metadata: '96K views · 1 week ago',
    duration: '12:08',
    color: Color(0xFF934526),
    icon: Icons.keyboard_alt_outlined,
  ),
];

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final _notifications = DynamicNotificationController();
  bool _opened = false;
  int _category = 0;
  double _originLift = 0;

  void _showMessage() => _notifications.show(
    DynamicNotification(
      title: 'New message',
      message: 'Maya sent you the final design.',
      icon: Icons.notifications_outlined,
      accent: _red,
      onTap: () => setState(() => _opened = true),
    ),
  );

  void _showUpload() => _notifications.show(
    DynamicNotification(
      title: 'Uploading files',
      message: '60% complete',
      duration: null,
      style: const DynamicNotificationStyle(
        backgroundColor: Color(0xFF242426),
        borderRadius: 22,
      ),
      contentBuilder: (context) => const Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: Color(0xFFFF636A)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uploading files',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.6,
                  color: Color(0xFFFF636A),
                  backgroundColor: Color(0xFF505054),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Text('60%', style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
  );

  void _settings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Drop origin lift · ${_originLift.round()} pt'),
                Slider(
                  value: _originLift,
                  max: 24,
                  divisions: 24,
                  label: '${_originLift.round()} pt',
                  onChanged: (value) {
                    setState(() => _originLift = value);
                    setSheetState(() {});
                  },
                ),
                TextButton(
                  onPressed: () {
                    _notifications.dismiss();
                    Navigator.pop(context);
                  },
                  child: const Text('Dismiss notification'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube-style demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _red),
        scaffoldBackgroundColor: Colors.white,
      ),
      builder: (context, child) => DynamicNotifications(
        controller: _notifications,
        originLift: _originLift,
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 16,
            title: const Row(
              children: [
                Icon(Icons.smart_display_rounded, color: _red, size: 34),
                SizedBox(width: 4),
                Text(
                  'YouTube',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.25,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Show notification (2s)',
                onPressed: _showMessage,
                icon: const Icon(Icons.notifications_outlined),
              ),
              IconButton(
                tooltip: 'Show persistent notification',
                onPressed: _showUpload,
                icon: const Icon(Icons.video_call_outlined),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: ListView(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Row(
                  children: [
                    for (final (index, label) in [
                      'All',
                      'Travel',
                      'Tech',
                    ].indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _category == index,
                          showCheckmark: false,
                          side: BorderSide.none,
                          backgroundColor: const Color(0xFFF1F1F1),
                          selectedColor: _ink,
                          labelStyle: TextStyle(
                            color: _category == index ? Colors.white : _ink,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setState(() => _category = index),
                        ),
                      ),
                  ],
                ),
              ),
              if (_opened)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text('Message opened'),
                ),
              for (final (index, video) in _videos.indexed)
                if (_category == 0 || _category == index + 1) ...[
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/${video.image}.jpg',
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              child: Text(
                                video.duration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: video.color,
                          child: Icon(
                            video.icon,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${video.channel} · ${video.metadata}',
                                style: const TextStyle(
                                  color: Color(0xFF5B5B5B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFECECEC))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _category = 0),
                    icon: const Icon(Icons.home_filled),
                    label: const Text('Home'),
                    style: TextButton.styleFrom(foregroundColor: _ink),
                  ),
                  TextButton.icon(
                    onPressed: _showUpload,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Create'),
                    style: TextButton.styleFrom(foregroundColor: _ink),
                  ),
                  TextButton.icon(
                    onPressed: () => _settings(context),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('You'),
                    style: TextButton.styleFrom(foregroundColor: _ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
