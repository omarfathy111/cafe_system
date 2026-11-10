import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:cafe_system/models/cafe_note.dart';
import 'package:cafe_system/ui/widgets/cafe_page_heading.dart';
import 'package:flutter/material.dart';

class CafeNotesPage extends StatefulWidget {
  const CafeNotesPage({super.key, required this.notes, required this.onAdd});

  final List<CafeNote> notes;
  final Future<CafeNote> Function(String text) onAdd;

  @override
  State<CafeNotesPage> createState() => _CafeNotesPageState();
}

class _CafeNotesPageState extends State<CafeNotesPage> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اكتب الملاحظة أولًا')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onAdd(text);
      if (mounted) _controller.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر حفظ الملاحظة: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dateTime(DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date • $time';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CafePageHeading(title: 'ملاحظات الكاشير والأدمن'),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'اكتب ملاحظة جديدة...',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _addNote,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('حفظ الملاحظة'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text(
                'سجل الملاحظات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text('${widget.notes.length} ملاحظة'),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: widget.notes.isEmpty
              ? const Center(child: Text('لسه مفيش ملاحظات محفوظة'))
              : ListView.separated(
                  itemCount: widget.notes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final note = widget.notes[index];
                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE6EAE5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.sticky_note_2_outlined,
                                  color: AppColors.green,
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _dateTime(note.createdAt),
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              note.text,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
