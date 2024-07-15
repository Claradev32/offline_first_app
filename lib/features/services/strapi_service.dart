import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:offline_first_app/features/core/database.dart';
import 'package:sqflite/sqflite.dart';

class StrapiService {
  // static const String baseUrl =
  //     'http://10.0.2.2:1337'; // Use this for Android emulator
  static const String baseUrl =
      'http://localhost:1337'; // Use this for iOS simulator
  final DatabaseHelper databaseHelper = DatabaseHelper();

  final _todosStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get todosStream =>
      _todosStreamController.stream;

  Future<void> fetchAndCacheTodos() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/todos'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final todos = responseData['data'];

        final db = await databaseHelper.database;
        await db.transaction((txn) async {
          for (var todo in todos) {
            await txn.insert(
              'todos',
              {
                "id": todo['id'],
                "title": todo['attributes']['title'],
                "description": todo['attributes']['description'],
                "isCompleted": todo['attributes']['isCompleted'] == 1 ||
                        todo['isCompleted'] == true
                    ? 1
                    : 0,
                "createdAt": todo['attributes']['createdAt'],
                "updatedAt": todo['attributes']['updatedAt'],
                "isNew": 0,
                "isUpdated": 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
      }
    } catch (e) {
      print('Error fetching todos: $e');
    } finally {
      await _updateTodosStream();
    }
  }

  Future<void> createLocalTodo(Map<String, dynamic> todo) async {
    final db = await databaseHelper.database;
    todo['createdAt'] = DateTime.now().toIso8601String();
    todo['updatedAt'] = todo['createdAt'];
    todo['isCompleted'] == 1 || todo['isCompleted'] == true ? 1 : 0;
    todo['isNew'] = 1;
    todo['isUpdated'] = 0;

    final id = await db.insert('todos', todo,
        conflictAlgorithm: ConflictAlgorithm.replace);
    todo['id'] = id;

    await _updateTodosStream();

    uploadTodoToBackend(todo);
  }

  Future<void> updateLocalTodo(Map<String, dynamic> todo) async {
    final db = await databaseHelper.database;
    todo['updatedAt'] = DateTime.now().toIso8601String();
    todo['isCompleted'] == 1 || todo['isCompleted'] == true ? 1 : 0;
    todo['isUpdated'] = 1;

    await db.update(
      'todos',
      todo,
      where: 'id = ?',
      whereArgs: [todo['id']],
    );

    await _updateTodosStream();

    updateTodoOnBackend(todo).catchError((error) {
      throw ('Failed to update todo on backend: $error');
    });
  }

  Future<void> deleteLocalTodo(int id) async {
    final db = await databaseHelper.database;
    await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _updateTodosStream();

    deleteTodoOnBackend(id).catchError((error) {
      print('Failed to delete todo on backend: $error');
    });
  }

  Future<void> uploadTodoToBackend(Map<String, dynamic> todo,
      {bool isSync = false}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/todos'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              "data": {
                "title": todo['title'],
                "description": todo['description'],
                "isCompleted": todo['isCompleted'] == 1,
              }
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final backendId = responseData['data']['id'];

        final db = await databaseHelper.database;
        await db.update(
          'todos',
          {
            'id': backendId,
            'isNew': 0,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [todo['id']],
        );
        if (!isSync) todo['id'] = backendId;
      } else {
        throw Exception('Failed to upload todo');
      }
    } catch (e) {
      print('Error uploading todo: $e');
      throw e;
    }
  }

  Future<void> updateTodoOnBackend(Map<String, dynamic> todo) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/todos/${todo['id']}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              "data": {
                "title": todo['title'],
                "description": todo['description'],
                "isCompleted": todo['isCompleted'] == 1,
              }
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final db = await databaseHelper.database;
        await db.update('todos', {'isUpdated': 0},
            where: 'id = ?', whereArgs: [todo['id']]);
      } else {
        throw Exception('Failed to update todo on backend');
      }
    } catch (e) {
      print('Error updating todo on backend: $e');
      throw e;
    }
  }

  Future<void> deleteTodoOnBackend(int id) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/todos/$id'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete todo on backend');
      }
    } catch (e) {
      print('Error deleting todo on backend: $e');
      throw e;
    }
  }

  Future<void> syncLocalTodosWithBackend() async {
    print("syncing");
    final localTodos = await getLocalTodos();
    // print(localTodos);
    for (var todo in localTodos) {
      if (todo['isNew'] == 1) {
        await uploadTodoToBackend(todo, isSync: true);
      } else if (todo['isUpdated'] == 1) {
        await updateTodoOnBackend(todo);
      }
    }

    await fetchAndCacheTodos();
  }

  Future<List<Map<String, dynamic>>> getLocalTodos() async {
    final db = await databaseHelper.database;
    return await db.query('todos');
  }

  Future<void> _updateTodosStream() async {
    final todos = await getLocalTodos();
    _todosStreamController.add(todos);
  }
}
