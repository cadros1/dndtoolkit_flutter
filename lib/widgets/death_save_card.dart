import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_ui.dart';

class DeathSaveCard extends StatelessWidget {
  final int successes;
  final int failures;
  final int? lastRoll;
  final bool isDesktop;
  final VoidCallback onRoll;
  final VoidCallback onReset;
  final ValueChanged<int> onSuccessesChanged;
  final ValueChanged<int> onFailuresChanged;

  const DeathSaveCard({
    super.key,
    required this.successes,
    required this.failures,
    required this.lastRoll,
    required this.isDesktop,
    required this.onRoll,
    required this.onReset,
    required this.onSuccessesChanged,
    required this.onFailuresChanged,
  });

  bool get _isStable => successes >= 3;
  bool get _isDead => failures >= 3;
  bool get _isTerminal => _isStable || _isDead;
  bool get _hasState => successes > 0 || failures > 0 || lastRoll != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppPanel(
      key: const ValueKey('death-save-card'),
      padding: isDesktop
          ? const EdgeInsets.all(18)
          : const EdgeInsets.fromLTRB(8, 12, 8, 12),
      shadowAlpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.1,
      shadowBlur: 26,
      shadowOffset: const Offset(0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.heart_broken_outlined, color: cs.primary, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '死亡豁免',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '当前生命值为 0',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final useStackedProgress =
                  constraints.maxWidth < 334 || textScale > 1.25;

              if (useStackedProgress) {
                return Column(
                  children: [
                    _buildOutcome(context),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildSuccessProgress(context)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFailureProgress(context)),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSuccessProgress(context)),
                  _buildOutcome(context),
                  Expanded(child: _buildFailureProgress(context)),
                ],
              );
            },
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          _buildLastResult(context),
          SizedBox(height: isDesktop ? 16 : 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final stackActions =
                  constraints.maxWidth < 300 || textScale > 1.3;
              final rollButton = SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const ValueKey('death-save-roll-button'),
                  onPressed: _isTerminal ? null : onRoll,
                  icon: const Icon(Icons.casino_outlined),
                  label: Text(
                    _isStable
                        ? '伤势稳定'
                        : _isDead
                        ? '角色死亡'
                        : '死亡豁免检定',
                  ),
                ),
              );
              final resetButton = SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  key: const ValueKey('death-save-reset-button'),
                  onPressed: _hasState ? onReset : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重置'),
                ),
              );

              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    rollButton,
                    const SizedBox(height: 8),
                    resetButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: rollButton),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: resetButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessProgress(BuildContext context) {
    return _DeathSaveProgress(
      label: '成功',
      count: successes,
      accent: AppTheme.successFor(Theme.of(context).brightness),
      enabled: !_isDead,
      indices: const [1, 2, 3],
      onChanged: onSuccessesChanged,
    );
  }

  Widget _buildFailureProgress(BuildContext context) {
    return _DeathSaveProgress(
      label: '失败',
      count: failures,
      accent: Theme.of(context).colorScheme.error,
      enabled: !_isStable,
      indices: const [3, 2, 1],
      onChanged: onFailuresChanged,
    );
  }

  Widget _buildOutcome(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _isStable
        ? AppTheme.successFor(Theme.of(context).brightness)
        : _isDead
        ? cs.error
        : cs.outline;
    final label = _isStable
        ? '稳定'
        : _isDead
        ? '死亡'
        : '未决';
    final icon = _isStable
        ? Icons.health_and_safety_outlined
        : _isDead
        ? Icons.dangerous_outlined
        : null;

    return Semantics(
      liveRegion: true,
      excludeSemantics: true,
      label: '死亡豁免最终结果：$label',
      child: AnimatedContainer(
        key: const ValueKey('death-save-outcome'),
        duration: const Duration(milliseconds: 180),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(
            alpha: _isTerminal
                ? Theme.of(context).brightness == Brightness.dark
                      ? 0.2
                      : 0.1
                : 0.04,
          ),
          border: Border.all(
            color: accent.withValues(alpha: _isTerminal ? 0.75 : 0.45),
            width: _isTerminal ? 2 : 1.5,
          ),
        ),
        child: icon == null
            ? const SizedBox.shrink()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: accent, size: 28),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLastResult(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCriticalSuccess = lastRoll == 20;
    final isCriticalFailure = lastRoll == 1;
    final accent = isCriticalSuccess
        ? AppTheme.successFor(Theme.of(context).brightness)
        : isCriticalFailure
        ? cs.error
        : cs.primary;
    final semanticResult = lastRoll == null
        ? '尚未进行死亡豁免检定'
        : isCriticalSuccess
        ? '死亡豁免骰面 20，自然 20'
        : isCriticalFailure
        ? '死亡豁免骰面 1，自然 1'
        : '死亡豁免骰面 $lastRoll';

    return Semantics(
      liveRegion: true,
      excludeSemantics: true,
      label: semanticResult,
      child: AnimatedContainer(
        key: const ValueKey('death-save-last-result'),
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 62),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark
                ? 0.14
                : 0.07,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(
              alpha: isCriticalSuccess || isCriticalFailure ? 0.8 : 0.28,
            ),
            width: isCriticalSuccess || isCriticalFailure ? 2 : 1,
          ),
        ),
        child: Text(
          lastRoll?.toString() ?? '—',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: lastRoll == null ? cs.onSurfaceVariant : accent,
            fontWeight: FontWeight.w900,
            fontSize: isCriticalSuccess || isCriticalFailure ? 34 : 30,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _DeathSaveProgress extends StatelessWidget {
  final String label;
  final int count;
  final Color accent;
  final bool enabled;
  final List<int> indices;
  final ValueChanged<int> onChanged;

  const _DeathSaveProgress({
    required this.label,
    required this.count,
    required this.accent,
    required this.enabled,
    required this.indices,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final index in indices)
              _DeathSaveCircle(
                groupLabel: label,
                index: index,
                selected: count >= index,
                accent: accent,
                enabled: enabled,
                onPressed: () => onChanged(count >= index ? index - 1 : index),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$label $count/3',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: accent,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DeathSaveCircle extends StatelessWidget {
  final String groupLabel;
  final int index;
  final bool selected;
  final Color accent;
  final bool enabled;
  final VoidCallback onPressed;

  const _DeathSaveCircle({
    required this.groupLabel,
    required this.index,
    required this.selected,
    required this.accent,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stateText = selected ? '已记录' : '未记录';

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '死亡豁免$groupLabel第 $index 次，$stateText',
      hint: enabled
          ? selected
                ? '点击清除此格及之后的$groupLabel进度'
                : '点击记录到第 $index 次$groupLabel'
          : '请先撤回已完成的最终结果',
      child: SizedBox.square(
        dimension: 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('death-save-$groupLabel-$index'),
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : cs.surface,
                  border: Border.all(
                    color: selected ? accent : cs.outline,
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: 17, color: cs.surface)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
