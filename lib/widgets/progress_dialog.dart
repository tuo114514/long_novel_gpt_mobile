import 'package:flutter/material.dart';

class ProgressDialog extends StatelessWidget {
  final String message;
  final double? progress;
  final VoidCallback? onCancel;

  const ProgressDialog({super.key, required this.message, this.progress, this.onCancel});

  static Future<void> show(BuildContext context, {String message = '处理中...', VoidCallback? onCancel}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProgressDialog(message: message, onCancel: onCancel),
    );
  }

  static void update(BuildContext context, {String? message, double? progress}) {
    // 实际使用中由provider驱动
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 16)),
              if (progress != null) ...[ 
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 4),
                Text('${((progress! * 100).toStringAsFixed(0))}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              if (onCancel != null) ...[ 
                const SizedBox(height: 16),
                TextButton(onPressed: onCancel, child: const Text('取消')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
