import 'dart:convert';
import 'package:supabase/supabase.dart';
import 'package:intl/intl.dart';
import '../models/character.dart';
import 'character_storage.dart';
import 'token_manager.dart';

Map<String, dynamic> _decodeCharacterData(Object? rawData, String context) {
  if (rawData is Map) {
    return Map<String, dynamic>.from(rawData);
  }

  if (rawData is String) {
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      throw FormatException('$context 的 data 不是 JSON 对象');
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('$context 的 data 不是有效 JSON：$e');
    }
  }

  throw FormatException('$context 缺少可识别的角色 data');
}

/// 云端角色摘要（用于列表展示）
class CloudCharacterSummary {
  final String id;
  final String name;
  final String details;
  final DateTime? updatedAt;

  CloudCharacterSummary({
    required this.id,
    required this.name,
    required this.details,
    this.updatedAt,
  });

  factory CloudCharacterSummary.fromRow(Map<String, dynamic> row) {
    final data = _decodeCharacterData(row['data'], '云端角色 ${row['id']}');

    final name = data['Profile']?["CharacterName"] as String? ?? '未命名角色';
    final race = data['Profile']?["Race"] as String? ?? '';
    final cls = data['Profile']?["ClassAndLevel"] as String? ?? '';
    final details =
        '$race${race.isNotEmpty && cls.isNotEmpty ? " | " : ""}$cls';

    DateTime? updatedAt;
    if (row['updated_at'] != null) {
      updatedAt = DateTime.tryParse(row['updated_at'].toString());
    }

    return CloudCharacterSummary(
      id: row['id'] as String? ?? '',
      name: name,
      details: details,
      updatedAt: updatedAt,
    );
  }
}

/// 云端同步服务
/// 基于 Supabase + Token 身份认证，提供角色数据的云端存取
class CloudSyncService {
  // Supabase 配置
  static const String _supabaseUrl = 'https://kxmvhqhrjwnzcggbqlhb.supabase.co';
  static const String _supabaseAnonKey =
      'sb_publishable_gwJWSUQ_Ga18muqkL4JgHQ_urzgq0Mh';

  SupabaseClient? _client;
  String? _currentToken;

  static final CloudSyncService _instance = CloudSyncService._();
  static CloudSyncService get instance => _instance;
  CloudSyncService._();

  /// 获取或创建 SupabaseClient（自动注入 x-sync-token 请求头）
  Future<SupabaseClient> get client async {
    final token = await TokenManager.instance.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('尚未配置身份令牌，请先在设置中生成令牌');
    }

    // Token 未变则复用已有客户端
    if (_client != null && _currentToken == token) {
      return _client!;
    }

    _currentToken = token;
    _client = SupabaseClient(
      _supabaseUrl,
      _supabaseAnonKey,
      headers: {'x-sync-token': token},
    );
    return _client!;
  }

  /// 重置客户端（Token 变更时调用）
  Future<void> resetClient() {
    _client?.dispose();
    _client = null;
    _currentToken = null;
    // 下次访问 client getter 时会用新 token 重建
    return Future<void>.value();
  }

  /// 上传前去除 JSON 中的 base64 图片内容（减小体积，暂不考虑图片同步）
  Map<String, dynamic> _stripPortrait(Map<String, dynamic> json) {
    final profile = json['Profile'];
    if (profile is Map<String, dynamic> &&
        profile.containsKey('PortraitBase64')) {
      profile['PortraitBase64'] = '';
    }
    return json;
  }

  /// 下载后合并本地已有的 base64 图片内容（如有）
  Future<void> _mergeLocalPortrait(Character downloaded) async {
    try {
      final localChars = await CharacterStorage().loadAllCharacters();
      final local = localChars.cast<Character?>().firstWhere(
        (c) => c?.id == downloaded.id,
        orElse: () => null,
      );
      if (local != null && local.profile.portraitBase64.isNotEmpty) {
        downloaded.profile.portraitBase64 = local.profile.portraitBase64;
      }
    } catch (_) {
      // 本地无对应角色或无图片，忽略
    }
  }

  /// 获取云端角色列表
  Future<List<CloudCharacterSummary>> fetchCloudList() async {
    final c = await client;

    final response = await c.from('characters').select('id, data, updated_at');

    return (response as List<dynamic>)
        .map((e) => CloudCharacterSummary.fromRow(e as Map<String, dynamic>))
        .toList();
  }

  /// 根据 ID 从云端下载角色
  /// 下载后自动合并本地已存在的头像图片
  Future<Character> downloadCharacter(String id) async {
    final c = await client;

    final response = await c
        .from('characters')
        .select('data, updated_at')
        .eq('id', id)
        .single();

    final row = response;
    final data = _decodeCharacterData(row['data'], '云端角色 $id');

    // 确保 id 字段与数据库主键一致
    data['Id'] = id;

    final character = Character.fromJson(data);

    // 将云端的 updated_at 写入角色对象
    if (row['updated_at'] != null) {
      character.updatedAt = DateTime.tryParse(row['updated_at'].toString());
    }

    // 合并本地已有的头像图片
    await _mergeLocalPortrait(character);

    return character;
  }

  /// 上传角色到云端（upsert）
  /// 上传前会去除 base64 图片以减小体积
  Future<void> uploadCharacter(Character character) async {
    final c = await client;
    final token = _currentToken;
    if (token == null) {
      throw Exception('身份令牌异常');
    }

    // 序列化并去除图片
    final json = character.toJson();
    _stripPortrait(json);

    await c.from('characters').upsert({
      'id': character.id,
      'sync_token': token,
      'data': json,
      'updated_at': character.updatedAt!.toIso8601String(),
    });
  }

  /// 格式化时间用于 UI 展示
  static String formatTime(DateTime? dt) {
    if (dt == null) return '未知';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());
  }
}
