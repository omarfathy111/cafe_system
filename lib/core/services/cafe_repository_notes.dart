part of 'cafe_repository.dart';

extension CafeRepositoryNotes on CafeRepository {
  Future<CafeNote> addNote(String note) async {
    final text = note.trim();
    if (text.isEmpty) throw ArgumentError('اكتب الملاحظة أولًا');
    final db = await _database.database;
    final createdAt = DateTime.now();
    final id = await db.insert('cafe_notes', {
      'note_text': text,
      'created_at': createdAt.toIso8601String(),
    });
    return CafeNote(id: id, text: text, createdAt: createdAt);
  }

}
