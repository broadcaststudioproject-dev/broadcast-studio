// Copyright (c) 2026 Vinod Kumar Jannampally. All commercial and software rights reserved.
// Package: com.kingjvk.pocket_pcr

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/news_item.dart';

class NewsDatabaseHelper {
  static final NewsDatabaseHelper _instance = NewsDatabaseHelper._internal();
  factory NewsDatabaseHelper() => _instance;
  NewsDatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'ss_yatra_news.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE news_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        source TEXT,
        category TEXT,
        status TEXT,
        mediaUrl TEXT,
        date TEXT
      )
    ''');
  }

  // కొత్త వార్తను జోడించడం
  Future<int> insertNewsItem(NewsItem item) async {
    final db = await database;
    return await db.insert('news_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // అన్ని వార్తలను చదవడం (ఇక్కడే ఎర్రర్ వచ్చింది, ఇప్పుడు పరిష్కరించబడింది)
  Future<List<NewsItem>> getNewsItems() async {
    final db = await database;
    final maps = await db.query('news_items', orderBy: 'id DESC');
    
    return List.generate(maps.length, (i) {
      return NewsItem.fromMap(maps[i]);
    });
  }

  // వార్త స్థితిని (Status) అప్‌డేట్ చేయడం
  Future<int> updateNewsStatus(int id, String newStatus) async {
    final db = await database;
    return await db.update(
      'news_items',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // వార్తను తొలగించడం
  Future<int> deleteNewsItem(int id) async {
    final db = await database;
    return await db.delete(
      'news_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
