import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StepInputCard extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const StepInputCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = -999, // 允许负数（如先攻）
    this.max = 9999,
  });

  @override
  State<StepInputCard> createState() => _StepInputCardState();
}

class _StepInputCardState extends State<StepInputCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant StepInputCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果父组件传入的值变了，且不是当前输入框正在输入的内容，则更新输入框
    // 这里的逻辑是为了防止光标跳动，但对于按钮点击触发的变更，必须强制更新
    if (widget.value != oldWidget.value) {
      final textVal = int.tryParse(_controller.text) ?? widget.value;
      if (textVal != widget.value) {
        _controller.text = widget.value.toString();
        // 保持光标在末尾
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateValue(int newValue) {
    if (newValue >= widget.min && newValue <= widget.max) {
      widget.onChanged(newValue);
      // 注意：这里不需要手动 set text，因为 onChanged 会导致父组件 setState，
      // 进而触发 didUpdateWidget 更新 text
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero, // 由外部控制间距
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 减号
                _buildBtn(Icons.remove, () => _updateValue(widget.value - 1)),
                
                // 输入框
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                    ],
                    onChanged: (v) {
                      final val = int.tryParse(v);
                      if (val != null) {
                        widget.onChanged(val);
                      }
                    },
                  ),
                ),
                
                // 加号
                _buildBtn(Icons.add, () => _updateValue(widget.value + 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.blue),
      ),
    );
  }
}