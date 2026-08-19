import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/dm_models.dart';

typedef DmDirectoryProvider = Future<Directory> Function();

class DmStorage {
  final DmDirectoryProvider _directoryProvider;
  static Future<void> _ioQueue = Future.value();

  DmStorage({DmDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? _defaultDirectory;

  static Future<Directory> _defaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}${Platform.pathSeparator}dm');
  }

  Future<File> get _dataFile async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}dm_data.json');
  }

  Future<DmData> load() async {
    await _ioQueue;
    final file = await _dataFile;
    if (!await file.exists()) return DmData();

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('DM 数据文件根节点不是对象');
    }
    final json = Map<String, dynamic>.from(decoded);
    final versionValue = json['DnDToolkit-DM'];
    if (versionValue is! num) {
      throw const FormatException('DM 数据文件缺少格式标识');
    }
    final version = versionValue.toInt();
    if (version < 1 || version > DmData.schemaVersion) {
      throw FormatException('不支持的 DM 数据版本：$version');
    }
    return DmData.fromJson(json);
  }

  Future<File> save(DmData data) async {
    final payload = jsonEncode(data.toJson());
    final operation = _ioQueue.then<File>((_) async {
      final file = await _dataFile;
      await file.parent.create(recursive: true);
      final temporaryFile = File('${file.path}.tmp');
      await temporaryFile.writeAsString(payload, flush: true);
      if (await file.exists()) await file.delete();
      return temporaryFile.rename(file.path);
    });
    _ioQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
