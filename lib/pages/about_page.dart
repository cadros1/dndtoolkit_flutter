import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = "";
  String _buildNumber = "";
  bool _isChecking = false;

  // GitHub 仓库地址
  final String _repoUrl = "https://github.com/cadros1/dndtoolkit_flutter";
  // GitHub API 地址
  final String _apiUrl = "https://api.github.com/repos/cadros1/dndtoolkit_flutter/releases/latest";

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  /// 检查更新
  Future<void> _checkUpdate() async {
    setState(() => _isChecking = true);

    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String tagName = data['tag_name'] ?? ""; // 例如 "v1.0.1"
        final String htmlUrl = data['html_url'] ?? _repoUrl;
        final String body = data['body'] ?? "没有更新说明";

        // 处理版本号对比：移除 'v' 前缀
        final cleanTagName = tagName.replaceAll('v', '');
        
        // 简单对比：如果 tag 与当前 version 不一致，且 tag 不为空，则认为有更新
        // (更严谨的做法是使用 pub_semver 库进行语义化版本对比，这里简化处理)
        if (cleanTagName.isNotEmpty && cleanTagName != _version) {
          _showUpdateDialog(tagName, body, htmlUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("当前已是最新版本")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("检查失败: ${response.statusCode}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("检查出错，请检查网络: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  /// 显示发现更新对话框
  void _showUpdateDialog(String version, String desc, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("发现新版本 $version"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("更新内容：", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(desc),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("稍后"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(url);
            },
            child: const Text("前往下载"),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("无法打开浏览器")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("关于"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          // App 图标 (Flutter Logo 占位)
          const Center(
            child: FlutterLogo(size: 80),
          ),
          const SizedBox(height: 20),
          // App 名称
          const Center(
            child: Text(
              "DnD Toolkit",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          // 版本号
          Center(
            child: Text(
              "版本: v$_version (Build $_buildNumber)",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 40),
          
          // 检查更新按钮
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text("检查更新"),
            subtitle: const Text("从GitHub Release"),
            trailing: _isChecking 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _isChecking ? null : _checkUpdate,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
          ),
          
          const SizedBox(height: 10),
          
          // 项目主页
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text("项目主页"),
            subtitle: Text(_repoUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _launchUrl(_repoUrl),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
          ),
          
          const SizedBox(height: 40),
          const Center(
            child: Text(
              "Designed for D&D 5E Players",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}