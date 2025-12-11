import 'package:flutter/material.dart';
import '../../models/character.dart';
import '../../services/character_storage.dart';
import '../../services/lan_sync_service.dart';

class TransferPage extends StatefulWidget {
  final String serverIp;
  final String pin;
  final String serverName;

  const TransferPage({
    super.key,
    required this.serverIp,
    required this.pin,
    required this.serverName,
  });

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> with SingleTickerProviderStateMixin {
  final LanSyncService _syncService = LanSyncService();
  final CharacterStorage _storage = CharacterStorage();

  late TabController _tabController;
  
  // 数据源
  List<RemoteCharacterSummary> _remoteList = [];
  List<Character> _localList = [];
  
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initConnection();
  }

  Future<void> _initConnection() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      // 1. 获取远程列表（同时验证 PIN）
      final remote = await _syncService.getRemoteList(widget.serverIp, widget.pin);
      
      // 2. 获取本地列表
      final local = await _storage.loadAllCharacters();

      if (mounted) {
        setState(() {
          _remoteList = remote;
          _localList = local;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = e.toString();
        });
        // 验证失败，延迟退出
        if (e.toString().contains("PIN")) {
           _showErrorAndExit("PIN 码验证失败");
        }
      }
    }
  }

  void _showErrorAndExit(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("连接错误"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // 关弹窗
              Navigator.pop(context); // 退出页面
            },
            child: const Text("确定"),
          )
        ],
      ),
    );
  }

  // --- 下载操作 ---
  Future<void> _handleDownload(RemoteCharacterSummary item) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // 1. 下载
      final character = await _syncService.downloadCharacter(widget.serverIp, widget.pin, item.id);
      
      // 2. 保存到本地
      character.id = UniqueKey().toString(); // 生成新 ID
      await _storage.saveCharacter(character);

      if (mounted) {
        Navigator.pop(context); // 关 Loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("下载成功")));
        // 刷新本地列表
        final local = await _storage.loadAllCharacters();
        setState(() => _localList = local);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关 Loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("下载失败: $e")));
      }
    }
  }

  // --- 上传操作 ---
  Future<void> _handleUpload(Character item) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await _syncService.uploadCharacter(widget.serverIp, widget.pin, item);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("上传成功")));
        // 刷新远程列表
        final remote = await _syncService.getRemoteList(widget.serverIp, widget.pin);
        setState(() => _remoteList = remote);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("上传失败: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.serverName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "电脑端角色 (下载)"),
            Tab(text: "本机角色 (上传)"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_errorMsg!),
                    ),
                    ElevatedButton(onPressed: _initConnection, child: const Text("重试"))
                  ],
                ))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: 远程列表
                    _buildRemoteListView(),
                    // Tab 2: 本地列表
                    _buildLocalListView(),
                  ],
                ),
    );
  }

  Widget _buildRemoteListView() {
    if (_remoteList.isEmpty) {
      return const Center(child: Text("电脑端没有角色数据"));
    }
    return ListView.builder(
      itemCount: _remoteList.length,
      itemBuilder: (context, index) {
        final item = _remoteList[index];
        return ListTile(
          leading: const Icon(Icons.cloud_download),
          title: Text(item.name),
          subtitle: Text(item.details),
          trailing: IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _handleDownload(item),
          ),
        );
      },
    );
  }

  Widget _buildLocalListView() {
    if (_localList.isEmpty) {
      return const Center(child: Text("本地没有角色数据"));
    }
    return ListView.builder(
      itemCount: _localList.length,
      itemBuilder: (context, index) {
        final item = _localList[index];
        return ListTile(
          leading: const Icon(Icons.description),
          title: Text(item.profile.characterName.isEmpty ? "未命名" : item.profile.characterName),
          subtitle: Text("${item.profile.race} | ${item.profile.classAndLevel}"),
          trailing: IconButton(
            icon: const Icon(Icons.upload),
            onPressed: () => _handleUpload(item),
          ),
        );
      },
    );
  }
}