import 'package:flutter/material.dart';
import '../../models/character.dart';
import '../../services/character_storage.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/snack_bar_service.dart';
import '../../services/token_manager.dart';
import '../../widgets/app_ui.dart';

class SyncCenterPage extends StatefulWidget {
  const SyncCenterPage({super.key});

  @override
  State<SyncCenterPage> createState() => _SyncCenterPageState();
}

class _SyncCenterPageState extends State<SyncCenterPage>
    with SingleTickerProviderStateMixin {
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
      await _storage.saveDownloadedCharacter(character);

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
    if (cloudUpdatedAt != null &&
        item.updatedAt != null &&
        cloudUpdatedAt.isAfter(item.updatedAt!)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("云端版本冲突"),
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
      final cloud = await _cloudService.fetchCloudList();
      final uploadedSummary = cloud.cast<CloudCharacterSummary?>().firstWhere(
        (c) => c?.id == item.id,
        orElse: () => null,
      );
      if (uploadedSummary?.updatedAt != null) {
        item.updatedAt = uploadedSummary!.updatedAt;
        await _storage.saveDownloadedCharacter(item);
      }
      final local = await _storage.loadAllCharacters();

      if (mounted) {
        Navigator.pop(context); // 关闭加载
        final name = item.profile.characterName.isEmpty
            ? "未命名"
            : item.profile.characterName;
        SnackBarService.showSuccess('「$name」上传成功');
        // 刷新云端与本地列表（用于更新 updated_at 等）
        setState(() {
          _cloudList = cloud;
          _localList = local;
        });
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kAppDesktopBreakpoint) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  // ---- 移动端布局（TabBar + TabBarView） ----
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("云端同步中心"),
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
      body: _buildTabBody(),
    );
  }

  // ---- 桌面端布局（左右两栏并排） ----
  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("云端同步中心"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "刷新",
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
      ),
      body: _buildDesktopBody(),
    );
  }

  // ---- 共享：加载/错误/正常内容判断 ----
  Widget _buildTabBody() {
    if (_isLoading) return const AppLoadingState(label: "正在同步列表");
    if (_errorMsg != null) return _buildErrorView();
    return TabBarView(
      controller: _tabController,
      children: [_buildCloudTab(), _buildLocalTab()],
    );
  }

  Widget _buildDesktopBody() {
    if (_isLoading) return const AppLoadingState(label: "正在同步列表");
    if (_errorMsg != null) return _buildErrorView();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: AppSectionTitle(
                  title: "云端角色 (下载)",
                  subtitle: "将云端角色保存到本机",
                  icon: Icons.cloud_download_outlined,
                ),
              ),
              Expanded(child: _buildCloudTab()),
            ],
          ),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: AppSectionTitle(
                  title: "本地角色 (上传)",
                  subtitle: "将本机角色同步到云端",
                  icon: Icons.upload_file_outlined,
                ),
              ),
              Expanded(child: _buildLocalTab()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return AppEmptyState(
      icon: Icons.cloud_off_outlined,
      title: "同步不可用",
      message: _errorMsg!,
      action: FilledButton.icon(
        onPressed: _initPage,
        icon: const Icon(Icons.refresh),
        label: const Text("重试"),
      ),
    );
  }

  // --- Tab 1: 云端角色 (下载) ---
  Widget _buildCloudTab() {
    if (_cloudList.isEmpty) {
      return const AppEmptyState(
        icon: Icons.cloud_queue_outlined,
        title: "云端暂无角色数据",
        message: "上传本地角色后，这里会显示可下载的云端存档。",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _cloudList.length,
      itemBuilder: (context, index) {
        final item = _cloudList[index];
        final cloudNewer = _isCloudNewer(item);

        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppPanel(
            padding: EdgeInsets.zero,
            child: ListTile(
              minVerticalPadding: 14,
              leading: Icon(
                Icons.cloud_download_outlined,
                color: cloudNewer ? cs.primary : cs.onSurfaceVariant,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: item.name),
                          TextSpan(
                            text:
                                ' #${item.id.length >= 4 ? item.id.substring(0, 4) : item.id}',
                            style: TextStyle(fontSize: 12, color: cs.outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (cloudNewer)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        "云端较新",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: cs.onPrimaryContainer,
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
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              trailing: IconButton.filledTonal(
                tooltip: "下载",
                icon: const Icon(Icons.download),
                onPressed: () => _handleDownload(item),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Tab 2: 本地角色 (上传) ---
  Widget _buildLocalTab() {
    if (_localList.isEmpty) {
      return const AppEmptyState(
        icon: Icons.description_outlined,
        title: "本地暂无角色数据",
        message: "创建角色或导入 PDF 后，即可上传到云端。",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _localList.length,
      itemBuilder: (context, index) {
        final item = _localList[index];
        final name = item.profile.characterName.isEmpty
            ? "未命名"
            : item.profile.characterName;
        final hasDetail =
            item.profile.race.isNotEmpty ||
            item.profile.classAndLevel.isNotEmpty;
        final detailText = hasDetail
            ? '${item.profile.race}${item.profile.race.isNotEmpty && item.profile.classAndLevel.isNotEmpty ? " | " : ""}${item.profile.classAndLevel}'
            : '';

        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppPanel(
            padding: EdgeInsets.zero,
            child: ListTile(
              minVerticalPadding: 14,
              leading: Icon(Icons.description_outlined, color: cs.primary),
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: name),
                    TextSpan(
                      text:
                          ' #${item.id.length >= 4 ? item.id.substring(0, 4) : item.id}',
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                  ],
                ),
              ),
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
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              trailing: IconButton.filledTonal(
                tooltip: "上传",
                icon: const Icon(Icons.upload),
                onPressed: () => _handleUpload(item),
              ),
            ),
          ),
        );
      },
    );
  }
}
