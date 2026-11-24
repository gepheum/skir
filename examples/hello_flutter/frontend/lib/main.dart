import 'package:flutter/material.dart';
import 'package:skir_client/skir_client.dart' as skir;

import 'skirout/greet.dart';

// Change the host to 10.0.2.2 when running on an Android emulator.
const String _backendUrl = 'http://localhost:8080/api';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hello Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const GreetPage(),
    );
  }
}

class GreetPage extends StatefulWidget {
  const GreetPage({super.key});

  @override
  State<GreetPage> createState() => _GreetPageState();
}

class _GreetPageState extends State<GreetPage> {
  final _nameController = TextEditingController();
  final _greetClient = skir.ServiceClient(_backendUrl).wrap(greetMethod);

  String _message = '';
  bool _loading = false;
  String? _error;

  Future<void> _greet() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _message = '';
    });

    try {
      final response = await _greetClient.invoke(GreetRequest(name: name));
      setState(() {
        _message = response.message;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Hello Flutter + Skir'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _greet(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _greet,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Greet'),
            ),
            const SizedBox(height: 24),
            if (_message.isNotEmpty)
              Text(
                _message,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            if (_error != null)
              Text(
                'Error: $_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
