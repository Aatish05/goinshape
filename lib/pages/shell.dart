import 'package:flutter/material.dart';

// Prefix every tab import
import 'tabs/home_tab.dart' as home;
import 'tabs/counter_tab.dart' as counter;
import 'tabs/weekly_tab.dart' as weekly;
import 'tabs/profile_tab.dart' as profile;

class Shell extends StatefulWidget {
  final int userId;
  const Shell({super.key, required this.userId});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      home.HomeTab(userId: widget.userId),
      counter.CounterTab(userId: widget.userId),
      weekly.WeeklyTab(userId: widget.userId),
      profile.ProfileTab(userId: widget.userId),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Counter',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_week_outlined),
            selectedIcon: Icon(Icons.view_week),
            label: 'Weekly',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
