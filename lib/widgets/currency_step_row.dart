import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CurrencyStepRow extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const CurrencyStepRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<CurrencyStepRow> createState() => _CurrencyStepRowState();
}

class _CurrencyStepRowState extends State<CurrencyStepRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant CurrencyStepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当外部（父组件）传入的值发生变化，且和当前输入框内容不一致时，更新输入框
    // 这样可以确保点击加减按钮时输入框内容能同步，同时保证手动输入时光标不跳动
    if (widget.value != oldWidget.value) {
      final textVal = int.tryParse(_controller.text) ?? widget.value;
      if (textVal != widget.value) {
        _controller.text = widget.value.toString();
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
    if (newValue >= 0) { // 钱币不允许为负数
      widget.onChanged(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children:[
          // 左侧：钱币缩写 (CP, SP, etc.)
          SizedBox(
            width: 40,
            child: Text(
              widget.label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.amber, // 使用琥珀色符合金币的直觉
              ),
            ),
          ),
          
          const Spacer(), // 撑开中间空间
          
          // 右侧：减号 - 输入框 - 加号
          Row(
            mainAxisSize: MainAxisSize.min,
            children:[
              // 减号按钮
              _buildBtn(Icons.remove, () => _updateValue(widget.value - 1)),
              
              // 文本输入框
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters:[
                    FilteringTextInputFormatter.digitsOnly, // 仅允许正整数输入
                  ],
                  onChanged: (v) {
                    if (v.isEmpty) {
                      widget.onChanged(0); // 清空时默认设为0
                    } else {
                      final val = int.tryParse(v);
                      if (val != null) widget.onChanged(val);
                    }
                  },
                ),
              ),

              // 加号按钮
              _buildBtn(Icons.add, () => _updateValue(widget.value + 1)),
            ],
          ),
        ],
      ),
    );
  }

  // 辅助方法：构建圆角加减小按钮
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