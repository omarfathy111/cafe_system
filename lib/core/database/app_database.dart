import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_schema.dart';

class CafeDatabase {
  CafeDatabase._();
  static final CafeDatabase instance = CafeDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final appData =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    final databaseDirectory = Directory(path.join(appData, 'CafeSystem'));
    await databaseDirectory.create(recursive: true);
    final dbPath = path.join(databaseDirectory.path, 'cafe_system.db');
    _currentDatabasePath = dbPath;
    _database = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 20,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: CafeDatabaseSchema().createSchema,
        onUpgrade: CafeDatabaseSchema().upgradeSchema,
      ),
    );
    return _database!;
  }

  String? _currentDatabasePath;

  String get backupsDirectoryPath {
    final appData =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    return path.join(appData, 'CafeSystem', 'Backups');
  }

  Future<List<File>> listBackups() async {
    final directory = Directory(backupsDirectoryPath);
    if (!await directory.exists()) return [];
    final files = await directory
        .list()
        .where(
          (entity) => entity is File && path.extension(entity.path) == '.db',
        )
        .cast<File>()
        .toList();
    files.sort(
      (first, second) =>
          second.lastModifiedSync().compareTo(first.lastModifiedSync()),
    );
    return files;
  }

  Future<File> createBackup() async {
    final db = await database;
    final sourcePath = _currentDatabasePath!;
    final directory = Directory(backupsDirectoryPath);
    await directory.create(recursive: true);
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';
    final destination = File(
      path.join(directory.path, 'cafe_system_$stamp.db'),
    );
    await db.close();
    _database = null;
    try {
      return await File(sourcePath).copy(destination.path);
    } finally {
      await database;
    }
  }

  Future<void> restoreBackup(File backup) async {
    final normalizedBackup = path.normalize(backup.absolute.path);
    final normalizedDirectory = path.normalize(
      Directory(backupsDirectoryPath).absolute.path,
    );
    if (path.dirname(normalizedBackup) != normalizedDirectory ||
        path.extension(normalizedBackup) != '.db' ||
        !await backup.exists()) {
      throw ArgumentError('ملف النسخة الاحتياطية غير صالح');
    }

    final checkDb = await databaseFactory.openDatabase(
      normalizedBackup,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final integrity = await checkDb.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw StateError('ملف النسخة الاحتياطية تالف');
      }
      final tables = await checkDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('cafe_orders', 'cafe_sales', 'cafe_products')",
      );
      if (tables.length != 3) {
        throw StateError('ملف النسخة لا يخص نظام الكافيه');
      }
    } finally {
      await checkDb.close();
    }

    final recoveryCopy = await createBackup();
    final currentDb = await database;
    await currentDb.close();
    _database = null;
    final destinationPath = _currentDatabasePath!;
    try {
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$destinationPath$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }
      await File(normalizedBackup).copy(destinationPath);
      await database;
    } catch (_) {
      final openedDb = _database;
      if (openedDb != null) await openedDb.close();
      _database = null;
      final destination = File(destinationPath);
      if (await destination.exists()) await destination.delete();
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$destinationPath$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }
      await recoveryCopy.copy(destinationPath);
      await database;
      rethrow;
    }
  }
}
