import 'dart:async';
import 'package:flutter/material.dart';
import 'results_screen.dart';

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
  int _currentStep = 0;
  bool _isComplete = false;

  final List<_ProcessingStep> _steps = [
    _ProcessingStep('Analyzing transcript...', 0.05),
    _ProcessingStep('Identifying key topics...', 0.15),
    _ProcessingStep('Segmenting into scenes...', 0.25),
    _ProcessingStep('Generating scene 1/8...', 0.35),
    _ProcessingStep('Generating scene 2/8...', 0.42),
    _ProcessingStep('Generating scene 3/8...', 0.48),
    _ProcessingStep('Generating scene 4/8...', 0.54),
    _ProcessingStep('Generating scene 5/8...', 0.60),
    _ProcessingStep('Generating scene 6/8...', 0.66),
    _ProcessingStep('Generating scene 7/8...', 0.72),
    _ProcessingStep('Generating scene 8/8...', 0.78),
    _ProcessingStep('Adding cinematic motion...', 0.85),
    _ProcessingStep('Composing video...', 0.92),
    _ProcessingStep('Finalizing output...', 0.98),
    _ProcessingStep('Done!', 1.0),
  ];

  @override
  void initState() {
    super.initState();
    _simulateProgress();
  }

  Future<void> _simulateProgress() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(Duration(milliseconds: 400 + (i * 80)));
      if (!mounted) return;
      setState(() {
        _currentStep = i;
        _statusText = _steps[i].label;
        _progress = _steps[i].progress;
      });
    }
    // Extra delay at 100%
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isComplete = true);
    // Auto-navigate to results
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          aspectRatio16by9: widget.aspectRatio16by9,
          transcript: widget.transcript,
        ),
      ),
    );
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
                  'v1.0.6',
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
                  : const SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        strokeWidth: 6,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                      ),
                    ),
            ),
            const SizedBox(height: 40),

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
            const SizedBox(height: 12),

            // Scene count
            Text(
              'Scene ${_currentStep < 4 ? '-' : (_currentStep - 3).clamp(1, 8)}/8',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 32),

            // Step indicators
            if (!_isComplete) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(
                  _steps.length,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= _currentStep
                          ? const Color(0xFF6C63FF)
                          : Colors.grey[300],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProcessingStep {
  final String label;
  final double progress;

  const _ProcessingStep(this.label, this.progress);
}