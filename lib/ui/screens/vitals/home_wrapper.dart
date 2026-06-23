import 'package:flutter/material.dart';
import '../../../core/utils/haptics.dart';
import 'vitals_screen.dart';
import 'command_home_screen.dart';
import 'pulse_home_screen.dart';

enum HomeDirection { vitals, command, pulse }

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  HomeDirection _direction = HomeDirection.vitals;

  void _cycle() {
    KubelyHaptics.medium();
    setState(() {
      switch (_direction) {
        case HomeDirection.vitals:
          _direction = HomeDirection.command;
        case HomeDirection.command:
          _direction = HomeDirection.pulse;
        case HomeDirection.pulse:
          _direction = HomeDirection.vitals;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _cycle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_direction) {
          HomeDirection.vitals =>
            const VitalsScreen(key: ValueKey('vitals')),
          HomeDirection.command =>
            const CommandHomeScreen(key: ValueKey('command')),
          HomeDirection.pulse =>
            const PulseHomeScreen(key: ValueKey('pulse')),
        },
      ),
    );
  }
}
