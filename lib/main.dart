import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ToolboxApp());
}

class ToolboxApp extends StatelessWidget {
  const ToolboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '个人百宝箱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    AiAssistantPage(),
    BlindBoxPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '看板'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'AI助手'),
          NavigationDestination(icon: Icon(Icons.casino_outlined), label: '盲盒'),
        ],
      ),
    );
  }
}

// ==================== 1. 今日看板 ====================
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _weatherText = '加载中...';
  String _rateText = '加载中...';
  String _quoteText = '加载中...';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    await Future.wait([_fetchWeather(), _fetchRate(), _fetchQuote()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchWeather() async {
    try {
      // 长沙经纬度 (28.23, 112.94)，完全免费免Key
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=28.23&longitude=112.94&current_weather=true',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body);
      final current = data['current_weather'];
      setState(() {
        _weatherText = '当前气温 ${current['temperature']}°C · 风速 ${current['windspeed']} km/h';
      });
    } catch (_) {
      setState(() => _weatherText = '天气获取失败，点击右上角重试');
    }
  }

  Future<void> _fetchRate() async {
    try {
      final uri = Uri.parse('https://api.frankfurter.app/latest?from=USD&to=CNY,JPY');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body);
      final rates = data['rates'];
      setState(() {
        _rateText = '1 美元 ≈ ${rates['CNY']} 人民币\n1 美元 ≈ ${rates['JPY']} 日元';
      });
    } catch (_) {
      setState(() => _rateText = '汇率获取失败');
    }
  }

  Future<void> _fetchQuote() async {
    try {
      final uri = Uri.parse('https://v1.hitokoto.cn/?encode=json');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body);
      setState(() {
        _quoteText = '“${data['hitokoto']}”\n—— ${data['from'] ?? '佚名'}';
      });
    } catch (_) {
      setState(() => _quoteText = '保持热爱，奔赴山海。');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日看板'),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _refreshAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(title: '天气 (长沙)', content: _weatherText, icon: Icons.wb_sunny_outlined),
          const SizedBox(height: 12),
          _InfoCard(title: '实时汇率', content: _rateText, icon: Icons.currency_exchange),
          const SizedBox(height: 12),
          _InfoCard(title: '每日一言', content: _quoteText, icon: Icons.format_quote),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;

  const _InfoCard({required this.title, required this.content, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            Text(content, style: const TextStyle(fontSize: 15, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ==================== 2. 私人 AI 助手 ====================
class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  String _baseUrl = 'https://api.deepseek.com/v1/chat/completions';
  String _apiKey = '';
  String _model = 'deepseek-chat';
  String _reply = '点右上角齿轮填写 API Key 后即可使用。';
  bool _sending = false;

  Future<void> _askAi(String prefix) async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    if (_apiKey.isEmpty) {
      setState(() => _reply = '请先点击右上角设置图标填入你的 API Key');
      return;
    }
    setState(() {
      _sending = true;
      _reply = '思考中...';
    });
    try {
      final res = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'user', 'content': prefix.isEmpty ? text : '$prefix\n\n$text'}
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200) {
        setState(() => _reply = data['choices'][0]['message']['content']);
      } else {
        setState(() => _reply = '请求出错 (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      setState(() => _reply = '请求异常: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openSettings() {
    final urlCtrl = TextEditingController(text: _baseUrl);
    final keyCtrl = TextEditingController(text: _apiKey);
    final modelCtrl = TextEditingController(text: _model);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('AI 接口设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'API URL')),
            TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'API Key'), obscureText: true),
            TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Model')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              setState(() {
                _baseUrl = urlCtrl.text.trim();
                _apiKey = keyCtrl.text.trim();
                _model = modelCtrl.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 随身助手'),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _inputCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '输入要处理的内容或问题...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(onPressed: _sending ? null : () => _askAi('请帮我润色这段话，使其更自然流畅：'), child: const Text('润色')),
                FilledButton.tonal(onPressed: _sending ? null : () => _askAi('请将以下内容中英互译：'), child: const Text('翻译')),
                FilledButton.tonal(onPressed: _sending ? null : () => _askAi('请从以下内容中提取待办事项列表：'), child: const Text('提取待办')),
                FilledButton(onPressed: _sending ? null : () => _askAi(''), child: const Text('直接提问')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(child: SelectableText(_reply, style: const TextStyle(fontSize: 15, height: 1.5))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 3. 随机盲盒 ====================
class BlindBoxPage extends StatefulWidget {
  const BlindBoxPage({super.key});

  @override
  State<BlindBoxPage> createState() => _BlindBoxPageState();
}

class _BlindBoxPageState extends State<BlindBoxPage> {
  final List<String> _foods = ['猪脚饭', '麻辣烫', '黄焖鸡', '轻食沙拉', '牛肉面', '汉堡', '火锅'];
  final List<String> _movies = [
    '《星际穿越》- 科幻神作',
    '《肖申克的救赎》- 经典必看',
    '《疯狂动物城》- 轻松治愈',
    '《让子弹飞》- 百看不厌',
    '《白日梦想家》- 适合放空',
    '《时空恋旅人》- 温暖爱情',
  ];
  final Random _random = Random();
  String _result = '点下面按钮开盲盒';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('随手盲盒')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _result,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => setState(() => _result = _foods[_random.nextInt(_foods.length)]),
                child: const Text('今天吃什么'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.tonal(
                onPressed: () => setState(() => _result = _movies[_random.nextInt(_movies.length)]),
                child: const Text('随机推一部电影'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
