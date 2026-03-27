import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 离线缓存数据库服务
///
/// 使用 SQLite 实现本地数据缓存
/// 支持离线访问和数据同步
class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService instance = DatabaseService._internal();

  final Logger _logger = Logger();

  Database? _database;

  /// 数据库版本
  static const int _version = 1;

  /// 数据库名称
  static const String _dbName = 'nursing_app.db';

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _logger.i('初始化数据库: $path');

    return await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建表结构
  Future<void> _onCreate(Database db, int version) async {
    _logger.i('创建数据库表结构');

    // 通知缓存表
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        type INTEGER NOT NULL,
        content TEXT NOT NULL,
        title TEXT,
        is_read INTEGER DEFAULT 0,
        push_id TEXT,
        order_id INTEGER,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    // 地址缓存表
    await db.execute('''
      CREATE TABLE addresses (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        address TEXT NOT NULL,
        contact_name TEXT NOT NULL,
        contact_phone TEXT NOT NULL,
        is_default INTEGER DEFAULT 0,
        latitude REAL,
        longitude REAL,
        province TEXT,
        city TEXT,
        district TEXT,
        detail TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    // 订单缓存表
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY,
        order_no TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        nurse_id INTEGER,
        service_id INTEGER NOT NULL,
        service_name TEXT NOT NULL,
        service_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        contact_name TEXT NOT NULL,
        contact_phone TEXT NOT NULL,
        address TEXT NOT NULL,
        appointment_time TEXT NOT NULL,
        status INTEGER DEFAULT 0,
        pay_status INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    // 服务项目缓存表
    await db.execute('''
      CREATE TABLE services (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        description TEXT,
        icon_url TEXT,
        status INTEGER DEFAULT 1,
        category TEXT,
        created_at TEXT
      )
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX idx_notifications_user ON notifications(user_id)',
    );
    await db.execute('CREATE INDEX idx_addresses_user ON addresses(user_id)');
    await db.execute('CREATE INDEX idx_orders_user ON orders(user_id)');
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.i('升级数据库: $oldVersion -> $newVersion');
    // 未来版本升级逻辑
  }

  // ==================== 通知缓存 ====================

  /// 缓存通知列表
  Future<void> cacheNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (final notification in notifications) {
      batch.insert('notifications', {
        ...notification,
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    _logger.i('缓存 ${notifications.length} 条通知');
  }

  /// 获取缓存的通知
  Future<List<Map<String, dynamic>>> getCachedNotifications(int userId) async {
    final db = await database;
    return await db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  /// 更新通知已读状态
  Future<void> updateNotificationRead(int id) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清除通知缓存
  Future<void> clearNotifications(int userId) async {
    final db = await database;
    await db.delete('notifications', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ==================== 地址缓存 ====================

  /// 缓存地址列表
  Future<void> cacheAddresses(List<Map<String, dynamic>> addresses) async {
    final db = await database;
    final batch = db.batch();

    for (final address in addresses) {
      batch.insert('addresses', {
        ...address,
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    _logger.i('缓存 ${addresses.length} 个地址');
  }

  /// 获取缓存的地址
  Future<List<Map<String, dynamic>>> getCachedAddresses(int userId) async {
    final db = await database;
    return await db.query(
      'addresses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'is_default DESC, created_at DESC',
    );
  }

  /// 添加离线地址（待同步）
  Future<int> addOfflineAddress(Map<String, dynamic> address) async {
    final db = await database;
    return await db.insert('addresses', {...address, 'synced': 0});
  }

  /// 获取未同步的地址
  Future<List<Map<String, dynamic>>> getUnsyncedAddresses() async {
    final db = await database;
    return await db.query('addresses', where: 'synced = 0');
  }

  /// 标记地址已同步
  Future<void> markAddressSynced(int id, int serverId) async {
    final db = await database;
    await db.update(
      'addresses',
      {'id': serverId, 'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== 订单缓存 ====================

  /// 缓存订单列表
  Future<void> cacheOrders(List<Map<String, dynamic>> orders) async {
    final db = await database;
    final batch = db.batch();

    for (final order in orders) {
      batch.insert('orders', {
        ...order,
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    _logger.i('缓存 ${orders.length} 个订单');
  }

  /// 获取缓存的订单
  Future<List<Map<String, dynamic>>> getCachedOrders(
    int userId, {
    int? status,
  }) async {
    final db = await database;

    String where = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (status != null) {
      where += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.query(
      'orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
  }

  /// 获取单个订单
  Future<Map<String, dynamic>?> getCachedOrder(int orderId) async {
    final db = await database;
    final results = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ==================== 服务项目缓存 ====================

  /// 缓存服务列表
  Future<void> cacheServices(List<Map<String, dynamic>> services) async {
    final db = await database;

    // 先清空旧数据
    await db.delete('services');

    final batch = db.batch();
    for (final service in services) {
      batch.insert('services', service);
    }

    await batch.commit(noResult: true);
    _logger.i('缓存 ${services.length} 个服务项目');
  }

  /// 获取缓存的服务列表
  Future<List<Map<String, dynamic>>> getCachedServices({
    String? category,
  }) async {
    final db = await database;

    if (category != null) {
      return await db.query(
        'services',
        where: 'category = ? AND status = 1',
        whereArgs: [category],
      );
    }

    return await db.query('services', where: 'status = 1');
  }

  // ==================== 通用方法 ====================

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('notifications');
    await db.delete('addresses');
    await db.delete('orders');
    await db.delete('services');
    _logger.i('已清除所有缓存');
  }

  /// 清除用户相关缓存
  Future<void> clearUserCache(int userId) async {
    final db = await database;
    await db.delete('notifications', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('addresses', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('orders', where: 'user_id = ?', whereArgs: [userId]);
    _logger.i('已清除用户 $userId 的缓存');
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _logger.i('数据库已关闭');
    }
  }
}
