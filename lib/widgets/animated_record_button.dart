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
      widget.onRecordingStateChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          color: _localIsRecording
              ? const Color(0xFFE53935)
              : const Color(0xFF303030),
          border: Border.all(
            color: _localIsRecording
                ? const Color(0xFFEF5350)
                : Colors.grey[700]!,
            width: 2.5,
          ),
          boxShadow: [
            if (_localIsRecording)
              BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: _localIsProcessing
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Icon(
                _localIsRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                color: Colors.white,
                size: 28,
              ),
      ),
    );
  }
}
