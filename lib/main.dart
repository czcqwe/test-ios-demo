import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TankBattleApp());
}

class TankBattleApp extends StatelessWidget {
  const TankBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '经典坦克大战',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const TankGamePage(),
    );
  }
}

enum Dir { up, down, left, right }

class Bullet {
  double x, y;
  Dir dir;
  bool isPlayer;
  Bullet(this.x, this.y, this.dir, this.isPlayer);
}

class Explosion {
  double x, y;
  int life = 10;
  Explosion(this.x, this.y);
}

class Tank {
  double x, y;
  Dir dir;
  bool isPlayer;
  bool isFast;
  int cooldown = 0;
  int aiTurnTimer = 0;
  Tank(this.x, this.y, this.dir, this.isPlayer, {this.isFast = false});
}

class TankGamePage extends StatefulWidget {
  const TankGamePage({super.key});

  @override
  State<TankGamePage> createState() => _TankGamePageState();
}

class _TankGamePageState extends State<TankGamePage> {
  static const int gridSize = 13;
  static const int maxLevel = 5;

  // 0:空地, 1:砖墙, 2:钢板, 3:老鹰基地, 4:草丛(可穿过/遮挡), 5:河流(坦克不可过/子弹可过)
  late List<List<int>> _map;
  late Tank _player;
  final List<Tank> _enemies = [];
  final List<Bullet> _bullets = [];
  final List<Explosion> _explosions = [];
  final Random _rng = Random();

  Timer? _loop;
  Dir? _heldDir;
  int _level = 1;
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  int _enemiesToSpawn = 0;
  int _spawnTimer = 0;
  bool _gameOver = false;
  bool _levelCleared = false;
  bool _hasSave = false;
  bool _showStartMenu = true;

  @override
  void initState() {
    super.initState();
    _loadSaveInfo();
  }

