import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/character.dart';
import '../../widgets/app_ui.dart';

class CharacterSettingsTab extends StatefulWidget {
  final Character character;

  const CharacterSettingsTab({super.key, required this.character});

  @override
  State<CharacterSettingsTab> createState() => _CharacterSettingsTabState();
}

class _CharacterSettingsTabState extends State<CharacterSettingsTab> {
  // 便捷访问器
  Profile get _profile => widget.character.profile;
  Roleplay get _rp => widget.character.roleplay;

  final ImagePicker _picker = ImagePicker();

  /// 画像 + 外貌 —— 桌面端左右排列，移动端上下堆叠
  Widget _buildPortraitAndAppearance() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 500) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    const AppSectionTitle(
                      title: "角色画像",
                      icon: Icons.portrait_outlined,
                    ),
                    AppPanel(child: _buildPortraitArea()),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    const AppSectionTitle(
                      title: "外貌特征",
                      icon: Icons.face_retouching_natural_outlined,
                    ),
                    _buildAppearanceGrid(),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            const AppSectionTitle(title: "角色画像", icon: Icons.portrait_outlined),
            AppPanel(child: Center(child: _buildPortraitArea())),
            const SizedBox(height: 24),
            const AppSectionTitle(
              title: "外貌特征",
              icon: Icons.face_retouching_natural_outlined,
            ),
            _buildAppearanceGrid(),
          ],
        );
      },
    );
  }

  /// 从相册选择图片并转换为 Base64
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600, // 限制图片大小，防止Base64字符串过长导致卡顿
        imageQuality: 80,
      );

      if (!mounted) return;

      if (image != null) {
        final Uint8List bytes = await image.readAsBytes();
        if (!mounted) return;

        final String base64String = base64Encode(bytes);

        setState(() {
          _profile.portraitBase64 = base64String;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    }
  }

  /// 清除图片
  void _clearImage() {
    setState(() {
      _profile.portraitBase64 = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // 画像 + 外貌 —— 桌面端左右排列
        _buildPortraitAndAppearance(),

        const SizedBox(height: 18),

        // --- 3. 个性特征 ---
        const AppSectionTitle(
          title: "个性特征",
          subtitle: "用于快速回忆角色动机和扮演线索",
          icon: Icons.psychology_alt_outlined,
        ),
        AppPanel(
          child: Column(
            children: [
              _buildTextArea(
                label: "个性",
                initialValue: _rp.personalityTraits,
                onChanged: (v) => _rp.personalityTraits = v,
                lines: 3,
              ),
              const SizedBox(height: 12),
              _buildTextArea(
                label: "理想",
                initialValue: _rp.ideals,
                onChanged: (v) => _rp.ideals = v,
                lines: 2,
              ),
              const SizedBox(height: 12),
              _buildTextArea(
                label: "纽带",
                initialValue: _rp.bonds,
                onChanged: (v) => _rp.bonds = v,
                lines: 2,
              ),
              const SizedBox(height: 12),
              _buildTextArea(
                label: "缺陷",
                initialValue: _rp.flaws,
                onChanged: (v) => _rp.flaws = v,
                lines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // --- 4. 背景与经历 ---
        const AppSectionTitle(title: "设定", icon: Icons.menu_book_outlined),
        AppPanel(
          child: Column(
            children: [
              _buildTextArea(
                label: "盟友与组织",
                initialValue: _rp.alliesAndOrganizations,
                onChanged: (v) => _rp.alliesAndOrganizations = v,
                lines: 4,
              ),
              const SizedBox(height: 12),
              _buildTextArea(
                label: "所持物",
                initialValue: _rp.treasure,
                onChanged: (v) => _rp.treasure = v,
                lines: 4,
              ),
              const SizedBox(height: 12),
              _buildTextArea(
                label: "附加特征",
                initialValue: _rp.additionalFeaturesAndTraits,
                onChanged: (v) => _rp.additionalFeaturesAndTraits = v,
                lines: 4,
              ),
              const SizedBox(height: 12),
              _buildTextArea(
                label: "角色经历",
                initialValue: _rp.characterExperience,
                onChanged: (v) => _rp.characterExperience = v,
                lines: 4,
              ),
              const SizedBox(height: 12),
              _buildTextArea(
                label: "背景故事",
                initialValue: _rp.characterBackstory,
                onChanged: (v) => _rp.characterBackstory = v,
                lines: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 辅助组件 ---

  /// 构建画像区域
  Widget _buildPortraitArea() {
    final cs = Theme.of(context).colorScheme;
    Uint8List? imageBytes;
    final hasPortraitData = _profile.portraitBase64.isNotEmpty;
    if (hasPortraitData) {
      try {
        imageBytes = base64Decode(_profile.portraitBase64);
      } catch (_) {
        imageBytes = null;
      }
    }
    final hasBrokenPortrait = hasPortraitData && imageBytes == null;

    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.32),
                width: 2,
              ),
              image: imageBytes != null
                  ? DecorationImage(
                      image: MemoryImage(imageBytes),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageBytes == null
                ? Icon(
                    hasBrokenPortrait
                        ? Icons.broken_image_outlined
                        : Icons.add_a_photo_outlined,
                    size: 48,
                    color: hasBrokenPortrait ? cs.error : cs.primary,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text("选择图片"),
            ),
            if (imageBytes != null || hasBrokenPortrait) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: _clearImage,
                child: Text(
                  hasBrokenPortrait ? "清除损坏画像" : "清除",
                  style: TextStyle(color: cs.error),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 构建外貌网格
  Widget _buildAppearanceGrid() {
    final fields = [
      _buildSmallTextField("年龄", _profile.age, (v) => _profile.age = v),
      _buildSmallTextField("身高", _profile.height, (v) => _profile.height = v),
      _buildSmallTextField("体重", _profile.weight, (v) => _profile.weight = v),
      _buildSmallTextField("眼睛", _profile.eyes, (v) => _profile.eyes = v),
      _buildSmallTextField("皮肤", _profile.skin, (v) => _profile.skin = v),
      _buildSmallTextField("头发", _profile.hair, (v) => _profile.hair = v),
    ];
    return AppPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 520
              ? 3
              : constraints.maxWidth >= 360
              ? 2
              : 1;
          const spacing = 10.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: fields
                .map((field) => SizedBox(width: width, child: field))
                .toList(),
          );
        },
      ),
    );
  }

  /// 小文本框（用于外貌）
  Widget _buildSmallTextField(
    String label,
    String initialValue,
    Function(String) onChanged,
  ) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }

  /// 多行文本区域
  Widget _buildTextArea({
    required String label,
    required String initialValue,
    required Function(String) onChanged,
    int lines = 3,
    String? hint,
  }) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
      ),
      onChanged: onChanged,
    );
  }
}
