import 'dart:io';

import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:cafe_system/ui/widgets/cafe_page_heading.dart';
import 'package:flutter/material.dart';

class CafeBackupPage extends StatefulWidget {
  const CafeBackupPage({
    super.key,
    required this.backupDirectory,
    required this.onCreateBackup,
    required this.onListBackups,
    required this.onRestoreBackup,
    this.canManageBackups = true,
  });

  final String backupDirectory;
  final Future<File> Function() onCreateBackup;
  final Future<List<File>> Function() onListBackups;
  final Future<void> Function(File backup) onRestoreBackup;
  final bool canManageBackups;

  @override
  State<CafeBackupPage> createState() => _CafeBackupPageState();
}

class _CafeBackupPageState extends State<CafeBackupPage> {
  List<File> _backups = [];
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    if (widget.canManageBackups) {
      _refresh();
    } else {
      _loading = false;
    }
  }

  Future<void> _refresh() async {
    if (!widget.canManageBackups) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final backups = await widget.onListBackups();
      if (mounted) setState(() => _backups = backups);
    } catch (error) {
      _showMessage('تعذر قراءة النسخ الاحتياطية: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _working = true);
    try {
      final file = await widget.onCreateBackup();
      await _refresh();
      _showMessage('تم إنشاء نسخة احتياطية: ${file.uri.pathSegments.last}');
    } catch (error) {
      _showMessage('تعذر إنشاء النسخة الاحتياطية: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: const Text(
          'سيتم استبدال بيانات البرنامج بالبيانات الموجودة في النسخة المختارة. '
          'سيُنشئ البرنامج نسخة من البيانات الحالية قبل الاستعادة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await widget.onRestoreBackup(file);
      await _refresh();
      _showMessage('تمت استعادة النسخة الاحتياطية');
    } catch (error) {
      _showMessage('تعذرت استعادة النسخة: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _backupLabel(File file) {
    final modified = file.lastModifiedSync();
    return '${modified.day.toString().padLeft(2, '0')}/${modified.month.toString().padLeft(2, '0')}/${modified.year}  '
        '${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CafePageHeading(
          title: 'النسخ الاحتياطي والاستعادة',
          actions: widget.canManageBackups
              ? [
                  FilledButton.icon(
                    onPressed: _working ? null : _createBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('إنشاء نسخة الآن'),
                  ),
                ]
              : const [],
        ),
        if (widget.canManageBackups) ...[
          const SizedBox(height: 8),
          SelectableText(
            'مكان الحفظ: ${widget.backupDirectory}',
            style: const TextStyle(color: Colors.black54),
          ),
          if (_working) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          const Text(
            'النسخ المتاحة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _backups.isEmpty
                ? const Center(child: Text('لم يتم إنشاء نسخ احتياطية بعد'))
                : ListView.builder(
                    itemCount: _backups.length,
                    itemBuilder: (context, index) {
                      final file = _backups[index];
                      return Card(
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(
                            Icons.storage,
                            color: AppColors.green,
                          ),
                          title: Text(_backupLabel(file)),
                          subtitle: Text(file.uri.pathSegments.last),
                          trailing: OutlinedButton.icon(
                            onPressed: _working ? null : () => _restore(file),
                            icon: const Icon(Icons.settings_backup_restore),
                            label: const Text('استعادة'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    ),
  );
}