  Future<void> _loadSaveInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('highScore') ?? 0;
      _hasSave = prefs.containsKey('savedLevel');
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (_score > _highScore) {
      _highScore = _score;
      await prefs.setInt('highScore', _highScore);
    }
    if (_gameOver) {
      await prefs.remove('savedLevel');
      await prefs.remove('savedScore');
      await prefs.remove('savedLives');
      _hasSave = false;
    } else {
      await prefs.setInt('savedLevel', _level);
      await prefs.setInt('savedScore', _score);
      await prefs.setInt('savedLives', _lives);
      _hasSave = true;
    }
  }

  Future<void> _continueGame() async {
    final prefs = await SharedPreferences.getInstance();
    _level = prefs.getInt('savedLevel') ?? 1;
    _score = prefs.getInt('savedScore') ?? 0;
    _lives = prefs.getInt('savedLives') ?? 3;
    _showStartMenu = false;
    _startLevel(_level);
  }

  void _newGame() {
    _level = 1;
    _score = 0;
    _lives = 3;
    _showStartMenu = false;
    _startLevel(1);
  }

  void _nextLevel() {
    _level = _level < maxLevel ? _level + 1 : 1;
    _startLevel(_level);
  }

  void _startLevel(int level) {
    _loop?.cancel();
    _gameOver = false;
    _levelCleared = false;
    _heldDir = null;
    _bullets.clear();
    _enemies.clear();
    _explosions.clear();
    _enemiesToSpawn = 6 + level * 2;
    _spawnTimer = 60;

    _map = _buildMap(level);
    _player = Tank(4, 12, Dir.up, true);

    _spawnOneEnemy(0);
    _spawnOneEnemy(6);
    _spawnOneEnemy(12);

    _saveProgress();
    _loop = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
    setState(() {});
  }

  List<List<int>> _buildMap(int level) {
    final m = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    m[10][5] = 1; m[10][6] = 1; m[10][7] = 1;
    m[11][5] = 1; m[11][6] = 3; m[11][7] = 1;
    m[12][5] = 1; m[12][6] = 1; m[12][7] = 1;

    for (int y = 1; y <= 8; y++) {
      for (int x = 1; x <= 11; x++) {
        if (level == 1) {
          if (x % 2 == 1 && y != 4 && y != 7) m[y][x] = (y == 2 && x == 6) ? 2 : 1;
          if (y == 5 && (x == 2 || x == 10)) m[y][x] = 4;
        } else if (level == 2) {
          if ((x + y) % 3 == 0) m[y][x] = (y == 5) ? 2 : 1;
          if (y == 4 && (x >= 2 && x <= 4 || x >= 8 && x <= 10)) m[y][x] = 5;
        } else if (level == 3) {
          if ((y == 3 || y == 6) && x != 6) m[y][x] = (x % 3 == 0) ? 2 : 1;
          if (y == 7 && (x == 3 || x == 9)) m[y][x] = 4;
        } else if (level == 4) {
          if (x % 3 != 0 && y % 2 == 0) m[y][x] = (y == 4) ? 2 : 1;
          if (y == 5 && x >= 4 && x <= 8) m[y][x] = 5;
        } else {
          if ((x * y) % 4 == 1) m[y][x] = (y == 5) ? 2 : 1;
          if (y == 3 && (x == 2 || x == 10)) m[y][x] = 4;
        }
      }
    }
    m[0][0] = 0; m[0][6] = 0; m[0][12] = 0;
    return m;
  }

  void _spawnOneEnemy(int col) {
    if (_enemiesToSpawn <= 0 || _enemies.length >= 4) return;
    _enemiesToSpawn--;
    final fast = _level >= 2 && _rng.nextInt(3) == 0;
    _enemies.add(Tank(col.toDouble(), 0, Dir.down, false, isFast: fast));
  }

  void _tick() {
    if (_gameOver || _levelCleared || _showStartMenu) return;

    if (_heldDir != null) {
      _player.dir = _heldDir!;
      _moveTank(_player, 0.13);
    }
    if (_player.cooldown > 0) _player.cooldown--;

    _spawnTimer++;
    if (_spawnTimer > 90) {
      _spawnTimer = 0;
      _spawnOneEnemy([0, 6, 12][_rng.nextInt(3)]);
    }

    for (final e in _enemies) {
      if (e.cooldown > 0) e.cooldown--;
      e.aiTurnTimer--;
      final moved = _moveTank(e, e.isFast ? 0.11 : 0.08);
      if (!moved || e.aiTurnTimer <= 0) {
        e.dir = Dir.values[_rng.nextInt(4)];
        e.aiTurnTimer = 25 + _rng.nextInt(35);
      }
      if (e.cooldown == 0 && _rng.nextInt(28) == 0) {
        _fire(e);
      }
    }

    final toRemove = <Bullet>[];
    for (final b in _bullets) {
      switch (b.dir) {
        case Dir.up:
          b.y -= 0.28;
          break;
        case Dir.down:
          b.y += 0.28;
          break;
        case Dir.left:
          b.x -= 0.28;
          break;
        case Dir.right:
          b.x += 0.28;
          break;
      }

      final gx = b.x.round();
      final gy = b.y.round();
      if (gx < 0 || gx >= gridSize || gy < 0 || gy >= gridSize) {
        toRemove.add(b);
        continue;
      }

      final tile = _map[gy][gx];
      if (tile == 1) {
        _map[gy][gx] = 0;
        _explosions.add(Explosion(gx.toDouble(), gy.toDouble()));
        toRemove.add(b);
        continue;
      } else if (tile == 2) {
        toRemove.add(b);
        continue;
      } else if (tile == 3) {
        _map[gy][gx] = 0;
        _explosions.add(Explosion(gx.toDouble(), gy.toDouble()));
        _gameOver = true;
        _saveProgress();
        toRemove.add(b);
        continue;
      }

      if (b.isPlayer) {
        Tank? hitEnemy;
        for (final e in _enemies) {
          if ((e.x - b.x).abs() < 0.6 && (e.y - b.y).abs() < 0.6) {
            hitEnemy = e;
            break;
          }
        }
        if (hitEnemy != null) {
          _explosions.add(Explosion(hitEnemy.x, hitEnemy.y));
          _enemies.remove(hitEnemy);
          toRemove.add(b);
          _score += hitEnemy.isFast ? 200 : 100;
          if (_enemies.isEmpty && _enemiesToSpawn == 0) {
            _levelCleared = true;
            _saveProgress();
          }
        }
      } else {
        if ((_player.x - b.x).abs() < 0.6 && (_player.y - b.y).abs() < 0.6) {
          _explosions.add(Explosion(_player.x, _player.y));
          toRemove.add(b);
          _lives--;
          if (_lives <= 0) {
            _gameOver = true;
            _saveProgress();
          } else {
            _player = Tank(4, 12, Dir.up, true);
            _saveProgress();
          }
        }
      }
    }
    _bullets.removeWhere((b) => toRemove.contains(b));

    for (final ex in _explosions) {
      ex.life--;
    }
    _explosions.removeWhere((ex) => ex.life <= 0);

    setState(() {});
  }

  bool _moveTank(Tank t, double speed) {
    double nx = t.x;
    double ny = t.y;
    switch (t.dir) {
      case Dir.up:
        ny -= speed;
        break;
      case Dir.down:
        ny += speed;
        break;
      case Dir.left:
        nx -= speed;
        break;
      case Dir.right:
        nx += speed;
        break;
    }
    if (nx < 0 || nx > gridSize - 1 || ny < 0 || ny > gridSize - 1) return false;
    final gx = nx.round();
    final gy = ny.round();
    final tile = _map[gy][gx];
    // 草丛(4)和空地(0)可穿过；砖墙(1)、钢板(2)、老鹰(3)、河流(5)不可穿过
    if (tile != 0 && tile != 4) return false;
    t.x = nx;
    t.y = ny;
    return true;
  }

  void _fire(Tank t) {
    if (_gameOver || _levelCleared || t.cooldown > 0) return;
    t.cooldown = t.isPlayer ? 11 : 26;
    _bullets.add(Bullet(t.x, t.y, t.dir, t.isPlayer));
  }

  @override
  void dispose() {
    _loop?.cancel();
    super.dispose();
  }

  Widget _dirBtn(Dir dir, IconData icon) {
    return GestureDetector(
      onTapDown: (_) => _heldDir = dir,
      onTapUp: (_) => _heldDir = null,
      onTapCancel: () => _heldDir = null,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade600),
        ),
        child: Icon(icon, size: 30, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showStartMenu) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('经典坦克大战', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.amber)),
              const SizedBox(height: 12),
              Text('历史最高分: $_highScore', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 36),
              if (_hasSave) ...[
                SizedBox(
                  width: 200,
                  height: 48,
                  child: FilledButton(onPressed: _continueGame, child: const Text('继续游戏')),
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: 200,
                height: 48,
                child: FilledButton.tonal(onPressed: _newGame, child: const Text('开始新游戏')),
              ),
            ],
          ),
        ),
      );
    }

    final remaining = _enemies.length + _enemiesToSpawn;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: Text('第$_level关  敌:$remaining  命:$_lives  分:$_score', style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存并返回菜单',
            onPressed: () async {
              await _saveProgress();
              _loop?.cancel();
              setState(() => _showStartMenu = true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.grey.shade700, width: 2),
                      ),
                      child: CustomPaint(
                        painter: _BattlePainter(_map, _player, _enemies, _bullets, _explosions),
                        size: Size.infinite,
                      ),
                    ),
                    if (_levelCleared)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('第 $_level 关过关！', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.amber)),
                              const SizedBox(height: 14),
                              FilledButton(onPressed: _nextLevel, child: Text(_level < maxLevel ? '进入第 ${_level + 1} 关' : '通关！重新挑战')),
                            ],
                          ),
                        ),
                      ),
                    if (_gameOver)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('GAME OVER', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              const SizedBox(height: 8),
                              Text('最终得分: $_score', style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 14),
                              FilledButton(onPressed: _newGame, child: const Text('重新开始')),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    _dirBtn(Dir.up, Icons.arrow_drop_up),
                    Row(
                      children: [
                        _dirBtn(Dir.left, Icons.arrow_left),
                        const SizedBox(width: 54),
                        _dirBtn(Dir.right, Icons.arrow_right),
                      ],
                    ),
                    _dirBtn(Dir.down, Icons.arrow_drop_down),
                  ],
                ),
                GestureDetector(
                  onTapDown: (_) => _fire(_player),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.shade200, width: 3),
                    ),
                    child: const Center(
                      child: Text('开火', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BattlePainter extends CustomPainter {
  final List<List<int>> map;
  final Tank player;
  final List<Tank> enemies;
  final List<Bullet> bullets;
  final List<Explosion> explosions;

  _BattlePainter(this.map, this.player, this.enemies, this.bullets, this.explosions);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 13;

    // 1. 先画砖墙(1)、钢板(2)、老鹰(3)、河流(5)
    for (int y = 0; y < 13; y++) {
      for (int x = 0; x < 13; x++) {
        final t = map[y][x];
        if (t == 1) _drawBrick(canvas, x * cell, y * cell, cell);
        if (t == 2) _drawSteel(canvas, x * cell, y * cell, cell);
        if (t == 3) _drawEagle(canvas, x * cell, y * cell, cell);
        if (t == 5) _drawWater(canvas, x * cell, y * cell, cell);
      }
    }

    // 2. 画坦克
    _drawTank(canvas, player, cell, Colors.amber.shade400);
    for (final e in enemies) {
      _drawTank(canvas, e, cell, e.isFast ? Colors.purpleAccent : Colors.redAccent);
    }

    // 3. 画子弹
    final bulletPaint = Paint()..color = Colors.white;
    for (final b in bullets) {
      canvas.drawCircle(Offset((b.x + 0.5) * cell, (b.y + 0.5) * cell), cell * 0.13, bulletPaint);
    }

    // 4. 画草丛(4)在坦克上层，实现半隐身效果
    for (int y = 0; y < 13; y++) {
      for (int x = 0; x < 13; x++) {
        if (map[y][x] == 4) _drawGrass(canvas, x * cell, y * cell, cell);
      }
    }

    // 5. 画爆炸火花
    for (final ex in explosions) {
      final cx = (ex.x + 0.5) * cell;
      final cy = (ex.y + 0.5) * cell;
      final r = cell * (0.2 + (10 - ex.life) * 0.04);
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.orangeAccent.withOpacity(ex.life / 10));
      canvas.drawCircle(Offset(cx, cy), r * 0.5, Paint()..color = Colors.yellow);
    }
  }

  void _drawBrick(Canvas canvas, double x, double y, double s) {
    final bg = Paint()..color = const Color(0xFF9C4A2B);
    final mortar = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.2;
    canvas.drawRect(Rect.fromLTWH(x + 1, y + 1, s - 2, s - 2), bg);
    canvas.drawLine(Offset(x + 1, y + s * 0.5), Offset(x + s - 1, y + s * 0.5), mortar);
    canvas.drawLine(Offset(x + s * 0.5, y + 1), Offset(x + s * 0.5, y + s * 0.5), mortar);
    canvas.drawLine(Offset(x + s * 0.25, y + s * 0.5), Offset(x + s * 0.25, y + s - 1), mortar);
    canvas.drawLine(Offset(x + s * 0.75, y + s * 0.5), Offset(x + s * 0.75, y + s - 1), mortar);
  }

  void _drawSteel(Canvas canvas, double x, double y, double s) {
    canvas.drawRect(Rect.fromLTWH(x + 1, y + 1, s - 2, s - 2), Paint()..color = Colors.grey.shade500);
    canvas.drawRect(Rect.fromLTWH(x + s * 0.22, y + s * 0.22, s * 0.56, s * 0.56), Paint()..color = Colors.grey.shade300);
  }

  void _drawEagle(Canvas canvas, double x, double y, double s) {
    final p = Paint()..color = Colors.amber;
    final cx = x + s * 0.5;
    final cy = y + s * 0.5;
    canvas.drawCircle(Offset(cx, cy - s * 0.15), s * 0.14, p);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + s * 0.1), width: s * 0.55, height: s * 0.22), p);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + s * 0.26), width: s * 0.24, height: s * 0.16), p);
  }

  void _drawWater(Canvas canvas, double x, double y, double s) {
    canvas.drawRect(Rect.fromLTWH(x + 1, y + 1, s - 2, s - 2), Paint()..color = Colors.blue.shade800);
    final wave = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x + s * 0.2, y + s * 0.35), Offset(x + s * 0.8, y + s * 0.35), wave);
    canvas.drawLine(Offset(x + s * 0.2, y + s * 0.65), Offset(x + s * 0.8, y + s * 0.65), wave);
  }

  void _drawGrass(Canvas canvas, double x, double y, double s) {
    canvas.drawRect(Rect.fromLTWH(x + 1, y + 1, s - 2, s - 2), Paint()..color = Colors.green.shade700.withOpacity(0.78));
  }

  void _drawTank(Canvas canvas, Tank t, double cell, Color color) {
    final cx = (t.x + 0.5) * cell;
    final cy = (t.y + 0.5) * cell;
    final trackPaint = Paint()..color = Colors.grey.shade700;

    // 履带
    if (t.dir == Dir.up || t.dir == Dir.down) {
      canvas.drawRect(Rect.fromCenter(center: Offset(cx - cell * 0.28, cy), width: cell * 0.18, height: cell * 0.78), trackPaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(cx + cell * 0.28, cy), width: cell * 0.18, height: cell * 0.78), trackPaint);
    } else {
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy - cell * 0.28), width: cell * 0.78, height: cell * 0.18), trackPaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + cell * 0.28), width: cell * 0.78, height: cell * 0.18), trackPaint);
    }

    // 车体与炮塔
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: cell * 0.52, height: cell * 0.52), Paint()..color = color);
    canvas.drawCircle(Offset(cx, cy), cell * 0.18, Paint()..color = Colors.white70);

    // 炮管
    final barrelPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = cell * 0.14
      ..strokeCap = StrokeCap.round;
    Offset end;
    switch (t.dir) {
      case Dir.up:
        end = Offset(cx, cy - cell * 0.48);
        break;
      case Dir.down:
        end = Offset(cx, cy + cell * 0.48);
        break;
      case Dir.left:
        end = Offset(cx - cell * 0.48, cy);
        break;
      case Dir.right:
        end = Offset(cx + cell * 0.48, cy);
        break;
    }
    canvas.drawLine(Offset(cx, cy), end, barrelPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
