import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../services/snack_bar_service.dart';

/// 发现的服务器信息模型
class DiscoveryServer {
  final String ip;
  final int port;
  final String name;
  final DateTime lastSeen;

  DiscoveryServer({
    required this.ip,
    required this.port,
    required this.name,
  }) : lastSeen = DateTime.now();

  factory DiscoveryServer.fromJson(Map<String, dynamic> json) {
    return DiscoveryServer(
      ip: json['Ip'] ?? '',
      port: json['Port'] ?? 12345,
      name: json['Name'] ?? 'Unknown PC',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveryServer &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}

/// 简化的远程角色摘要模型 (用于列表显示)
class RemoteCharacterSummary {
  final String id;
  final String name;
  final String details;

  RemoteCharacterSummary({
    required this.id,
    required this.name,
    required this.details,
  });

  factory RemoteCharacterSummary.fromJson(Map<String, dynamic> json) {
    return RemoteCharacterSummary(
      id: json['Id'] ?? '',
      name: json['Name'] ?? '未命名角色',
      details: json['Details'] ?? '',
    );
  }
}

class LanSyncService {
  RawDatagramSocket? _udpSocket;
  final int _port = 12345;
  
  // 缓存设备信息，避免重复获取
  String? _cachedDeviceName;
  String? _cachedDeviceId;

  /// 获取设备名称和ID
  Future<Map<String, String>> _getDeviceInfo() async {
    if (_cachedDeviceName != null && _cachedDeviceId != null) {
      return {'name': _cachedDeviceName!, 'id': _cachedDeviceId!};
    }

    final deviceInfo = DeviceInfoPlugin();
    String name = "Flutter Client";
    String id = const Uuid().v4(); // 简单起见，这里生成一次性ID。生产环境建议存入SharedPreferences

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      name = "${androidInfo.brand} ${androidInfo.model}";
      id = androidInfo.id; // Android ID
    }

    _cachedDeviceName = name;
    _cachedDeviceId = id;
    return {'name': name, 'id': id};
  }

  /// 构建请求头
  Future<Map<String, String>> _buildHeaders(String pin) async {
    final info = await _getDeviceInfo();
    return {
      'Content-Type': 'application/json',
      'X-Auth-Pin': pin,
      'X-Device-Id': info['id']!,
      'X-Device-Name': info['name']!, // 防止中文乱码，可视情况进行 UrlEncode
    };
  }

  /// 开始监听 UDP 广播
  Stream<DiscoveryServer> startDiscovery() async* {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
      _udpSocket!.broadcastEnabled = true;

      await for (RawSocketEvent event in _udpSocket!) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _udpSocket!.receive();
          if (dg != null) {
            try {
              String message = utf8.decode(dg.data);
              Map<String, dynamic> json = jsonDecode(message);
              // 确保 json 包含必要字段
              if (json.containsKey('Ip')) {
                yield DiscoveryServer.fromJson(json);
              }
            } catch (e) {
              SnackBarService.showError("UDP 解析错误: $e");
            }
          }
        }
      }
    } catch (e) {
      // 这里的错误通常是因为端口被占用，但在Android上监听通常没问题
      SnackBarService.showError("UDP Bind Error: $e");
      rethrow;
    }
  }

  /// 停止监听
  void stopDiscovery() {
    _udpSocket?.close();
    _udpSocket = null;
  }

  /// 1. 获取远程列表
  Future<List<RemoteCharacterSummary>> getRemoteList(String ip, String pin) async {
    final url = Uri.parse('http://$ip:$_port/api/list');
    final headers = await _buildHeaders(pin);

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => RemoteCharacterSummary.fromJson(e)).toList();
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception("PIN 码错误");
    } else {
      throw Exception("连接失败: ${response.statusCode}");
    }
  }

  /// 2. 下载角色
  Future<Character> downloadCharacter(String ip, String pin, String charId) async {
    final url = Uri.parse('http://$ip:$_port/api/download?id=$charId');
    final headers = await _buildHeaders(pin);

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      // 获取到完整的 Character JSON：
      final Map<String, dynamic> json = jsonDecode(response.body);
      
      // 反序列化
      // 如果 Character.fromJson 能够处理该 JSON 结构
      return Character.fromJson(json);
    } else {
      throw Exception("下载失败: ${response.statusCode}");
    }
  }

  /// 3. 上传角色
  Future<void> uploadCharacter(String ip, String pin, Character character) async {
    final url = Uri.parse('http://$ip:$_port/api/upload');
    final headers = await _buildHeaders(pin);

    final body = jsonEncode(character.toJson());

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception("上传失败: ${response.statusCode} ${response.body}");
    }
  }
}