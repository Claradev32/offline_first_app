import 'package:flutter/material.dart';
import 'package:offline_first_app/features/core/database.dart';
import 'package:offline_first_app/features/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final DatabaseHelper databasehleper = DatabaseHelper();
  await databasehleper.database;
  runApp(const MyApp());
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
