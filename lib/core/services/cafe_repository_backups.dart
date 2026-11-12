part of 'cafe_repository.dart';

extension CafeRepositoryBackups on CafeRepository {
  Future<File> createBackup() => _database.createBackup();

  Future<List<File>> listBackups() => _database.listBackups();

  Future<void> restoreBackup(File backup) => _database.restoreBackup(backup);

  String get backupsDirectoryPath => _database.backupsDirectoryPath;

}
