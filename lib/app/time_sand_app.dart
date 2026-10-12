import 'package:flutter/material.dart';

import '../core/database/app_database.dart';
import '../core/database/time_records_repository.dart';
import '../design/app_theme.dart';
import '../features/home/home_page.dart';

class TimeSandApp extends StatelessWidget {
  const TimeSandApp({required this.database, super.key});

  final TimeSandDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeSand',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: HomePage(repository: TimeRecordsRepository(database)),
    );
  }
}
