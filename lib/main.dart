import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const PickerApp());
}

class PickerApp extends StatelessWidget {
  const PickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '随手抽签',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const PickerHomePage(),
    );
  }
}

class PickerHomePage extends StatefulWidget {
  const PickerHomePage({super.key});

  @override
  State<PickerHomePage> createState() => _PickerHomePageState();
}

class _PickerHomePageState extends State<PickerHomePage> {
  final List<String> _options = ['猪脚饭', '麻辣烫', '黄焖鸡', '轻食沙拉', '牛肉面', '汉堡'];
  final TextEditingController _controller = TextEditingController();
  final Random _random = Random();
  String _result = '点下面按钮抽一个';

  void _pickRandom() {
    if (_options.isEmpty) {
      setState(() => _result = '先加几个选项吧');
      return;
    }
    setState(() {
      _result = _options[_random.nextInt(_options.length)];
    });
  }

  void _addOption() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _options.add(text);
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今天吃什么'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _result,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _pickRandom,
                child: const Text('帮我选一个', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '输入新选项，比如：火锅',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addOption(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addOption, child: const Text('添加')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_options[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _options.removeAt(index)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
