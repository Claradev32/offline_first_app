import 'package:flutter/material.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:offline_first_app/features/services/strapi_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StrapiService strapiService = StrapiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final bool _enabled = true;

  @override
  void initState() {
    super.initState();
    strapiService.fetchAndCacheTodos();
    strapiService.syncLocalTodosWithBackend();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    await BackgroundFetch.configure(
        BackgroundFetchConfig(
            minimumFetchInterval: 15,
            stopOnTerminate: false,
            enableHeadless: true,
            requiresBatteryNotLow: false,
            requiresCharging: false,
            requiresStorageNotLow: false,
            requiresDeviceIdle: false,
            requiredNetworkType: NetworkType.ANY),
        _onBackgroundFetch,
        _onBackgroundFetchTimeout);
    setState(() {});

    if (_enabled) {
      await BackgroundFetch.start();
    }
    if (!mounted) return;
  }

  void _onBackgroundFetch(String taskId) async {
    await strapiService.syncLocalTodosWithBackend();
    BackgroundFetch.finish(taskId);
  }

  void _onBackgroundFetchTimeout(String taskId) {
    BackgroundFetch.finish(taskId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: strapiService.todosStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            final todos = snapshot.data ?? [];
            return ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final todo = todos[index];
                return ListTile(
                  title: Text(todo['title']),
                  subtitle: Text(todo['description']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: todo['isCompleted'] == 1,
                        onChanged: (value) {
                          if (value != null) {
                            strapiService.updateLocalTodo({
                              ...todo,
                              'isCompleted': value ? 1 : 0,
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Delete Todo?'),
                                content: const Text(
                                    'Are you sure you want to delete this todo?'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      strapiService.deleteLocalTodo(todo['id']);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Delete Todo?'),
                          content: const Text(
                              'Are you sure you want to delete this todo?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                strapiService.deleteLocalTodo(todo['id']);
                                Navigator.pop(context);
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'New Todo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: _descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final newTodo = {
                          'title': _titleController.text,
                          'description': _descriptionController.text,
                          'isCompleted': 0,
                          'createdAt': DateTime.now().toIso8601String(),
                        };
                        strapiService.createLocalTodo(newTodo);
                        _titleController.clear();
                        _descriptionController.clear();
                        Navigator.pop(context);
                      },
                      child: const Text('Create Todo'),
                    ),
                  ],
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
