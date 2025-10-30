// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/app_theme.dart';

void main() {
  runApp(
    // ProviderScope wraps entire app for Riverpod
    const ProviderScope(
      child: NovaApp(),
    ),
  );
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova - School Events Platform',
      debugShowCheckedModeBanner: false,

      // Theme configuration from AppTheme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Auto follow OS theme

      // Temporary home screen (placeholder until features implemented)
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Nova'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Nova Design System',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Design system classes implemented',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '✓ NovaColors (light/dark mode)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '✓ NovaSpacing (4px grid)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '✓ NovaTypography (Inter font)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '✓ NovaRadius (border radius)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '✓ NovaShadows (elevation)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '✓ NovaIconSizes (icon scale)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '✓ NovaGlass (liquid glass)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '✓ AppTheme (MaterialApp config)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
