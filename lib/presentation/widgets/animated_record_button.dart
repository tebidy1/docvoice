import 'package:flutter/material.dart';

class AnimatedRecordButton extends StatefulWidget {
  final Future<void> Function()? onStartRecording;
  final Future<void> Function()? onStopRecording;
  final bool initialIsRecording;
  final bool initialIsProcessing;
  final void Function(bool isRecording)? onRecordingStateChanged;

  const AnimatedRecordButton({
    super.key,
    this.onStartRecording,
    this.onStopRecording,
    this.initialIsRecording = false,
    this.initialIsProcessing = false,
    this.onRecordingStateChanged,
  });

  @override
  State<AnimatedRecordButton> createState() => _AnimatedRecordButtonState();
}

class _AnimatedRecordButtonState extends State<AnimatedRecordButton> {
  late bool _localIsRecording;
  late bool _localIsProcessing;

  @override
  void initState() {
    super.initState();
    _localIsRecording = widget.initialIsRecording;
    _localIsProcessing = widget.initialIsProcessing;
  }

  @override
  void didUpdateWidget(AnimatedRecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sync processing state if parent finishes processing
    if (oldWidget.initialIsProcessing && !widget.initialIsProcessing) {
      _localIsProcessing = false;
    }

    // Sync local state if parent forces a stop externally
    if (!widget.initialIsRecording && _localIsRecording && !widget.initialIsProcessing) {
      _localIsRecording = false;
      _localIsProcessing = false;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRecordingStateChanged?.call(false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Idle styling: background from theme surface, border from theme outline
    final idleBg = colorScheme.surface;
    final idleBorder = colorScheme.outline;
    // Recording: always red (semantic color, not theme-dependent)
    const recordingBg = Color(0xFFE53935);
    const recordingBorder = Color(0xFFEF5350);

    return GestureDetector(
      onTap: _localIsProcessing
          ? null
          : () async {
              if (_localIsRecording) {
                // STOP
                setState(() {
                  _localIsRecording = false;
                  _localIsProcessing = true;
                });
                widget.onRecordingStateChanged?.call(false);
                
                if (widget.onStopRecording != null) {
                  await widget.onStopRecording!();
                }

                if (mounted) {
                  setState(() {
                    _localIsProcessing = false;
                  });
                }
              } else {
                // START
                setState(() => _localIsRecording = true);
                widget.onRecordingStateChanged?.call(true);

                if (widget.onStartRecording != null) {
                  await widget.onStartRecording!();
                }
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _localIsRecording ? recordingBg : idleBg,
          border: Border.all(
            color: _localIsRecording ? recordingBorder : idleBorder,
            width: 2.5,
          ),
          boxShadow: [
            if (_localIsRecording)
              BoxShadow(
                color: recordingBg.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: _localIsProcessing
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: colorScheme.primary),
              )
            : Icon(
                _localIsRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                color: _localIsRecording ? Colors.white : colorScheme.onSurface,
                size: 28,
              ),
      ),
    );
  }
}






