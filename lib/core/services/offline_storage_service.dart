import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../shared/models/entry.dart';

final offlineStorageServiceProvider = Provider<OfflineStorageService>((ref) {
  return OfflineStorageService();
});

class SyncQueueItem {
  final String queueId;
  final String action; // 'CREATE_ENTRY' | 'UPDATE_ENTRY' | 'DELETE_ENTRY'
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  SyncQueueItem({
    required this.queueId,
    required this.action,
    required this.entityId,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() => {
        'queueId': queueId,
        'action': action,
        'entityId': entityId,
        'payload': jsonEncode(payload),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'retryCount': retryCount,
        'lastError': lastError,
      };

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedPayload = {};
    try {
      final raw = map['payload'];
      if (raw is String) {
        parsedPayload = jsonDecode(raw) as Map<String, dynamic>;
      } else if (raw is Map) {
        parsedPayload = Map<String, dynamic>.from(raw);
      }
    } catch (_) {}

    return SyncQueueItem(
      queueId: map['queueId'] as String,
      action: map['action'] as String,
      entityId: map['entityId'] as String,
      payload: parsedPayload,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      retryCount: map['retryCount'] as int? ?? 0,
      lastError: map['lastError'] as String?,
    );
  }
}

class OfflineStorageService {
  Database? _db;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // In-memory fallbacks when SQLite native binary is unavailable (e.g. headless unit tests)
  final Map<String, Entry> _memEntries = {};
  final List<Entry> _memFeed = [];
  final List<Map<String, dynamic>> _memWatchlist = [];
  final Map<String, SyncQueueItem> _memQueue = {};

