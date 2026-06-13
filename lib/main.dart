import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

import 'timer_logic.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(NotificationService.init());
  runApp(const TomatoTimerApp());
}

class TomatoTimerApp extends StatelessWidget {
  const TomatoTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tomato Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        scaffoldBackgroundColor: Colors.red.shade50,
        useMaterial3: true,
      ),
      home: const TomatoPage(),
    );
  }
}

// --- Main Tomato Timer Page ---
class TomatoPage extends StatefulWidget {
  const TomatoPage({super.key});

  @override
  State<TomatoPage> createState() => _TomatoPageState();
}

class _TomatoPageState extends State<TomatoPage> {
  static const String _workSoundKey = 'work_sound_path';
  static const String _breakSoundKey = 'break_sound_path';
  final TextEditingController _workController = TextEditingController(text: "25:00");
  final TextEditingController _breakController = TextEditingController(text: "05:00");
  final FocusNode _workFocusNode = FocusNode();
  final FocusNode _breakFocusNode = FocusNode();

  Timer? _timer;
  bool _isRunning = false;
  bool _isWorkPhase = true;
  Duration _remaining = Duration.zero;
  Duration _workDuration = const Duration(minutes: 25);
  Duration _breakDuration = const Duration(minutes: 5);
  int _completedTomatoes = 0;
  int _totalFocusedMinutes = 0;
  bool _notificationsEnabled = true;
  bool _inAppSoundEnabled = false;
  String? _workSoundPath;
  String? _breakSoundPath;
  final AudioPlayer _workSoundPlayer = AudioPlayer();
  final AudioPlayer _breakSoundPlayer = AudioPlayer();
  String _workOriginalText = "25:00";
  String _breakOriginalText = "05:00";

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedSounds());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _workSoundPlayer.dispose();
    _breakSoundPlayer.dispose();
    _workController.dispose();
    _breakController.dispose();
    _workFocusNode.dispose();
    _breakFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phaseLabel = _isWorkPhase ? "Work" : "Break";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tomato Timer", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Credits',
            icon: const Icon(Icons.info_outline),
            onPressed: _showCreditsDialog,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Fixed line: using Theme.of(context).platform instead of defaultTargetPlatform
          final isCompact = constraints.maxWidth < 980 || Theme.of(context).platform == TargetPlatform.android;
          return isCompact ? _buildCompactLayout(phaseLabel) : _buildWideLayout(phaseLabel);
        },
      ),
    );
  }

  Widget _buildCompactLayout(String phaseLabel) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _tomatoHeroCard(phaseLabel),
            const SizedBox(height: 12),
            _timeBox(
              label: 'Work',
              controller: _workController,
              isActive: _isRunning && _isWorkPhase,
              readOnly: false,
              onIncrement: () => _adjustPhaseDuration('Work', 1),
              onDecrement: () => _adjustPhaseDuration('Work', -1),
              focusNode: _workFocusNode,
              onEdit: () => _highlightTimeField(_workController, _workFocusNode),
            ),
            const SizedBox(height: 12),
            _timeBox(
              label: 'Break',
              controller: _breakController,
              isActive: _isRunning && !_isWorkPhase,
              readOnly: false,
              onIncrement: () => _adjustPhaseDuration('Break', 1),
              onDecrement: () => _adjustPhaseDuration('Break', -1),
              focusNode: _breakFocusNode,
              onEdit: () => _highlightTimeField(_breakController, _breakFocusNode),
            ),
            const SizedBox(height: 12),
            _compactSummaryCard(),
            const SizedBox(height: 12),
            _settingsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(String phaseLabel) {
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Container(
            color: Colors.red.shade100.withValues(alpha: 0.35),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Work / Break Sounds', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _soundDropCard(
                    label: 'Work notification',
                    currentPath: _workSoundPath,
                    onPick: () => _pickSoundFile(isWork: true),
                    onDrop: (paths) async {
                      final nextPath = paths.isNotEmpty ? paths.first : null;
                      setState(() => _workSoundPath = nextPath);
                      await _saveSoundPaths();
                    },
                    onReset: () async {
                      await _workSoundPlayer.stop();
                      await _breakSoundPlayer.stop();
                      if (!mounted) return;
                      setState(() => _workSoundPath = null);
                      await _saveSoundPaths();
                    },
                  ),
                  const SizedBox(height: 12),
                  _soundDropCard(
                    label: 'Break notification',
                    currentPath: _breakSoundPath,
                    onPick: () => _pickSoundFile(isWork: false),
                    onDrop: (paths) async {
                      final nextPath = paths.isNotEmpty ? paths.first : null;
                      setState(() => _breakSoundPath = nextPath);
                      await _saveSoundPaths();
                    },
                    onReset: () async {
                      await _workSoundPlayer.stop();
                      await _breakSoundPlayer.stop();
                      if (!mounted) return;
                      setState(() => _breakSoundPath = null);
                      await _saveSoundPaths();
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text('Quick notes', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('• Use the arrow buttons to change each timer quickly.\n• Tap Edit to highlight the current time text for quick updates.'),
                  const SizedBox(height: 16),
                  const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable notifications'),
                    value: _notificationsEnabled,
                    onChanged: (value) => setState(() => _notificationsEnabled = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('In-app sound'),
                    value: _inAppSoundEnabled,
                    onChanged: (value) => setState(() => _inAppSoundEnabled = value),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _timeBox(
                    label: 'Work',
                    controller: _workController,
                    isActive: _isRunning && _isWorkPhase,
                    readOnly: false,
                    onIncrement: () => _adjustPhaseDuration('Work', 1),
                    onDecrement: () => _adjustPhaseDuration('Work', -1),
                    focusNode: _workFocusNode,
                    onEdit: () => _highlightTimeField(_workController, _workFocusNode),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const FittedBox(
                          fit: BoxFit.contain,
                          child: Text('🍅', style: TextStyle(fontSize: 150)),
                        ),
                        Image.asset(
                          'assets/tomato(By_AomAm).png',
                          width: 200,
                          height: 200,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                        ),
                        Positioned(
                          bottom: 20,
                          child: ElevatedButton.icon(
                            onPressed: _toggleLoop,
                            icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                            label: Text(_isRunning ? 'Stop $phaseLabel' : 'Start'),
                            style: ElevatedButton.styleFrom(
                              shape: const StadiumBorder(),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red.shade800,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              elevation: 4,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _timeBox(
                    label: 'Break',
                    controller: _breakController,
                    isActive: _isRunning && !_isWorkPhase,
                    readOnly: false,
                    onIncrement: () => _adjustPhaseDuration('Break', 1),
                    onDecrement: () => _adjustPhaseDuration('Break', -1),
                    focusNode: _breakFocusNode,
                    onEdit: () => _highlightTimeField(_breakController, _breakFocusNode),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: Container(
            color: Colors.red.shade100.withValues(alpha: 0.35),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stats', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _statusCard('Tomatoes completed', '$_completedTomatoes', Icons.eco_outlined),
                  const SizedBox(height: 10),
                  _statusCard('Focused hours', _formatHours(_totalFocusedMinutes), Icons.access_time),
                  const SizedBox(height: 18),
                  const Text('Progress', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Each finished work block adds 1 tomato and counts toward your total focused time.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactSummaryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Icon(Icons.insights, color: Colors.red.shade700),
          title: const Text('Your Stats', style: TextStyle(fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
          children: [
            Row(
              children: [
                Expanded(child: _statusCard('Tomatoes', '$_completedTomatoes', Icons.eco_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _statusCard('Focused', _formatHours(_totalFocusedMinutes), Icons.access_time)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tomatoHeroCard(String phaseLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          Text('Current phase: $phaseLabel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              const Text('🍅', style: TextStyle(fontSize: 90)),
              Image.asset(
                'assets/tomato(By_AomAm).png',
                width: 110,
                height: 110,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _toggleLoop,
            icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(_isRunning ? 'Stop $phaseLabel' : 'Start timer'),
            style: ElevatedButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Icon(Icons.settings, color: Colors.red.shade700),
          title: const Text('Settings & Notes', style: TextStyle(fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick notes', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('• Use the arrow buttons to change each timer quickly.\n• Tap Edit to highlight the current time text for quick updates.'),
                const SizedBox(height: 12),
                const Text('Work / Break Sounds', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _soundDropCard(
                  label: 'Work notification',
                  currentPath: _workSoundPath,
                  onPick: () => _pickSoundFile(isWork: true),
                  onDrop: (paths) async {
                    final nextPath = paths.isNotEmpty ? paths.first : null;
                    setState(() => _workSoundPath = nextPath);
                    await _saveSoundPaths();
                  },
                  onReset: () async {
                    await _workSoundPlayer.stop();
                    await _breakSoundPlayer.stop();
                    if (!mounted) return;
                    setState(() => _workSoundPath = null);
                    await _saveSoundPaths();
                  },
                ),
                const SizedBox(height: 10),
                _soundDropCard(
                  label: 'Break notification',
                  currentPath: _breakSoundPath,
                  onPick: () => _pickSoundFile(isWork: false),
                  onDrop: (paths) async {
                    final nextPath = paths.isNotEmpty ? paths.first : null;
                    setState(() => _breakSoundPath = nextPath);
                    await _saveSoundPaths();
                  },
                  onReset: () async {
                    await _workSoundPlayer.stop();
                    await _breakSoundPlayer.stop();
                    if (!mounted) return;
                    setState(() => _breakSoundPath = null);
                    await _saveSoundPaths();
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable notifications'),
                  value: _notificationsEnabled,
                  onChanged: (value) => setState(() => _notificationsEnabled = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('In-app sound'),
                  value: _inAppSoundEnabled,
                  onChanged: (value) => setState(() => _inAppSoundEnabled = value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreditsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Credits'),
        content: const Text(
          'Icon asset: assets/tomato(By_AomAm).ico made by [AomAm] from www.flaticon.com',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleLoop() {
    if (_isRunning) {
      _stopLoop(resetFields: true);
      return;
    }

    final workDuration = _parseDuration(_workController.text);
    final breakDuration = _parseDuration(_breakController.text);
    if (workDuration == null ||
        breakDuration == null ||
        workDuration.inSeconds <= 0 ||
        breakDuration.inSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter times as MM:SS")),
      );
      return;
    }

    _workDuration = workDuration;
    _breakDuration = breakDuration;
    _workOriginalText = _formatDuration(workDuration);
    _breakOriginalText = _formatDuration(breakDuration);
    _isWorkPhase = true;
    _startPhase(_workDuration);
  }

  void _startPhase(Duration duration) {
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _remaining = duration;
      _updateActiveController();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (_remaining.inSeconds <= 1) {
        _finishPhase();
        return;
      }

      setState(() {
        _remaining -= const Duration(seconds: 1);
        _updateActiveController();
      });
    });
  }

  void _finishPhase() {
    final finishedWork = _isWorkPhase;
    final finishedLabel = finishedWork ? "Work" : "Break";

    if (finishedWork) {
      _completedTomatoes += 1;
      _totalFocusedMinutes += _workDuration.inMinutes;
    }

    _timer?.cancel();
    setState(() {
      if (finishedWork) {
        _workController.text = _workOriginalText;
        _isWorkPhase = false;
      } else {
        _breakController.text = _breakOriginalText;
        _isWorkPhase = true;
      }
    });

    if (_inAppSoundEnabled) {
      unawaited(_playPhaseSound(finishedWork));
    }

    if (_notificationsEnabled) {
      unawaited(
        NotificationService.showNotification(
          "$finishedLabel timer finished",
          finishedWork ? "Break timer started." : "Work timer started.",
          identifier: "tomato_${finishedLabel.toLowerCase()}_timer",
        ),
      );
    }

    _startPhase(_isWorkPhase ? _workDuration : _breakDuration);
  }

  void _stopLoop({required bool resetFields}) {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _isRunning = false;
      _isWorkPhase = true;
      _remaining = Duration.zero;
      if (resetFields) {
        _workController.text = _workOriginalText;
        _breakController.text = _breakOriginalText;
      }
    });
  }

  void _updateActiveController() {
    final text = _formatDuration(_remaining);
    if (_isWorkPhase) {
      _workController.text = text;
    } else {
      _breakController.text = text;
    }
  }

  void _adjustPhaseDuration(String phase, int minutesDelta) {
    if (minutesDelta == 0) return;

    setState(() {
      if (phase == 'Work') {
        final updated = _workDuration + Duration(minutes: minutesDelta);
        if (updated.inMinutes < 1) return;
        _workDuration = updated;
        _workOriginalText = _formatDuration(updated);
        _workController.text = _workOriginalText;
        if (_isRunning && _isWorkPhase) {
          _remaining = Duration(seconds: (_remaining.inSeconds + minutesDelta * 60).clamp(1, updated.inSeconds));
          _updateActiveController();
        }
      } else {
        final updated = _breakDuration + Duration(minutes: minutesDelta);
        if (updated.inMinutes < 1) return;
        _breakDuration = updated;
        _breakOriginalText = _formatDuration(updated);
        _breakController.text = _breakOriginalText;
        if (_isRunning && !_isWorkPhase) {
          _remaining = Duration(seconds: (_remaining.inSeconds + minutesDelta * 60).clamp(1, updated.inSeconds));
          _updateActiveController();
        }
      }
    });
  }

  Duration? _parseDuration(String value) {
    final parts = value.trim().split(":");
    if (parts.length == 1) {
      final minutes = int.tryParse(parts.first);
      return minutes == null ? null : Duration(minutes: minutes);
    }
    if (parts.length != 2) return null;

    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null || seconds > 59) return null;
    return Duration(minutes: minutes, seconds: seconds);
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 9999 * 60 + 59);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  String _formatHours(int totalMinutes) {
    final hours = totalMinutes / 60.0;
    return hours >= 10 ? hours.toStringAsFixed(0) : hours.toStringAsFixed(1);
  }

  Future<void> _pickSoundFile({required bool isWork}) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        setState(() {
          if (isWork) {
            _workSoundPath = path;
          } else {
            _breakSoundPath = path;
          }
        });
        await _saveSoundPaths();
      }
    } catch (_) {}
  }

  Future<void> _loadSavedSounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _workSoundPath = prefs.getString(_workSoundKey);
        _breakSoundPath = prefs.getString(_breakSoundKey);
      });
    } catch (_) {}
  }

  Future<void> _saveSoundPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_workSoundKey, _workSoundPath ?? '');
      await prefs.setString(_breakSoundKey, _breakSoundPath ?? '');
    } catch (_) {}
  }

  Future<void> _playPhaseSound(bool isWorkPhase) async {
    final player = isWorkPhase ? _workSoundPlayer : _breakSoundPlayer;
    final customPath = isWorkPhase ? _workSoundPath : _breakSoundPath;

    try {
      await player.stop();
      if (customPath != null && customPath.isNotEmpty) {
        await player.play(DeviceFileSource(customPath));
        return;
      }
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        // Ignore sound playback failures on unsupported platforms.
      }
    }
  }

  void _highlightTimeField(TextEditingController controller, FocusNode focusNode) {
    focusNode.requestFocus();
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
      affinity: TextAffinity.downstream,
    );
  }

  Widget _statusCard(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _soundDropCard({
    required String label,
    required String? currentPath,
    required VoidCallback onPick,
    required ValueChanged<List<String>> onDrop,
    required VoidCallback onReset,
  }) {
    return DropTarget(
      onDragDone: (details) => onDrop(
        details.files.map((file) => file.path).whereType<String>().toList(),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              currentPath?.isNotEmpty == true
                  ? 'Using: ${currentPath!.split(Platform.pathSeparator).last}'
                  : 'Sound here',
              style: TextStyle(
                color: currentPath?.isNotEmpty == true ? Colors.red.shade800 : Colors.black54,
                fontSize: 13,
              ),
              softWrap: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.audiotrack),
                    label: const Text('Sound'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: IconButton(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reset sound',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeBox({
    required String label,
    required TextEditingController controller,
    required bool isActive,
    required bool readOnly,
    required FocusNode focusNode,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required VoidCallback onEdit,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      constraints: const BoxConstraints(minHeight: 96),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? Colors.red.shade100 : Colors.white,
        border: Border.all(
          color: isActive ? Colors.red.shade800 : Colors.black87,
          width: isActive ? 4 : 2,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Decrease $label',
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                onPressed: onDecrement,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.red.shade900 : Colors.grey.shade800,
                ),
              ),
              IconButton(
                tooltip: 'Increase $label',
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                onPressed: onIncrement,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: readOnly,
                  onTap: () => _highlightTimeField(controller, focusNode),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isActive ? Colors.red.shade900 : Colors.black,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Highlight $label time',
                icon: const Icon(Icons.edit, size: 18),
                onPressed: onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}