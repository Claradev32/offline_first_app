import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:offline_first_app/features/core/database.dart';
import 'package:offline_first_app/features/screens/home_screen.dart';
import 'package:offline_first_app/features/services/strapi_service.dart';

@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  String taskId = task.taskId;
  bool isTimeout = task.timeout;
  if (isTimeout) {
    BackgroundFetch.finish(taskId);
    return;
  }
  final strapiService = StrapiService();
  await strapiService.syncLocalTodosWithBackend();
  BackgroundFetch.finish(taskId);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final DatabaseHelper databasehleper = DatabaseHelper();
  await databasehleper.database;
  runApp(const MyApp());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline First App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}
