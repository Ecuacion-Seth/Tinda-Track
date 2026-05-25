import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final _uuid = const Uuid();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tindatrack.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE seasonal_recommendations (
          id TEXT PRIMARY KEY,
          month INTEGER NOT NULL,
          event_name TEXT NOT NULL,
          product_name TEXT NOT NULL,
          category TEXT NOT NULL,
          reason TEXT NOT NULL,
          urgency INTEGER NOT NULL,
          weeks_before INTEGER NOT NULL
        )
      ''');
      await _seedSeasonalData(db);
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL)',
    );

    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category_id TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        barcode TEXT,
        image_path TEXT,
        low_stock_threshold INTEGER DEFAULT 5,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL,
        quantity_sold INTEGER NOT NULL,
        total_price REAL NOT NULL,
        sold_at TEXT NOT NULL,
        FOREIGN KEY (item_id) REFERENCES items (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE seasonal_recommendations (
        id TEXT PRIMARY KEY,
        month INTEGER NOT NULL,
        event_name TEXT NOT NULL,
        product_name TEXT NOT NULL,
        category TEXT NOT NULL,
        reason TEXT NOT NULL,
        urgency INTEGER NOT NULL,
        weeks_before INTEGER NOT NULL
      )
    ''');

    await _seedDatabase(db);
    await _seedSeasonalData(db);
  }

  Future<void> _seedSeasonalData(Database db) async {
    final seasons = [
      {
        'm': 1,
        'event': 'New Year Recovery',
        'prod': 'Instant Noodles',
        'cat': 'Daily Essentials',
        'reason': 'Quick meals after heavy holiday prep.',
        'u': 2,
        'w': 2,
      },
      {
        'm': 2,
        'event': "Valentine's Day",
        'prod': 'Chocolates',
        'cat': 'Snacks',
        'reason': 'High impulse buy for gifting.',
        'u': 3,
        'w': 3,
      },
      {
        'm': 3,
        'event': 'Holy Week Prep',
        'prod': 'Sardines & Tuna',
        'cat': 'Canned Goods',
        'reason': 'Fasting and meat alternatives.',
        'u': 2,
        'w': 4,
      },
      {
        'm': 4,
        'event': 'Summer Heat',
        'prod': 'Cold Drinks',
        'cat': 'Beverages',
        'reason': 'Peak temperature increases beverage velocity.',
        'u': 3,
        'w': 2,
      },
      {
        'm': 5,
        'event': 'Flores de Mayo',
        'prod': 'Snacks & Juices',
        'cat': 'Snacks',
        'reason': 'Community gatherings and processions.',
        'u': 2,
        'w': 2,
      },
      {
        'm': 6,
        'event': 'Back to School',
        'prod': 'Skyflakes & Bear Brand',
        'cat': 'Snacks',
        'reason': 'Parents buying daily baon supplies.',
        'u': 3,
        'w': 4,
      },
      {
        'm': 7,
        'event': 'Rainy Season',
        'prod': 'Instant Coffee',
        'cat': 'Beverages',
        'reason': 'Comfort drinks during monsoon.',
        'u': 2,
        'w': 2,
      },
      {
        'm': 8,
        'event': 'Mid-Year Replenish',
        'prod': 'Rice & Noodles',
        'cat': 'Daily Essentials',
        'reason': 'Steady staple movement.',
        'u': 1,
        'w': 1,
      },
      {
        'm': 9,
        'event': 'Ber Months Start',
        'prod': 'Noche Buena Staples',
        'cat': 'Canned Goods',
        'reason': 'Early shoppers begin hoarding holiday items.',
        'u': 2,
        'w': 4,
      },
      {
        'm': 10,
        'event': 'Pre-Undas Prep',
        'prod': 'Candles & Travel Snacks',
        'cat': 'Daily Essentials',
        'reason': 'Travel and cemetery preparation.',
        'u': 3,
        'w': 3,
      },
      {
        'm': 11,
        'event': 'Undas & Holiday Ramp',
        'prod': 'Evap & Condensed Milk',
        'cat': 'Canned Goods',
        'reason': 'Dessert prep begins for early parties.',
        'u': 3,
        'w': 4,
      },
      {
        'm': 12,
        'event': 'Christmas Peak',
        'prod': 'Fruit Cocktail & Softdrinks',
        'cat': 'Beverages',
        'reason': 'Peak family gatherings and feasts.',
        'u': 3,
        'w': 4,
      },
    ];

    for (var s in seasons) {
      await db.insert('seasonal_recommendations', {
        'id': _uuid.v4(),
        'month': s['m'],
        'event_name': s['event'],
        'product_name': s['prod'],
        'category': s['cat'],
        'reason': s['reason'],
        'urgency': s['u'],
        'weeks_before': s['w'],
      });
    }
  }

  Future<void> _seedDatabase(Database db) async {
    final categories = {
      'cat_drinks': 'Beverages',
      'cat_snacks': 'Snacks',
      'cat_canned': 'Canned Goods',
      'cat_essentials': 'Daily Essentials',
    };

    for (var entry in categories.entries) {
      await db.insert('categories', {'id': entry.key, 'name': entry.value});
    }

    final now = DateTime.now().toIso8601String();
    final items = [
      {
        'name': 'Bear Brand Swak 33g',
        'cat': 'cat_drinks',
        'price': 15.0,
        'qty': 45,
        'barcode': '4800361397003',
      },
      {
        'name': 'Milo Sachet 24g',
        'cat': 'cat_drinks',
        'price': 10.0,
        'qty': 60,
        'barcode': '4800361365286',
      },
      {
        'name': 'Skyflakes Crackers',
        'cat': 'cat_snacks',
        'price': 8.0,
        'qty': 100,
        'barcode': '4800016644445',
      },
      {
        'name': 'Piattos Cheese',
        'cat': 'cat_snacks',
        'price': 18.0,
        'qty': 25,
        'barcode': '4800016252015',
      },
      {
        'name': 'Lucky Me Pancit Canton Original',
        'cat': 'cat_essentials',
        'price': 16.0,
        'qty': 40,
        'barcode': '',
      },
      {
        'name': 'Lucky Me Pancit Canton Chilimansi',
        'cat': 'cat_essentials',
        'price': 16.0,
        'qty': 50,
        'barcode': '',
      },
      {
        'name': 'Century Tuna Flakes in Oil 155g',
        'cat': 'cat_canned',
        'price': 35.0,
        'qty': 15,
        'barcode': '',
      },
      {
        'name': '555 Sardines in Tomato Sauce',
        'cat': 'cat_canned',
        'price': 22.0,
        'qty': 30,
        'barcode': '',
      },
      {
        'name': 'Nescafe Original Sachet',
        'cat': 'cat_drinks',
        'price': 7.0,
        'qty': 80,
        'barcode': '',
      },
      {
        'name': 'Kopiko Blanca',
        'cat': 'cat_drinks',
        'price': 8.0,
        'qty': 70,
        'barcode': '',
      },
      {
        'name': 'Magic Flakes',
        'cat': 'cat_snacks',
        'price': 8.0,
        'qty': 4,
        'barcode': '',
      },
      {
        'name': 'Fita Crackers',
        'cat': 'cat_snacks',
        'price': 8.0,
        'qty': 20,
        'barcode': '',
      },
      {
        'name': 'Coke Mismo',
        'cat': 'cat_drinks',
        'price': 20.0,
        'qty': 24,
        'barcode': '',
      },
      {
        'name': 'Sprite Mismo',
        'cat': 'cat_drinks',
        'price': 20.0,
        'qty': 12,
        'barcode': '',
      },
      {
        'name': 'Datu Puti Vinegar 200ml',
        'cat': 'cat_essentials',
        'price': 15.0,
        'qty': 10,
        'barcode': '',
      },
      {
        'name': 'Silver Swan Soy Sauce 200ml',
        'cat': 'cat_essentials',
        'price': 15.0,
        'qty': 3,
        'barcode': '',
      },
    ];

    for (var item in items) {
      await db.insert('items', {
        'id': _uuid.v4(),
        'name': item['name'],
        'category_id': item['cat'],
        'price': item['price'],
        'quantity': item['qty'],
        'barcode': item['barcode'],
        'image_path': null,
        'low_stock_threshold': 5,
        'updated_at': now,
      });
    }

    final random = Random();
    final itemIds = (await db.query(
      'items',
      columns: ['id'],
    )).map((r) => r['id'] as String).toList();

    for (int i = 89; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final isWeekend =
          date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      int salesCount = isWeekend
          ? 8 + random.nextInt(6)
          : 4 + random.nextInt(4);

      if (date.month == 12) salesCount += 3;

      for (int s = 0; s < salesCount; s++) {
        final itemId = itemIds[random.nextInt(itemIds.length)];
        final qty = 1 + random.nextInt(3);
        await db.insert('sales', {
          'id': _uuid.v4(),
          'item_id': itemId,
          'quantity_sold': qty,
          'total_price': qty * 15.0,
          'sold_at': date.toIso8601String(),
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await database;
    return await db.query('items', orderBy: 'name ASC');
  }

  Future<int> insertItem(Map<String, dynamic> itemMap) async {
    final db = await database;
    return await db.insert('items', itemMap);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<int> updateItem(Map<String, dynamic> itemMap) async {
    final db = await database;
    return await db.update(
      'items',
      itemMap,
      where: 'id = ?',
      whereArgs: [itemMap['id']],
    );
  }

  Future<int> deleteItem(String id) async {
    final db = await database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getItemByBarcode(String barcode) async {
    final db = await database;
    final result = await db.query(
      'items',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> insertSale(Map<String, dynamic> saleMap) async {
    final db = await database;
    return await db.insert('sales', saleMap);
  }

  Future<void> processCheckout(List<Map<String, dynamic>> updates) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var op in updates) {
        await txn.update(
          'items',
          op['itemMap'],
          where: 'id = ?',
          whereArgs: [op['itemMap']['id']],
        );
        await txn.insert('sales', op['saleMap']);
      }
    });
  }

  Future<int> getTotalItemsCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) as count FROM items'),
        ) ??
        0;
  }

  Future<int> getLowStockCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) as count FROM items WHERE quantity <= low_stock_threshold',
          ),
        ) ??
        0;
  }

  Future<double> getTodaysRevenue() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      "SELECT SUM(total_price) as total FROM sales WHERE sold_at LIKE ?",
      ['$today%'],
    );
    final total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
  }

  Future<List<Map<String, dynamic>>> getSalesLast7Days() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 6))
        .toIso8601String()
        .substring(0, 10);
    return await db.rawQuery(
      "SELECT sold_at, total_price FROM sales WHERE sold_at >= ? ORDER BY sold_at ASC",
      [sevenDaysAgo],
    );
  }

  Future<List<Map<String, dynamic>>> getItemVelocity() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);
    return await db.rawQuery(
      '''
      SELECT i.name, i.quantity, COALESCE(SUM(s.quantity_sold), 0) as weekly_sales
      FROM items i
      LEFT JOIN sales s ON s.item_id = i.id AND s.sold_at >= ?
      GROUP BY i.id
      ORDER BY weekly_sales DESC
    ''',
      [sevenDaysAgo],
    );
  }

  Future<List<Map<String, dynamic>>> getSeasonalRecommendations(
    int month,
  ) async {
    final db = await database;
    int nextMonth = month == 12 ? 1 : month + 1;
    return await db.query(
      'seasonal_recommendations',
      where: 'month IN (?, ?)',
      whereArgs: [month, nextMonth],
    );
  }

  Future<Map<String, dynamic>> getMonthlySalesSummary(
    int year,
    int month,
  ) async {
    final db = await database;
    final likeString =
        '${year.toString()}-${month.toString().padLeft(2, '0')}-%';
    final res = await db.rawQuery(
      '''
      SELECT SUM(total_price) as revenue, SUM(quantity_sold) as units, COUNT(id) as trans_count
      FROM sales WHERE sold_at LIKE ?
    ''',
      [likeString],
    );
    return res.isNotEmpty ? res.first : {};
  }

  Future<Map<String, dynamic>?> getTopItemForMonth(int year, int month) async {
    final db = await database;
    final likeString =
        '${year.toString()}-${month.toString().padLeft(2, '0')}-%';
    final res = await db.rawQuery(
      '''
      SELECT i.name, SUM(s.quantity_sold) as total_qty 
      FROM sales s JOIN items i ON s.item_id = i.id 
      WHERE s.sold_at LIKE ? GROUP BY s.item_id ORDER BY total_qty DESC LIMIT 1
    ''',
      [likeString],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getDailySalesForMonth(
    int year,
    int month,
  ) async {
    final db = await database;
    final likeString =
        '${year.toString()}-${month.toString().padLeft(2, '0')}-%';
    return await db.rawQuery(
      '''
      SELECT SUBSTR(sold_at, 9, 2) as day, SUM(total_price) as daily_total
      FROM sales WHERE sold_at LIKE ? GROUP BY day ORDER BY day ASC
    ''',
      [likeString],
    );
  }

  Future<List<Map<String, dynamic>>> getSalesLast28Days() async {
    final db = await database;
    final pastDate = DateTime.now()
        .subtract(const Duration(days: 28))
        .toIso8601String()
        .substring(0, 10);
    return await db.rawQuery(
      '''
      SELECT s.item_id, i.name, s.quantity_sold, s.sold_at
      FROM sales s JOIN items i ON s.item_id = i.id
      WHERE s.sold_at >= ?
    ''',
      [pastDate],
    );
  }
}
