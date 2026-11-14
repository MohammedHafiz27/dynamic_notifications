import 'dart:io';
import 'dart:math' as math;

import 'package:dynamic_notifications/dynamic_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DemoApp());
}

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
  final _androidProvider = AndroidCutoutGeometryProvider();

  bool _opened = false;
  int _category = 0;
  double _originLift = 0;

  // Diagnostic mode state (disabled by default)
  bool _debugMode = false;
  bool _showGuides = true;
  bool _useNativeGeometry = false;
  bool _highContrast = false;
  double? _progressOverride;
  NotchGeometry? _nativeGeometry;
  Map<String, dynamic>? _nativeData;
  int? _benchmarkLatencyUs;

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

  Future<void> _fetchNativeCutout(BuildContext context) async {
    if (!Platform.isAndroid) return;
    final mq = MediaQuery.of(context);
    final stopwatch = Stopwatch()..start();
    try {
      final res = await const MethodChannel(
        'dynamic_notifications/android_geometry',
      ).invokeMapMethod<String, dynamic>('getCutoutGeometry');
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _nativeData = res;
        _benchmarkLatencyUs =
            res?['latencyUs'] as int? ?? stopwatch.elapsedMicroseconds;
      });
      final geo = await _androidProvider.load(mediaQuery: mq);
      if (mounted) {
        setState(() => _nativeGeometry = geo);
      }
    } catch (_) {
      // Platform channel unavailable or not supported
    }
  }

  void _logDiagnostics(BuildContext context, NotchGeometry activeGeometry) {
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final dpr = mq.devicePixelRatio;
    final insets = mq.viewPadding != EdgeInsets.zero
        ? mq.viewPadding
        : mq.padding;
    final windowExtendsIntoCutout = insets.top > 0 && mq.size.height > 0;
    final anchorTop = activeGeometry.anchorTop;
    final anchorX = activeGeometry.anchorX;
    final hasCutout = activeGeometry.hasCutout;
    final maxOverlap = math.max(0.0, anchorTop);
    final yTop = hasCutout ? -math.min(2.5, maxOverlap) : 0.0;
    final isPunchHole =
        hasCutout && activeGeometry.shape == NotchShape.punchHole;
    final domeArch = isPunchHole
        ? math.min(2.0, math.max(0.0, maxOverlap + yTop))
        : 0.0;
    final topBoundaryGlobal = anchorTop + yTop - domeArch;
    final neckWidth = activeGeometry.width > 0 ? activeGeometry.width : 32.0;

    debugPrint(
      '╔════════════════════════════════════════════════════════════════════╗',
    );
    debugPrint(
      '║                DYNAMIC NOTIFICATIONS DIAGNOSTIC LOG                ║',
    );
    debugPrint(
      '╠════════════════════════════════════════════════════════════════════╣',
    );
    debugPrint(
      '║ Device: ${Platform.operatingSystem} (${_nativeData?['deviceModel'] ?? 'Unknown'})',
    );
    debugPrint(
      '║ Android API: ${_nativeData?['apiLevel'] ?? 'N/A'}, Target SDK: ${_nativeData?['targetSdk'] ?? 'N/A'}',
    );
    debugPrint('║ Window physical: ${view.physicalSize}, logical: ${mq.size}');
    debugPrint('║ DPR: $dpr');
    debugPrint('║ viewPadding: ${mq.viewPadding}, padding: ${mq.padding}');
    debugPrint('║ Window extends into cutout: $windowExtendsIntoCutout');
    debugPrint('║ DisplayFeatures (${mq.displayFeatures.length}):');
    for (var i = 0; i < mq.displayFeatures.length; i++) {
      final f = mq.displayFeatures[i];
      debugPrint('║   [$i] type=${f.type}, bounds=${f.bounds}');
    }
    debugPrint('║ Active NotchGeometry:');
    debugPrint(
      '║   Source: ${activeGeometry.source}, Shape: ${activeGeometry.shape}',
    );
    debugPrint(
      '║   Confidence: ${activeGeometry.confidence}, hasCutout: ${activeGeometry.hasCutout}',
    );
    debugPrint('║   bounds: ${activeGeometry.bounds}');
    debugPrint(
      '║   center: ${activeGeometry.center}, width: ${activeGeometry.width}, height: ${activeGeometry.height}',
    );
    debugPrint('║ Coordinates:');
    debugPrint('║   anchorX: $anchorX, anchorTop: $anchorTop');
    debugPrint('║   Global painter origin: ($anchorX, $anchorTop)');
    debugPrint(
      '║   Painter top boundary: Y = $topBoundaryGlobal (screen coordinate)',
    );
    debugPrint('║   Estimated contact neck width: $neckWidth');
    if (_benchmarkLatencyUs case final latencyUs?) {
      final framePercent = (latencyUs / 16666.0 * 100).toStringAsFixed(1);
      debugPrint(
        '║ Native Channel Latency: $latencyUs µs ($framePercent% of 60Hz frame)',
      );
    }
    debugPrint(
      '╚════════════════════════════════════════════════════════════════════╝',
    );
  }

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
                const SizedBox(height: 8),
                const SizedBox(height: 12),
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
        scaffoldBackgroundColor: _highContrast ? Colors.white : Colors.white,
      ),
      builder: (context, child) {
        final activeGeometry = _useNativeGeometry && _nativeGeometry != null
            ? _nativeGeometry!
            : NotchGeometryDetector.detect(context);

        if (_debugMode) {
          _logDiagnostics(context, activeGeometry);
        }

        return DynamicNotifications(
          controller: _notifications,
          originLift: _originLift,
          debugShowGuides: _debugMode && _showGuides,
          geometryOverride: _useNativeGeometry ? _nativeGeometry : null,
          progressOverride: _progressOverride,
          child: Stack(
            children: [
              child!,
              if (_debugMode)
                _GeometryDebugHud(
                  geometry: activeGeometry,
                  showGuides: _showGuides,
                  useNativeGeometry: _useNativeGeometry,
                  highContrast: _highContrast,
                  nativeData: _nativeData,
                  latencyUs: _benchmarkLatencyUs,
                  progressOverride: _progressOverride,
                  onToggleGuides: (val) {
                    setState(() => _showGuides = val);
                  },
                  onProgressChanged: (val) {
                    setState(() => _progressOverride = val);
                  },
                  onToggleGeometrySource: (useNative) async {
                    if (useNative && _nativeGeometry == null) {
                      await _fetchNativeCutout(context);
                    }
                    setState(() => _useNativeGeometry = useNative);
                  },
                  onToggleHighContrast: (val) {
                    setState(() => _highContrast = val);
                  },
                  onRunBenchmark: () => _fetchNativeCutout(context),
                  onTriggerNotification: _showUpload,
                  onClose: () => setState(() {
                    _debugMode = false;
                    _progressOverride = null;
                  }),
                ),
            ],
          ),
        );
      },
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: _highContrast ? Colors.white : Colors.white,
          appBar: AppBar(
            backgroundColor: _highContrast ? Colors.white : Colors.white,
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
                tooltip: 'Toggle Debug Geometry Mode',
                onPressed: () async {
                  final next = !_debugMode;
                  if (next && _nativeData == null) {
                    await _fetchNativeCutout(context);
                  }
                  setState(() => _debugMode = next);
                },
                icon: Icon(
                  _debugMode ? Icons.bug_report : Icons.bug_report_outlined,
                  color: _debugMode ? _red : null,
                ),
              ),
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
          body: _highContrast
              ? Container(color: Colors.white)
              : ListView(
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
                                  color: _category == index
                                      ? Colors.white
                                      : _ink,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) =>
                                    setState(() => _category = index),
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

