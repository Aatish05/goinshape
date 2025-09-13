import 'package:flutter/material.dart';
import '../services/db.dart';
import '../services/session.dart';
import '../utils/safe_ui.dart';
import '../utils/safe_flags.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/counter_tab.dart';
import 'tabs/weekly_tab.dart';
import 'tabs/profile_tab.dart';
import 'profile_setup_page.dart';
import 'auth/login_page.dart';

class HomePage extends StatefulWidget {
  final bool firstTime;
  const HomePage({super.key, this.firstTime = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _index = 0;
  int _uid = -1;
  Map<String, Object?>? _profile;
  bool _loading = true;

  bool _overToday = false;
  int _overBy = 0;
  int _dailyTarget = 2000;
  bool _bannerShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOverAlert();
  }

  int _computeDailyTarget(Map<String, Object?>? p) {
    final age = (p?['age'] as num?)?.toInt() ?? 25;
    final h = (p?['height_cm'] as num?)?.toInt() ?? 170;
    final w = (p?['weight_kg'] as num?)?.toDouble() ?? 70.0;
    final sex = (p?['sex'] as String? ?? 'male');
    final goal = (p?['goal'] as String? ?? 'maintain');
    final rate = (p?['target_rate_kg_per_week'] as num?)?.toDouble() ?? 0.0;

    final bmr = sex == 'male'
        ? 10 * w + 6.25 * h - 5 * age + 5
        : 10 * w + 6.25 * h - 5 * age - 161;
    double tdee = bmr * 1.3;

    if (rate != 0) {
      tdee += 7700.0 * rate / 7.0;
    } else {
      if (goal == 'lose') tdee -= 450;
      if (goal == 'gain') tdee += 300;
    }

    final t = tdee.round();
    if (t < 900) return 900;
    if (t > 5000) return 5000;
    return t;
  }

  Future<void> _init() async {
    final id = await Session.currentUserId();
    if (!mounted) return;
    if (id == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
      );
      return;
    }
    _uid = id;

    final p = await AppDatabase.instance.getProfile(_uid);
    if (!mounted) return;

    if (widget.firstTime && (p == null)) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const ProfileSetupPage()),
      );
      final refreshed = await AppDatabase.instance.getProfile(_uid);
      if (!mounted) return;
      setState(() {
        _profile = refreshed;
        _dailyTarget = _computeDailyTarget(refreshed);
        _loading = false;
      });
    } else {
      setState(() {
        _profile = p;
        _dailyTarget = _computeDailyTarget(p);
        _loading = false;
      });
    }

    await _refreshOverAlert();
  }

  Future<void> _refreshOverAlert() async {
    if (_uid <= 0) return;
    final totalToday = await AppDatabase.instance.totalForDay(_uid, DateTime.now());
    final over = totalToday > _dailyTarget;
    final overBy = (totalToday - _dailyTarget).clamp(0, 1 << 30);
    if (!mounted) return;
    setState(() {
      _overToday = over;
      _overBy = overBy;
    });
    _maybeShowOrHideBanner();
  }

  void _maybeShowOrHideBanner() {
    if (!mounted) return;

    if (desktopSafeMode) return; // no banners on desktop to avoid pointer assertion

    final shouldShow = _overToday && _index == 0;

    if (shouldShow && !_bannerShown) {
      final banner = MaterialBanner(
        backgroundColor: Colors.red.withOpacity(.08),
        elevation: 0,
        content: Text(
          'You are over today’s target by $_overBy kcal.',
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        actions: [
          TextButton(
            onPressed: () {
              clearBannersAfterInput(context);
              _bannerShown = false;
            },
            child: const Text('Dismiss'),
          ),
        ],
      );
      showBannerAfterInput(context, banner);
      _bannerShown = true;
    } else if (!shouldShow && _bannerShown) {
      clearBannersAfterInput(context);
      _bannerShown = false;
    }
  }

  Future<void> _reloadProfile() async {
    final p = await AppDatabase.instance.getProfile(_uid);
    if (!mounted) return;
    setState(() {
      _profile = p;
      _dailyTarget = _computeDailyTarget(p);
    });
    await _refreshOverAlert();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('GoinShape')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_off_outlined, size: 64),
                  const SizedBox(height: 12),
                  const Text('Let’s finish your profile',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 8),
                  const Text('We couldn’t find your profile yet. Tap below to set it up.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const ProfileSetupPage()),
                      );
                      final refreshed = await AppDatabase.instance.getProfile(_uid);
                      if (!mounted) return;
                      setState(() {
                        _profile = refreshed;
                        _dailyTarget = _computeDailyTarget(refreshed);
                      });
                      await _refreshOverAlert();
                    },
                    child: const Text('Complete profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final tabs = [
      DashboardTab(userId: _uid, profile: _profile),
      CounterTab(userId: _uid),
      WeeklyTab(userId: _uid),
      ProfileTab(userId: _uid, profile: _profile, onChanged: _reloadProfile),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('GoinShape'),
        actions: [
          if (_overToday)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.red.withOpacity(.25)),
                  ),
                  child: Text(
                    'Over by $_overBy kcal',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshOverAlert),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              clearBannersAfterInput(context);
              await Session.setUserId(null);
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (_) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(child: tabs[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          setState(() => _index = i);
          _maybeShowOrHideBanner();
          if (i == 0) await _refreshOverAlert();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Counter'),
          NavigationDestination(icon: Icon(Icons.calendar_view_week), label: 'Weekly'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
