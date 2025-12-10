import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/character.dart';

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

  /// 从相册选择图片并转换为 Base64
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600, // 限制图片大小，防止Base64字符串过长导致卡顿
        imageQuality: 80,
      );

      if (image != null) {
        final Uint8List bytes = await image.readAsBytes();
        final String base64String = base64Encode(bytes);
        
        setState(() {
          _profile.portraitBase64 = base64String;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
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
      padding: const EdgeInsets.all(16.0),
      children: [
        // --- 1. 角色画像 ---
        _buildSectionTitle("角色画像"),
        const SizedBox(height: 10),
        Center(child: _buildPortraitArea()),
        const SizedBox(height: 24),

        // --- 2. 外貌特征 ---
        _buildSectionTitle("外貌特征"),
        const SizedBox(height: 8),
        _buildAppearanceGrid(),
        
        const Divider(height: 40),

        // --- 3. 个性特征 ---
        _buildSectionTitle("个性特征"),
        const SizedBox(height: 8),
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

        const Divider(height: 40),

        // --- 4. 背景与经历 ---
        _buildSectionTitle("设定"),
        const SizedBox(height: 8),
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
          lines: 10, // 大文本框
        ),

        const SizedBox(height: 50),
      ],
    );
  }

  // --- 辅助组件 ---

  /// 构建画像区域
  Widget _buildPortraitArea() {
    Uint8List? imageBytes;
    if (_profile.portraitBase64.isNotEmpty) {
      try {
        imageBytes = base64Decode(_profile.portraitBase64);
      } catch (e) {
        print("Base64 decode error: $e");
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade400, width: 2),
              image: imageBytes != null
                  ? DecorationImage(
                      image: MemoryImage(imageBytes),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageBytes == null
                ? const Icon(Icons.add_a_photo, size: 50, color: Colors.grey)
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text("选择图片"),
            ),
            if (imageBytes != null) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: _clearImage,
                child: const Text("清除", style: TextStyle(color: Colors.red)),
              )
            ]
          ],
        )
      ],
    );
  }

  /// 构建外貌网格
  Widget _buildAppearanceGrid() {
    return Card(
      elevation: 0, // 扁平化风格
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildSmallTextField("年龄", _profile.age, (v) => _profile.age = v)),
                const SizedBox(width: 10),
                Expanded(child: _buildSmallTextField("身高", _profile.height, (v) => _profile.height = v)),
                const SizedBox(width: 10),
                Expanded(child: _buildSmallTextField("体重", _profile.weight, (v) => _profile.weight = v)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildSmallTextField("眼睛", _profile.eyes, (v) => _profile.eyes = v)),
                const SizedBox(width: 10),
                Expanded(child: _buildSmallTextField("皮肤", _profile.skin, (v) => _profile.skin = v)),
                const SizedBox(width: 10),
                Expanded(child: _buildSmallTextField("头发", _profile.hair, (v) => _profile.hair = v)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  /// 小文本框（用于外貌）
  Widget _buildSmallTextField(String label, String initialValue, Function(String) onChanged) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
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
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      onChanged: onChanged,
    );
  }
}