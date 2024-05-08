import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:offline_first_app/features/core/database.dart';
import 'package:offline_first_app/features/utils.dart';
import 'package:sqflite/sqflite.dart';

class StrapiService {
  static const String baseUrl = 'http://localhost:3000';
  final DatabaseHelper databaseHelper = DatabaseHelper();

  Future<void> fetchAndCacheTodos() async {
    final response = await http.get(Uri.parse('$baseUrl/api/todos'));
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final todos = responseData['data']; // Access the 'data' field

      final db = await databaseHelper.database;
      await db.transaction((txn) async {
        await txn.delete('todos'); // Clear existing todos
        for (var todo in todos) {
          await txn.insert(
            'todos',
            {
              "id": todo['id'],
              "title": todo['attributes']
                  ['title'], // Access title under 'attributes'
              "description": todo['attributes']
                  ['description'], // Access description under 'attributes'
              "isCompleted": todo['attributes']['isCompleted']
                  ? 1
                  : 0, // Store boolean as integer

              "createdAt": todo['attributes']
                  ['createdAt'], // Access createdAt under 'attributes'
              "updatedAt": todo['attributes']
                  ['updatedAt'], // Access updatedAt under 'attributes'
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } else {
      throw Exception('Failed to load todos');
    }
  }

  Future<List<Map<String, dynamic>>> getLocalTodos() async {
    try {
      final db = await databaseHelper.database;
      final todos = await db.query('todos');
      return todos;
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> createLocalTodo(Map<String, dynamic> todo) async {
    final db = await databaseHelper.database;
    final id = await db.insert(
      'todos',
      todo,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    todo['id'] = id;
    // Synchronize the new todo with the server in the background
    await uploadTodoToBackend(todo);
  }

  Future<void> updateLocalTodo(Map<String, dynamic> todo) async {
    final db = await databaseHelper.database;
    await db.update(
      'todos',
      todo,
      where: 'id = ?',
      whereArgs: [todo['id']],
    );
  }

  Future<void> deleteLocalTodo(int id) async {
    final db = await databaseHelper.database;
    await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> uploadTodoToBackend(Map<String, dynamic> todo) async {
    try {
      var connectivityService = ConnectivityService();
      if (await connectivityService.checkConnectivity()) {
        await http.post(
          Uri.parse('$baseUrl/api/todos'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            "data": {
              "id": todo['id'],
              "title": todo['title'],
              "description": todo['description'],
              "isCompleted": todo['isCompleted'] == 1 ? true : false,
            }
          }),
        );
      } else {
        return;
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> syncLocalTodosWithBackend() async {
    final localtodos = await getLocalTodos();
    final remotetodos = await fetchRemoteTodos();

    // Handle conflicts and merge data
    final mergedtodos = _mergeLocalAndRemoteTodos(localtodos, remotetodos);
    // Upload new or updated todos to the backend
    for (var todo in mergedtodos) {
      if ((todo['isNew'] == true || todo['isNew'] == 1) ||
          (todo['isUpdated'] == true || todo['isUpdated'] == 1)) {
        await uploadTodoToBackend(todo);
      }
    }
  }

  List<Map<String, dynamic>> _mergeLocalAndRemoteTodos(
    List<Map<String, dynamic>> localtodos,
    List<Map<String, dynamic>> remotetodos,
  ) {
    final mergedtodos = [...localtodos];

    // Iterate over remote todos
    for (var remotetodo in remotetodos) {
      final localtodoIndex =
          mergedtodos.indexWhere((todo) => todo['id'] == remotetodo['id']);

      if (localtodoIndex == -1) {
        // Remote todo doesn't exist locally, add it
        mergedtodos.add({
          ...remotetodo,
          'isNew': false,
          'isUpdated': false,
        });
      } else {
        final localtodo = mergedtodos[localtodoIndex];
        final remoteUpdatedAt = DateTime.parse(remotetodo['updatedAt']);
        final localUpdatedAt = DateTime.parse(localtodo['updatedAt']);

        if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
          // Remote todo is more recent, update local todo
          mergedtodos[localtodoIndex] = {
            ...remotetodo,
            'isNew': false,
            'isUpdated': true,
          };
        } else if (remoteUpdatedAt.isBefore(localUpdatedAt)) {
          // Local todo is more recent, mark it for upload
          mergedtodos[localtodoIndex] = {
            ...localtodo,
            'isNew': false,
            'isUpdated': true,
          };
        }
      }
    }

    return mergedtodos;
  }

  Future<List<Map<String, dynamic>>> fetchRemoteTodos() async {
    final response = await http.get(Uri.parse('$baseUrl/api/todos'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final List<dynamic> todosData = responseData['data'];
      final List<Map<String, dynamic>> todos = todosData
          .map((todo) => todo['attributes'] as Map<String, dynamic>)
          .toList();
      return todos;
    } else {
      throw Exception('Failed to load todos');
    }
  }
}