  Future<Database?> _getDatabase() async {
    if (_db != null && _db!.isOpen) return _db;
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'watchhive_offline.db');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE cached_entries (
              id TEXT PRIMARY KEY,
              userId TEXT,
              tmdbId INTEGER,
              type TEXT,
              isWatching INTEGER,
              watchedAt TEXT,
              jsonData TEXT,
              cachedAt INTEGER,
              isPendingSync INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE cached_feed (
              id TEXT PRIMARY KEY,
              jsonData TEXT,
              activityDate INTEGER,
              cachedAt INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE cached_watchlist (
              id TEXT PRIMARY KEY,
              tmdbId INTEGER,
              jsonData TEXT,
              cachedAt INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE offline_sync_queue (
              queueId TEXT PRIMARY KEY,
              action TEXT,
              entityId TEXT,
              payload TEXT,
              createdAt INTEGER,
              retryCount INTEGER,
              lastError TEXT
            )
          ''');
        },
      );
      _isInitialized = true;
      return _db;
    } catch (e) {
      debugPrint('[OfflineStorageService] SQLite unavailable, using in-memory store: $e');
      _isInitialized = true;
      return null;
    }
  }

  // ─── ENTRIES CACHE ──────────────────────────────────────────────────────────

  Future<void> cacheEntries(List<Entry> entries, {bool? isWatching}) async {
    for (final e in entries) {
      _memEntries[e.id] = e;
    }

    final db = await _getDatabase();
    if (db == null) return;

    try {
      final batch = db.batch();
      for (final e in entries) {
        batch.insert(
          'cached_entries',
          {
            'id': e.id,
            'userId': e.userId,
            'tmdbId': e.tmdbId,
            'type': e.type,
            'isWatching': e.isWatching ? 1 : 0,
            'watchedAt': e.watchedAt.toIso8601String(),
            'jsonData': jsonEncode(e.toFullJson()),
            'cachedAt': DateTime.now().millisecondsSinceEpoch,
            'isPendingSync': e.isPendingSync ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[OfflineStorageService] Error caching entries: $e');
    }
  }

  Future<void> insertOrUpdateCachedEntry(Entry entry) async {
    _memEntries[entry.id] = entry;

    final db = await _getDatabase();
    if (db == null) return;

    try {
      await db.insert(
        'cached_entries',
        {
          'id': entry.id,
          'userId': entry.userId,
          'tmdbId': entry.tmdbId,
          'type': entry.type,
          'isWatching': entry.isWatching ? 1 : 0,
          'watchedAt': entry.watchedAt.toIso8601String(),
          'jsonData': jsonEncode(entry.toFullJson()),
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
          'isPendingSync': entry.isPendingSync ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[OfflineStorageService] Error saving entry: $e');
    }
  }

  Future<void> removeCachedEntry(String id) async {
    _memEntries.remove(id);

    final db = await _getDatabase();
    if (db == null) return;

    try {
      await db.delete('cached_entries', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[OfflineStorageService] Error removing entry: $e');
    }
  }

  Future<List<Entry>> getCachedEntries({bool? isWatching, String? type, String? userId}) async {
    final db = await _getDatabase();
    if (db == null) {
      var list = _memEntries.values.toList();
      if (isWatching != null) {
        list = list.where((e) => e.isWatching == isWatching).toList();
      }
      if (type != null && type.isNotEmpty) {
        list = list.where((e) => e.type == type).toList();
      }
      if (userId != null && userId.isNotEmpty) {
        list = list.where((e) => e.userId == userId).toList();
      }
      list.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
      return list;
    }

    try {
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (isWatching != null) {
        whereClauses.add('isWatching = ?');
        whereArgs.add(isWatching ? 1 : 0);
      }
      if (type != null && type.isNotEmpty) {
        whereClauses.add('type = ?');
        whereArgs.add(type);
      }
      if (userId != null && userId.isNotEmpty) {
        whereClauses.add('userId = ?');
        whereArgs.add(userId);
      }

      final results = await db.query(
        'cached_entries',
        where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'watchedAt DESC',
      );

      final entries = <Entry>[];
      for (final row in results) {
        final jsonStr = row['jsonData'] as String?;
        if (jsonStr != null && jsonStr.isNotEmpty) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            final entry = Entry.fromJson(map).copyWith(
              isPendingSync: (row['isPendingSync'] as int? ?? 0) == 1,
            );
            entries.add(entry);
          } catch (_) {}
        }
      }
      return entries;
    } catch (e) {
      debugPrint('[OfflineStorageService] Error fetching cached entries: $e');
      return _memEntries.values.toList();
    }
  }

  // ─── FEED CACHE ─────────────────────────────────────────────────────────────

  Future<void> cacheFeed(List<Entry> entries) async {
    _memFeed.clear();
    _memFeed.addAll(entries);

    final db = await _getDatabase();
    if (db == null) return;

    try {
      final batch = db.batch();
      batch.delete('cached_feed');
      for (final e in entries) {
        batch.insert('cached_feed', {
          'id': e.id,
          'jsonData': jsonEncode(e.toFullJson()),
          'activityDate': e.activityDate.millisecondsSinceEpoch,
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[OfflineStorageService] Error caching feed: $e');
    }
  }

  Future<List<Entry>> getCachedFeed() async {
    final db = await _getDatabase();
    if (db == null) return List<Entry>.from(_memFeed);

    try {
      final results = await db.query(
        'cached_feed',
        orderBy: 'activityDate DESC',
        limit: 50,
      );

      final entries = <Entry>[];
      for (final row in results) {
        final jsonStr = row['jsonData'] as String?;
        if (jsonStr != null && jsonStr.isNotEmpty) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            entries.add(Entry.fromJson(map));
          } catch (_) {}
        }
      }
      return entries;
    } catch (e) {
      debugPrint('[OfflineStorageService] Error reading cached feed: $e');
      return List<Entry>.from(_memFeed);
    }
  }

  // ─── WATCHLIST CACHE ────────────────────────────────────────────────────────

  Future<void> cacheWatchlist(List<Map<String, dynamic>> items) async {
    _memWatchlist.clear();
    _memWatchlist.addAll(items);

    final db = await _getDatabase();
    if (db == null) return;

    try {
      final batch = db.batch();
      batch.delete('cached_watchlist');
      for (final item in items) {
        final id = (item['id'] ?? item['tmdbId'] ?? DateTime.now().millisecondsSinceEpoch).toString();
        batch.insert('cached_watchlist', {
          'id': id,
          'tmdbId': (item['tmdbId'] as num?)?.toInt() ?? 0,
          'jsonData': jsonEncode(item),
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[OfflineStorageService] Error caching watchlist: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedWatchlist() async {
    final db = await _getDatabase();
    if (db == null) return List<Map<String, dynamic>>.from(_memWatchlist);

    try {
      final results = await db.query('cached_watchlist', orderBy: 'cachedAt DESC');
      final list = <Map<String, dynamic>>[];
      for (final row in results) {
        final jsonStr = row['jsonData'] as String?;
        if (jsonStr != null && jsonStr.isNotEmpty) {
          try {
            list.add(jsonDecode(jsonStr) as Map<String, dynamic>);
          } catch (_) {}
        }
      }
      return list;
    } catch (e) {
      debugPrint('[OfflineStorageService] Error fetching cached watchlist: $e');
      return List<Map<String, dynamic>>.from(_memWatchlist);
    }
  }

  // ─── OFFLINE SYNC QUEUE ─────────────────────────────────────────────────────

  Future<SyncQueueItem> enqueueSyncAction({
    required String action,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final queueId = 'queue_${DateTime.now().millisecondsSinceEpoch}_${entityId.hashCode.abs()}';
    final item = SyncQueueItem(
      queueId: queueId,
      action: action,
      entityId: entityId,
      payload: payload,
      createdAt: DateTime.now(),
    );

    _memQueue[queueId] = item;

    final db = await _getDatabase();
    if (db != null) {
      try {
        await db.insert('offline_sync_queue', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('[OfflineStorageService] Error enqueuing sync action: $e');
      }
    }

    return item;
  }

  Future<List<SyncQueueItem>> getPendingSyncActions() async {
    final db = await _getDatabase();
    if (db == null) {
      final list = _memQueue.values.toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    }

    try {
      final rows = await db.query('offline_sync_queue', orderBy: 'createdAt ASC');
      return rows.map((r) => SyncQueueItem.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[OfflineStorageService] Error reading sync queue: $e');
      return _memQueue.values.toList();
    }
  }

  Future<void> removeSyncAction(String queueId) async {
    _memQueue.remove(queueId);

    final db = await _getDatabase();
    if (db != null) {
      try {
        await db.delete('offline_sync_queue', where: 'queueId = ?', whereArgs: [queueId]);
      } catch (e) {
        debugPrint('[OfflineStorageService] Error removing sync action: $e');
      }
    }
  }

  Future<void> updateSyncActionError(String queueId, String error) async {
    if (_memQueue.containsKey(queueId)) {
      final old = _memQueue[queueId]!;
      _memQueue[queueId] = SyncQueueItem(
        queueId: old.queueId,
        action: old.action,
        entityId: old.entityId,
        payload: old.payload,
        createdAt: old.createdAt,
        retryCount: old.retryCount + 1,
        lastError: error,
      );
    }

    final db = await _getDatabase();
    if (db != null) {
      try {
        await db.rawUpdate(
          'UPDATE offline_sync_queue SET retryCount = retryCount + 1, lastError = ? WHERE queueId = ?',
          [error, queueId],
        );
      } catch (e) {
        debugPrint('[OfflineStorageService] Error updating sync queue error: $e');
      }
    }
  }

  Future<int> getPendingCount() async {
    final db = await _getDatabase();
    if (db == null) return _memQueue.length;

    try {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM offline_sync_queue');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return _memQueue.length;
    }
  }

  Future<void> clearAllCache() async {
    _memEntries.clear();
    _memFeed.clear();
    _memWatchlist.clear();
    _memQueue.clear();

    final db = await _getDatabase();
    if (db != null) {
      try {
        await db.delete('cached_entries');
        await db.delete('cached_feed');
        await db.delete('cached_watchlist');
        await db.delete('offline_sync_queue');
      } catch (_) {}
    }
  }
}
