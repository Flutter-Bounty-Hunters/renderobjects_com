import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:renderobjects/examples/apple_watch_app_grid/apple_watch_app_grid.dart';

class WatchAppGridDemoPage extends StatelessWidget {
  const WatchAppGridDemoPage({super.key});

  static const _icons = [
    'phone',
    'messages',
    'mail',
    'calendar',
    'maps',
    'clock',
    'reminders',
    'notes',
    'weather',
    'settings',
    'photos',
    'camera',
    'music',
    'podcasts',
    'app_store',
    'heart_rate',
    'activity',
    'workout',
    'breathe',
    'sleep',
    'noise',
    'ecg',
    'blood_oxygen',
    'compass',
    'altimeter',
    'timer',
    'stopwatch',
    'world_clock',
    'alarm',
    'calculator',
    'facetime',
    'contacts',
    'walkie_talkie',
    'find_my',
    'wallet',
    'stocks',
    'apple_tv',
    'radio',
    'books',
    'audiobooks',
    'news',
    'home',
    'remote',
    'flashlight',
    'shortcuts',
    'measure',
    'translate',
    'magnifier',
    'cycle_tracking',
    'medications',
    'mindfulness',
    'fertility',
    'vision',
    'focus',
    'accessibility',
    'battery',
    'cellular',
    'siri',
    'journal',
    'memoji',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.3), radius: 1.2, colors: [Color(0xFF1C1C1E), Colors.black]),
        ),
        child: Center(child: _AppleWatchFace(iconNames: [..._icons, ..._icons, ..._icons])),
      ),
    );
  }
}

class _AppleWatchFace extends StatefulWidget {
  const _AppleWatchFace({required this.iconNames});

  final List<String> iconNames;

  static const double caseW = 228.0;
  static const double caseH = 264.0;
  static const double caseRadius = 54.0;
  static const double bezel = 5.0;
  static const double screenRadius = 49.0;

  @override
  State<_AppleWatchFace> createState() => _AppleWatchFaceState();
}

class _AppleWatchFaceState extends State<_AppleWatchFace> with SingleTickerProviderStateMixin {
  int? _openAppIndex;

  late final AnimationController _appTransition;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _appTransition = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    final curved = CurvedAnimation(parent: _appTransition, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
    _fade = curved;
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(curved);
  }

  @override
  void dispose() {
    _appTransition.dispose();
    super.dispose();
  }

  void _openApp(int index) {
    setState(() => _openAppIndex = index);
    _appTransition.forward(from: 0.0);
  }

  void _closeApp() {
    _appTransition.reverse().whenComplete(() {
      if (mounted) {
        setState(() => _openAppIndex = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool appOpen = _openAppIndex != null;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: _AppleWatchFace.caseW,
          height: _AppleWatchFace.caseH,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3A3A3C), Color(0xFF1C1C1E)],
            ),
            borderRadius: BorderRadius.circular(_AppleWatchFace.caseRadius),
            border: Border.all(color: const Color(0xFF48484A)),
            boxShadow: const [
              BoxShadow(color: Color(0xCC000000), blurRadius: 48, spreadRadius: 6, offset: Offset(0, 16)),
              BoxShadow(color: Color(0x28FFFFFF), blurRadius: 1, offset: Offset(0, -1)),
            ],
          ),
          padding: const EdgeInsets.all(_AppleWatchFace.bezel),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_AppleWatchFace.screenRadius),
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  WatchAppGrid(
                    childCount: widget.iconNames.length,
                    builder: (context, index) => GestureDetector(
                      onTap: () => _openApp(index),
                      child: ClipOval(
                        child: SvgPicture.network('/images/apple_watch_app_grid/${widget.iconNames[index]}.svg'),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    ignoring: !appOpen,
                    child: FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(
                        scale: _scale,
                        child: appOpen
                            ? _WatchAppPage(
                                iconName: widget.iconNames[_openAppIndex!],
                                onBack: _closeApp,
                              )
                            : const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Digital Crown — press to return to the app grid
        Positioned(
          right: -9,
          top: _AppleWatchFace.caseH * 0.26,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: appOpen ? _closeApp : null,
            child: const _SideButton(width: 10, height: 52),
          ),
        ),

        Positioned(
          right: -8,
          top: _AppleWatchFace.caseH * 0.26 + 52 + 8,
          child: const _SideButton(width: 8, height: 30),
        ),
      ],
    );
  }
}

class _WatchAppPage extends StatelessWidget {
  const _WatchAppPage({required this.iconName, required this.onBack});

  final String iconName;
  final VoidCallback onBack;

  static String _title(String iconName) {
    return iconName.split('_').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 28.0, left: 4.0),
            child: GestureDetector(
              onTap: onBack,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.chevron_left, color: Colors.white, size: 20),
                    Text(
                      'Grid',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SvgPicture.network(
                      '/images/apple_watch_app_grid/$iconName.svg',
                      width: 72,
                      height: 72,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _title(iconName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppleWatchAppGridApp extends StatelessWidget {
  const AppleWatchAppGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WatchAppGridDemoPage(),
    );
  }
}

void main() {
  runApp(const AppleWatchAppGridApp());
}

class _SideButton extends StatelessWidget {
  const _SideButton({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF3A3A3C), Color(0xFF2C2C2E)],
        ),
        borderRadius: BorderRadius.circular(width / 2),
        border: Border.all(color: const Color(0xFF48484A), width: 0.5),
      ),
    );
  }
}
