import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/lan_sync_service.dart';
import 'transfer_page.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final LanSyncService _service = LanSyncService();
  
  // 使用 Set 去重，或者 List 配合逻辑去重
  final List<DiscoveryServer> _servers = [];
  // 记录最后一次更新时间，用于清理离线设备（可选）
  StreamSubscription? _subscription;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _service.stopDiscovery();
    _subscription?.cancel();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _servers.clear();
      _isScanning = true;
    });

    _subscription = _service.startDiscovery().listen((server) {
      // 收到广播
      setState(() {
        // 如果列表中已存在（IP端口相同），则更新，否则添加
        final index = _servers.indexWhere((s) => s.ip == server.ip && s.port == server.port);
        if (index != -1) {
          _servers[index] = server; // 更新（比如名字变了）
        } else {
          _servers.add(server);
        }
      });
    }, onError: (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("扫描出错: $e")));
      }
    });
  }

  void _connectToServer(DiscoveryServer server) {
    final TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("连接到 ${server.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("请输入 PC 端显示的 4 位 PIN 码"),
            const SizedBox(height: 10),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                hintText: "PIN",
                border: OutlineInputBorder(),
                counterText: "",
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (pinController.text.length == 4) {
                _navigateToTransfer(server, pinController.text);
              }
            },
            child: const Text("连接"),
          ),
        ],
      ),
    );
  }

  void _navigateToTransfer(DiscoveryServer server, String pin) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransferPage(
          serverIp: server.ip,
          pin: pin,
          serverName: server.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("局域网同步"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "请确保手机与电脑处于同一 Wi-Fi 网络下\n且电脑端已开启同步模式",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _servers.isEmpty
                ? const Center(child: Text("正在搜索设备..."))
                : ListView.separated(
                    itemCount: _servers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final server = _servers[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.computer),
                        ),
                        title: Text(server.name),
                        subtitle: Text("${server.ip}:${server.port}"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _connectToServer(server),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}