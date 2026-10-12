import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../features/home/home_page.dart';

class TimeSandApp extends StatelessWidget {
  const TimeSandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeSand',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
