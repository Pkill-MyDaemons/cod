import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'screens/chat_screen.dart';
import 'screens/email_screen.dart';
import 'screens/code_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';

class CodApp extends StatelessWidget {
  const CodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cod',
      debugShowCheckedModeBanner: false,
      theme: CodTheme.dark,
      home: const _Shell(),
    );
  }
}

class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  int _index = 0;

  static const _screens = [
    ChatScreen(),
    EmailScreen(),
    CalendarScreen(),
    CodeScreen(),
    TasksScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'Email',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.code_outlined),
            selectedIcon: Icon(Icons.code),
            label: 'Code',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