class _GeometryDebugHud extends StatefulWidget {
  const _GeometryDebugHud({
    required this.geometry,
    required this.showGuides,
    required this.useNativeGeometry,
    required this.highContrast,
    required this.nativeData,
    required this.latencyUs,
    required this.progressOverride,
    required this.onToggleGuides,
    required this.onProgressChanged,
    required this.onToggleGeometrySource,
    required this.onToggleHighContrast,
    required this.onRunBenchmark,
    required this.onTriggerNotification,
    required this.onClose,
  });

  final NotchGeometry geometry;
  final bool showGuides;
  final bool useNativeGeometry;
  final bool highContrast;
  final Map<String, dynamic>? nativeData;
  final int? latencyUs;
  final double? progressOverride;
  final ValueChanged<bool> onToggleGuides;
  final ValueChanged<double?> onProgressChanged;
  final ValueChanged<bool> onToggleGeometrySource;
  final ValueChanged<bool> onToggleHighContrast;
  final VoidCallback onRunBenchmark;
  final VoidCallback onTriggerNotification;
  final VoidCallback onClose;

  @override
  State<_GeometryDebugHud> createState() => _GeometryDebugHudState();
}

class _GeometryDebugHudState extends State<_GeometryDebugHud> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final dpr = mq.devicePixelRatio;
    final insets = mq.viewPadding != EdgeInsets.zero
        ? mq.viewPadding
        : mq.padding;
    final windowExtends =
        widget.nativeData?['windowExtendsIntoCutout'] as bool? ??
        (insets.top > 0 && mq.size.height > 0);
    final anchorTop = widget.geometry.anchorTop;
    final anchorX = widget.geometry.anchorX;
    final hasCutout = widget.geometry.hasCutout;
    final maxOverlap = math.max(0.0, anchorTop);
    final yTop = hasCutout ? -math.min(2.5, maxOverlap) : 0.0;
    final isPunchHole =
        hasCutout && widget.geometry.shape == NotchShape.punchHole;
    final domeArch = isPunchHole
        ? math.min(2.0, math.max(0.0, maxOverlap + yTop))
        : 0.0;
    final topBoundaryGlobal = anchorTop + yTop - domeArch;
    final neckWidth = widget.geometry.width > 0 ? widget.geometry.width : 32.0;

    return Positioned(
      bottom: mq.padding.bottom + 60,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xEE1E1E24),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF141418),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: Color(0xFF00E5FF),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'GEOMETRY DIAGNOSTIC HUD',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white70,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
                    IconButton(
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Metric details
                      _metricRow(
                        'Device',
                        '${Platform.operatingSystem} (${widget.nativeData?['deviceModel'] ?? 'Unknown'})',
                      ),
                      _metricRow(
                        'API / Target SDK',
                        '${widget.nativeData?['apiLevel'] ?? 'N/A'} / ${widget.nativeData?['targetSdk'] ?? 'N/A'}',
                      ),
                      _metricRow(
                        'Window Size',
                        '${mq.size.width.toStringAsFixed(1)}×${mq.size.height.toStringAsFixed(1)} (DPR $dpr)',
                      ),
                      _metricRow(
                        'FlutterView Phys',
                        '${view.physicalSize.width.round()}×${view.physicalSize.height.round()}',
                      ),
                      _metricRow(
                        'Padding / viewPad',
                        '${mq.padding.top.toStringAsFixed(1)} / ${mq.viewPadding.top.toStringAsFixed(1)} dp (extends: $windowExtends)',
                      ),
                      _metricRow(
                        'Display Features',
                        mq.displayFeatures.isEmpty
                            ? 'None'
                            : mq.displayFeatures
                                  .map(
                                    (f) =>
                                        '${f.type.name} [${f.bounds.left.toStringAsFixed(1)}, ${f.bounds.top.toStringAsFixed(1)}, ${f.bounds.right.toStringAsFixed(1)}, ${f.bounds.bottom.toStringAsFixed(1)}]',
                                  )
                                  .join('; '),
                      ),
                      _metricRow(
                        'Shape / Source',
                        '${widget.geometry.shape.name} / ${widget.geometry.source.name} (${widget.geometry.confidence.name})',
                      ),
                      _metricRow('Renderer', 'Verified Standard'),
                      _metricRow(
                        'Cutout Bounds',
                        widget.geometry.bounds != null
                            ? '[${widget.geometry.bounds!.left.toStringAsFixed(1)}, ${widget.geometry.bounds!.top.toStringAsFixed(1)}, ${widget.geometry.bounds!.right.toStringAsFixed(1)}, ${widget.geometry.bounds!.bottom.toStringAsFixed(1)}]'
                            : 'None',
                      ),
                      _metricRow(
                        'Anchor (X, Top)',
                        '(${anchorX.toStringAsFixed(1)}, ${anchorTop.toStringAsFixed(1)})',
                      ),
                      _metricRow(
                        'Painter Origin',
                        '(${anchorX.toStringAsFixed(1)}, ${anchorTop.toStringAsFixed(1)}) global',
                      ),
                      _metricRow(
                        'Top Boundary Y',
                        '${topBoundaryGlobal.toStringAsFixed(2)} dp (screen space)',
                      ),
                      _metricRow(
                        'Contact Neck W',
                        '${neckWidth.toStringAsFixed(1)} dp',
                      ),
                      if (widget.latencyUs != null)
                        _metricRow(
                          'Channel Latency',
                          '${widget.latencyUs}µs (${(widget.latencyUs! / 166.66).toStringAsFixed(1)}% of 60Hz frame)',
                        ),

                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.progressOverride != null
                                ? 'Scrub: ${(widget.progressOverride! * 100).round()}%'
                                : 'Animation: Live',
                            style: const TextStyle(
                              color: Color(0xFFFFEA00),
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                            onPressed: () {
                              if (widget.progressOverride == null) {
                                widget.onProgressChanged(0.15);
                              } else {
                                widget.onProgressChanged(null);
                              }
                            },
                            child: Text(
                              widget.progressOverride == null
                                  ? 'Scrub Frame'
                                  : 'Live Mode',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF00E5FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.progressOverride != null)
                        Slider(
                          value: widget.progressOverride!,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          activeColor: const Color(0xFFFFEA00),
                          inactiveColor: Colors.white24,
                          onChanged: (val) => widget.onProgressChanged(val),
                        ),

                      const Divider(color: Colors.white24, height: 16),

                      // A/B Renderer Selection

                      // Control buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: widget.useNativeGeometry
                                      ? const Color(0xFF76FF03)
                                      : Colors.white38,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => widget.onToggleGeometrySource(
                                !widget.useNativeGeometry,
                              ),
                              child: Text(
                                widget.useNativeGeometry
                                    ? 'Source: Native Path (API 31+)'
                                    : 'Source: Flutter Features',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.useNativeGeometry
                                      ? const Color(0xFF76FF03)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              widget.showGuides
                                  ? Icons.layers
                                  : Icons.layers_clear,
                              color: widget.showGuides
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white38,
                              size: 18,
                            ),
                            onPressed: () =>
                                widget.onToggleGuides(!widget.showGuides),
                          ),
                          IconButton(
                            icon: Icon(
                              widget.highContrast
                                  ? Icons.contrast
                                  : Icons.contrast_outlined,
                              color: widget.highContrast
                                  ? const Color(0xFFFFEA00)
                                  : Colors.white38,
                              size: 18,
                            ),
                            onPressed: () => widget.onToggleHighContrast(
                              !widget.highContrast,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.speed,
                              color: Color(0xFF00E5FF),
                              size: 18,
                            ),
                            onPressed: widget.onRunBenchmark,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Color(0xFFFFEA00),
                              size: 18,
                            ),
                            onPressed: widget.onTriggerNotification,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Visual Guides Legend: ',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                          _legendItem(const Color(0xFF00E5FF), 'Cutout'),
                          const SizedBox(width: 6),
                          _legendItem(const Color(0xFFFF1744), 'Origin'),
                          const SizedBox(width: 6),
                          _legendItem(const Color(0xFFFFEA00), 'Neck Top'),
                          const SizedBox(width: 6),
                          _legendItem(const Color(0xFF76FF03), 'Dome Apex'),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
