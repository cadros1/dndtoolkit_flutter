import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 法术位步进器 —— 单行加减控件，显示"当前值 / 最大值"格式，归零时红色警示
class SpellSlotStepRow extends StatefulWidget {
  final int level; // 法术环位 (1-9)
  final int current; // 当前剩余数
  final int max; // 总数上限
  final ValueChanged<int> onCurrentChanged;
  final ValueChanged<int>? onMaxChanged; // 预留：未来可在此行直接编辑上限

  const SpellSlotStepRow({
    super.key,
    required this.level,
    required this.current,
    required this.max,
    required this.onCurrentChanged,
    this.onMaxChanged,
  });

  String get label => '$level环';

  @override
  State<SpellSlotStepRow> createState() => _SpellSlotStepRowState();
}

class _SpellSlotStepRowState extends State<SpellSlotStepRow> {
  late TextEditingController _currentController;

  @override
  void initState() {
    super.initState();
    _currentController = TextEditingController(text: widget.current.toString());
  }

  // 当父组件外部改变值时，同步控制器内容，避免光标跳动
  @override
  void didUpdateWidget(covariant SpellSlotStepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current != oldWidget.current) {
      final textVal = int.tryParse(_currentController.text) ?? widget.current;
      if (textVal != widget.current) {
        _currentController.text = widget.current.toString();
        _currentController.selection = TextSelection.fromPosition(
          TextPosition(offset: _currentController.text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    super.dispose();
  }

  void _updateCurrent(int newValue) {
    if (newValue >= 0) {
      widget.onCurrentChanged(newValue);
    }
  }

  // 步进器布局：[标签] ...[减号 输入框/上限 加号]
  @override
  Widget build(BuildContext context) {
    final isZero = widget.current == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isZero ? Colors.red : Colors.grey.shade700,
              ),
            ),
          ),

          const Spacer(),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBtn(Icons.remove, () => _updateCurrent(widget.current - 1)),

              SizedBox(
                width: 45,
                child: TextField(
                  controller: _currentController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isZero ? Colors.red : Colors.black,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (v) {
                    if (v.isEmpty) {
                      widget.onCurrentChanged(0);
                    } else {
                      final val = int.tryParse(v);
                      if (val != null) widget.onCurrentChanged(val);
                    }
                  },
                ),
              ),

              Text(
                ' / ${widget.max}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),

              _buildBtn(Icons.add, () => _updateCurrent(widget.current + 1)),
            ],
          ),
        ],
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
        child: Icon(icon, size: 20),
      ),
    );
  }
}
