import 'package:flutter/material.dart';

Future<String?> showAdminPasswordDialog(
  BuildContext context, {
  required bool setup,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => AdminPasswordDialog(setup: setup),
);

class AdminPasswordDialog extends StatefulWidget {
  const AdminPasswordDialog({super.key, required this.setup});

  final bool setup;

  @override
  State<AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<AdminPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    if (password.length < 4) {
      setState(
        () => _error = 'كلمة المرور يجب أن تكون 4 أحرف أو أرقام على الأقل',
      );
      return;
    }
    if (widget.setup && password != _confirmationController.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }
    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.setup ? 'إنشاء كلمة مرور الأدمن' : 'دخول الأدمن'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController,
            autofocus: true,
            obscureText: true,
            onSubmitted: (_) {
              if (!widget.setup) _submit();
            },
            decoration: InputDecoration(
              labelText: widget.setup ? 'كلمة مرور جديدة' : 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          if (widget.setup) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmationController,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: Icon(Icons.lock_reset),
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: _submit, child: const Text('متابعة')),
    ],
  );
}
