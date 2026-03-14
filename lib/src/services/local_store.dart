import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_models.dart';

class LocalStore {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, 'bitsend.db');
    _database = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE pending_transfers (
            transfer_id TEXT PRIMARY KEY,
            chain TEXT NOT NULL,
            network TEXT NOT NULL,
            wallet_engine TEXT NOT NULL DEFAULT 'local',
            direction TEXT NOT NULL,
            status TEXT NOT NULL,
            amount_lamports INTEGER NOT NULL,
            sender_address TEXT NOT NULL,
            receiver_address TEXT NOT NULL,
            transport_hint TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL,
            updated_at_ms INTEGER NOT NULL,
            envelope_json TEXT NOT NULL,
            remote_endpoint TEXT,
            tx_signature TEXT,
            explorer_url TEXT,
            last_error TEXT,
            confirmed_at_ms INTEGER,
            bitgo_wallet_id TEXT,
            bitgo_transfer_id TEXT,
            backend_status TEXT,
            fileverse_receipt_id TEXT,
            fileverse_receipt_url TEXT,
            fileverse_saved_at_ms INTEGER,
            fileverse_storage_mode TEXT,
            fileverse_message TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE pending_transfers ADD COLUMN chain TEXT NOT NULL DEFAULT 'solana'",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE pending_transfers ADD COLUMN network TEXT NOT NULL DEFAULT 'testnet'",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE pending_transfers ADD COLUMN wallet_engine TEXT NOT NULL DEFAULT 'local'",
          );
          await db.execute(
            'ALTER TABLE pending_transfers ADD COLUMN bitgo_wallet_id TEXT',
          );
          await db.execute(
            'ALTER TABLE pending_transfers ADD COLUMN bitgo_transfer_id TEXT',
          );
          await db.execute(
            'ALTER TABLE pending_transfers ADD COLUMN backend_status TEXT',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE pending_transfers ADD COLUMN fileverse_receipt_id TEXT',
          );
          await db.execute(
            'ALTER TABLE pending_transfers ADD COLUMN fileverse_receipt_url TEXT',
          );
          await db.execute(
            'ALTER TABLE pending_transfers ADD COLUMN fileverse_saved_at_ms INTEGER',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE pending_transfers ADD COLUMN fileverse_storage_mode TEXT',
          );
          await db.execute(
            'ALTER TABLE pending_transfers ADD COLUMN fileverse_message TEXT',
          );
        }
      },
    );

    return _database!;
  }

  Future<List<PendingTransfer>> loadTransfers() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'pending_transfers',
      orderBy: 'updated_at_ms DESC',
    );
    return rows.map(PendingTransfer.fromDbMap).toList();
  }

  Future<void> upsertTransfer(PendingTransfer transfer) async {
    final Database db = await database;
    await db.insert(
      'pending_transfers',
      transfer.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PendingTransfer?> findByTransferId(String transferId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'pending_transfers',
      where: 'transfer_id = ?',
      whereArgs: <Object?>[transferId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return PendingTransfer.fromDbMap(rows.first);
  }

  Future<PendingTransfer?> findBySignature(String signature) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'pending_transfers',
      where: 'tx_signature = ?',
      whereArgs: <Object?>[signature],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return PendingTransfer.fromDbMap(rows.first);
  }

  Future<void> saveSetting(String key, Object? value) async {
    final Database db = await database;
    await db.insert('settings', <String, Object?>{
      'key': key,
      'value': value == null ? null : jsonEncode(value),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<T?> loadSetting<T>(String key) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final String? value = rows.first['value'] as String?;
    if (value == null) {
      return null;
    }
    return jsonDecode(value) as T;
  }

  Future<void> clearAll() async {
    final Database db = await database;
    await db.delete('pending_transfers');
    await db.delete('settings');
  }
}
