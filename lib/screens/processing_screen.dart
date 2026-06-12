import 'dart:async';
import 'package:flutter/material.dart';
import 'results_screen.dart';

/// VideoGenerationBloc — polls every 2 seconds (matching backend pattern)
class VideoGenerationBloc {
  Timer? _pollingTimer;
  double _progress = 0.0;
  String _statusText = 'Analyzing transcript...';
  final List<_ProcessingStep> _steps;
  int _currentStep = 0;
  bool _isComplete = false;

  final void Function(double progress, String status, bool isComplete) onUpdate;
  final VoidCallback onComplete;

  VideoGenerationBloc({
    required this.onUpdate,
    required this.onComplete,
  }) : _steps = [
          // Stage 1: Transcript Analysis (segment_transcript.py logic)
          _ProcessingStep('Analyzing transcript...', 0.05, 'segment'),
          _ProcessingStep('Splitting into 8-second clips...', 0.10, 'segment'),
          _ProcessingStep('Optimizing for social media pacing...', 0.15, 'segment'),

          // Stage 2: Visual Generation (generate_visuals.py logic)
          _ProcessingStep('Generating scene 1/8...', 0.22, 'visual'),
          _ProcessingStep('Generating scene 2/8...', 0.30, 'visual'),
          _ProcessingStep('Generating scene 3/8...', 0.37, 'visual'),
          _ProcessingStep('Generating scene 4/8...', 0.44, 'visual'),
          _ProcessingStep('Generating scene 5/8...', 0.51, 'visual'),
          _ProcessingStep('Generating scene 6/8...', 0.58, 'visual'),
          _ProcessingStep('Generating scene 7/8...', 0.65, 'visual'),
          _ProcessingStep('Generating scene 8/8...', 0.72, 'visual'),

          // Stage 3: Cinematic Motion (FFmpeg zoompan fallback + assembly)
          _ProcessingStep('Applying cinematic motion effects...', 0.78, 'motion'),
          _ProcessingStep('Adding zoompan camera animation...', 0.85, 'motion'),
          _ProcessingStep('Composing final video...', 0.92, 'compose'),
          _ProcessingStep('Finalizing output...', 0.98, 'compose'),
          _ProcessingStep('Done!', 1.0, 'done'),
        ];

  void startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentStep < _steps.length - 1) {
        _currentStep++;
        _progress = _steps[_currentStep].progress;
        _statusText = _steps[_currentStep].label;
        onUpdate(_progress, _statusText, false);
      } else {
        _isComplete = true;
        _progress = 1.0;
        _statusText = 'Done!';
        timer.cancel();
        onUpdate(1.0, 'Done!', true);
        onComplete();
      }
    });

    // Emit the initial state immediately
    onUpdate(_progress, _statusText, false);
  }

  void dispose() {
    _pollingTimer?.cancel();
  }
}

class ProcessingScreen extends StatefulWidget {
  final String transcript;
  final bool aspectRatio16by9;

  const ProcessingScreen({
    super.key,
    required this.transcript,
    required this.aspectRatio16by9,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  double _progress = 0.0;
  String _statusText = 'Analyzing transcript...';
  bool _isComplete = false;
  int _sceneCounter = 0;
  String _stageLabel = 'Analyzing';
  VideoGenerationBloc? _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = VideoGenerationBloc(
      onUpdate: (progress, status, isComplete) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          _statusText = status;
          _isComplete = isComplete;
          // Extract scene number if present
          final sceneMatch = RegExp(r'scene (\d+)/8').firstMatch(status);
          if (sceneMatch != null) {
            _sceneCounter = int.parse(sceneMatch.group(1)!);
          }
          // Determine stage
          if (status.contains('Analyzing') || status.contains('Splitting') || status.contains('Optimizing')) {
            _stageLabel = 'Analyzing';
          } else if (status.contains('scene')) {
            _stageLabel = 'Generating';
          } else if (status.contains('motion') || status.contains('zoompan') || status.contains('camera')) {
            _stageLabel = 'Motion';
          } else if (status.contains('Composing') || status.contains('Finalizing')) {
            _stageLabel = 'Composing';
          } else {
            _stageLabel = 'Complete';
          }
        });
      },
      onComplete: () {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResultsScreen(
                aspectRatio16by9: widget.aspectRatio16by9,
                transcript: widget.transcript,
              ),
            ),
          );
        });
      },
    );
    _bloc!.startPolling();
  }

  @override
  void dispose() {
    _bloc?.dispose();
    super.dispose();
  }

  String get _sceneDisplay {
    if (_stageLabel == 'Analyzing') return '—';
    if (_sceneCounter > 0) return '$_sceneCounter/8';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generating Video'),
        centerTitle: true,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'v1.0.7',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isComplete
                  ? const Icon(
                      Icons.check_circle,
                      key: ValueKey('check'),
                      size: 80,
                      color: Colors.green,
                    )
                  : SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        strokeWidth: 6,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                      ),
                    ),
            ),
            const SizedBox(height: 40),

            // Stage indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _stageColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _stageLabel,
                style: TextStyle(
                  color: _stageColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF6C63FF),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 24),

            // Status text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _statusText,
                key: ValueKey(_statusText),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2D2D2D),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),

            // Scene counter
            Text(
              'Scene $_sceneDisplay',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),

            const SizedBox(height: 12),

            // Polling indicator
            if (!_isComplete)
              Text(
                'Polling every 2s...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                    ),
              ),

            const SizedBox(height: 32),

            // Backend pipeline reference
            if (!_isComplete)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backend Pipeline:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildPipelineStep('segment_transcript.py', _stageLabel == "Analyzing" || _progress >= 0.05),
                    _buildPipelineStep('generate_visuals.py', _stageLabel == 'Generating' || _progress >= 0.22),
                    _buildPipelineStep('FFmpeg zoompan → assembly', _stageLabel == 'Motion' || _progress >= 0.78),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color get _stageColor {
    switch (_stageLabel) {
      case 'Analyzing':
        return Colors.blue;
      case 'Generating':
        return Colors.orange;
      case 'Motion':
        return Colors.purple;
      case 'Composing':
        return Colors.teal;
      case 'Complete':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPipelineStep(String label, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: active ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? Colors.grey[800] : Colors.grey[400],
              decoration: active ? TextDecoration.none : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingStep {
  final String label;
  final double progress;
  final String stage;

  const _ProcessingStep(this.label, this.progress, this.stage);
}