import 'dart:async';

import 'package:flutter/material.dart';

class DanmuAutoShieldPrompt extends StatefulWidget {
  const DanmuAutoShieldPrompt({
    super.key,
    required this.message,
    required this.onAccept,
    required this.onReject,
    required this.onIgnorePermanently,
    this.countdown = const Duration(seconds: 5),
  });

  final String message;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onIgnorePermanently;
  final Duration countdown;

  @override
  State<DanmuAutoShieldPrompt> createState() => _DanmuAutoShieldPromptState();
}

class _DanmuAutoShieldPromptState extends State<DanmuAutoShieldPrompt> {
  Timer? _timer;
  late int _remainingSeconds;
  var _resolved = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        _resolve(widget.onAccept);
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  void _resolve(VoidCallback action) {
    if (_resolved) {
      return;
    }
    _resolved = true;
    _timer?.cancel();
    action();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Material(
          color: colorScheme.surface,
          elevation: 8,
          shadowColor: Colors.black45,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '检测到重复弹幕',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('以下弹幕即将自动加入屏蔽关键词：'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _remainingSeconds / widget.countdown.inSeconds,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  runAlignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => _resolve(widget.onIgnorePermanently),
                      child: const Text('永不加入'),
                    ),
                    TextButton(
                      onPressed: () => _resolve(widget.onReject),
                      child: const Text('拒绝'),
                    ),
                    FilledButton(
                      onPressed: () => _resolve(widget.onAccept),
                      child: Text('同意（${_remainingSeconds}s）'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
