import 'package:flutter/material.dart';
import '../../models/character.dart';
import '../../services/character_storage.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/snack_bar_service.dart';
import '../../services/token_manager.dart';

class SyncCenterPage extends StatefulWidget {
  const SyncCenterPage({super.key});

  @override
  State<SyncCenterPage> createState() => _SyncCenterPageState();
}

class _SyncCenterPageState extends State<SyncCenterPage> with SingleTickerProviderStateMixin {
  final CloudSyncService _cloudService = CloudSyncService.instance;
  final CharacterStorage _storage = CharacterStorage();

  late TabController _tabController;

  List<CloudCharacterSummary> _cloudList = [];
  List<Character> _localList = [];

  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initPage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 页面初始化：确保 Token 存在，然后加载数据
  Future<void> _initPage() async {
    // 确保令牌已配置
    final token = await TokenManager.ensureToken(context);
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = '未配置身份令牌，无法使用云端同步';
        });
      }
      return;
    }

    await _refreshData();
  }

  /// 刷新云端和本地数据
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final cloud = await _cloudService.fetchCloudList();
      final local = await _storage.loadAllCharacters();

      if (mounted) {
        setState(() {
          _cloudList = cloud;
          _localList = local;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = '加载失败：${e.toString()}';
        });
        SnackBarService.showError('云端连接失败：${e.toString()}');
      }
    }
  }

  /// 检测云端是否比本地更新
  bool _isCloudNewer(CloudCharacterSummary cloudItem) {
    final local = _localList.cast<Character?>().firstWhere(
      (c) => c?.id == cloudItem.id,
      orElse: () => null,
    );
    if (local == null) return true; // 本地没有，视为云端有新版本
    if (local.updatedAt == null) return false;
    if (cloudItem.updatedAt == null) return false;
    return cloudItem.updatedAt!.isAfter(local.updatedAt!);
  }

  /// 获取本地角色对应的云端更新时间（用于上传冲突检测）
  DateTime? _getCloudUpdatedAt(String charId) {
    final cloud = _cloudList.cast<CloudCharacterSummary?>().firstWhere(
      (c) => c?.id == charId,
      orElse: () => null,
    );
    return cloud?.updatedAt;
  }

  // --- 下载操作 ---
  Future<void> _handleDownload(CloudCharacterSummary item) async {
    try {
      // 显示加载
      _showLoadingOverlay();

      final character = await _cloudService.downloadCharacter(item.id);
      await _storage.saveCharacter(character);

      if (mounted) {
        Navigator.pop(context); // 关闭加载
        SnackBarService.showSuccess('「${item.name}」下载成功');
        // 刷新本地列表
        final local = await _storage.loadAllCharacters();
        setState(() => _localList = local);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载
        SnackBarService.showError('下载失败：${e.toString()}');
      }
    }
  }

  // --- 上传操作 ---
  Future<void> _handleUpload(Character item) async {
    // 冲突检测：云端版本比本地新时拦截
    final cloudUpdatedAt = _getCloudUpdatedAt(item.id);
    if (cloudUpdatedAt != null && item.updatedAt != null && cloudUpdatedAt.isAfter(item.updatedAt!)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("⚠️ 云端版本冲突"),
          content: Text(
            "云端存档比当前本地存档更新，强行上传将覆盖云端数据，确认继续吗？\n\n"
            "云端更新时间：${CloudSyncService.formatTime(cloudUpdatedAt)}\n"
            "本地更新时间：${CloudSyncService.formatTime(item.updatedAt)}",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("取消"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("确认覆盖"),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      _showLoadingOverlay();

      await _cloudService.uploadCharacter(item);

      if (mounted) {
        Navigator.pop(context); // 关闭加载
        final name = item.profile.characterName.isEmpty ? "未命名" : item.profile.characterName;
        SnackBarService.showSuccess('「$name」上传成功');
        // 刷新云端列表（用于更新 updated_at 等）
        final cloud = await _cloudService.fetchCloudList();
        setState(() => _cloudList = cloud);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载
        SnackBarService.showError('上传失败：${e.toString()}');
      }
    }
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("云端同步中心"),
        backgroundColor: cs.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "刷新",
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
        bottom: _errorMsg == null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: "云端角色 (下载)"),
                  Tab(text: "本地角色 (上传)"),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(_errorMsg!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _initPage,
                icon: const Icon(Icons.refresh),
                label: const Text("重试"),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildCloudTab(),
        _buildLocalTab(),
      ],
    );
  }

  // --- Tab 1: 云端角色 (下载) ---
  Widget _buildCloudTab() {
    if (_cloudList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_queue, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              "云端暂无角色数据",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _cloudList.length,
      itemBuilder: (context, index) {
        final item = _cloudList[index];
        final cloudNewer = _isCloudNewer(item);

        return ListTile(
          leading: Icon(
            Icons.cloud_download,
            color: cloudNewer ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Row(
            children: [
              Expanded(child: Text(item.name)),
              if (cloudNewer)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "云端有新版本",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.details.isNotEmpty)
                Text(
                  item.details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                '更新: ${CloudSyncService.formatTime(item.updatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _handleDownload(item),
          ),
        );
      },
    );
  }

  // --- Tab 2: 本地角色 (上传) ---
  Widget _buildLocalTab() {
    if (_localList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              "本地暂无角色数据",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _localList.length,
      itemBuilder: (context, index) {
        final item = _localList[index];
        final name = item.profile.characterName.isEmpty ? "未命名" : item.profile.characterName;
        final hasDetail = item.profile.race.isNotEmpty || item.profile.classAndLevel.isNotEmpty;
        final detailText = hasDetail
            ? '${item.profile.race}${item.profile.race.isNotEmpty && item.profile.classAndLevel.isNotEmpty ? " | " : ""}${item.profile.classAndLevel}'
            : '';

        return ListTile(
          leading: const Icon(Icons.description),
          title: Text(name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDetail)
                Text(
                  detailText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                '更新: ${CloudSyncService.formatTime(item.updatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.upload),
            onPressed: () => _handleUpload(item),
          ),
        );
      },
    );
  }
}
