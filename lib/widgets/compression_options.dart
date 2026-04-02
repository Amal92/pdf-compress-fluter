import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/models.dart';

class CompressionOptions extends StatefulWidget {
  final int originalSize;
  final void Function(String type, CompressionSettings settings) onCompress;
  final bool isProcessing;
  final bool hideButton;
  final bool hideSizeInfo;
  final void Function(String type, CompressionSettings settings)? onSettingsChange;

  const CompressionOptions({
    super.key,
    required this.originalSize,
    required this.onCompress,
    this.isProcessing = false,
    this.hideButton = false,
    this.hideSizeInfo = false,
    this.onSettingsChange,
  });

  @override
  State<CompressionOptions> createState() => _CompressionOptionsState();
}

class _CompressionOptionsState extends State<CompressionOptions> {
  String _mode = 'simple';
  CompressionLevel _level = CompressionLevel.balanced;
  final _targetCtrl = TextEditingController();
  String _unit = 'MB';
  String? _targetError;

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  void _notifySettingsChange() {
    final cb = widget.onSettingsChange;
    if (cb == null) return;
    if (_mode == 'simple') {
      cb('simple', CompressionSettings(type: 'simple', level: _level));
    } else {
      final val = double.tryParse(_targetCtrl.text);
      if (val != null && val > 0) {
        final mb = _unit == 'MB' ? val : val / 1000;
        cb(
          'target',
          CompressionSettings(
            type: 'target',
            targetSizeMb: mb,
            targetDisplayValue: val,
            targetDisplayUnit: _unit,
          ),
        );
      }
    }
  }

  String? _validateTargetSize(String value, String unit) {
    final val = double.tryParse(value);
    if (value.isEmpty || val == null) return null;
    if (val <= 0) return 'Target size must be greater than zero.';
    if (widget.originalSize > 0) {
      final targetBytes = unit == 'MB' ? val * 1024 * 1024 : val * 1024;
      if (targetBytes >= widget.originalSize) {
        final origMb = widget.originalSize / (1024 * 1024);
        final origDisplay = origMb < 1
            ? '${(origMb * 1000).toStringAsFixed(0)} KB'
            : '${origMb.toStringAsFixed(2)} MB';
        return 'Target must be smaller than the original ($origDisplay).';
      }
    }
    return null;
  }

  bool get _isValid {
    if (_mode == 'simple') return true;
    final val = double.tryParse(_targetCtrl.text);
    if (val == null || val <= 0) return false;
    if (_targetError != null) return false;
    return true;
  }

  void _handleCompress() {
    if (_mode == 'simple') {
      widget.onCompress(
        'simple',
        CompressionSettings(type: 'simple', level: _level),
      );
    } else {
      final val = double.parse(_targetCtrl.text);
      final mb = _unit == 'MB' ? val : val / 1000;
      widget.onCompress(
        'target',
        CompressionSettings(
          type: 'target',
          targetSizeMb: mb,
          targetDisplayValue: val,
          targetDisplayUnit: _unit,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode tab switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _ModeTab(
                  label: 'Quick Compress',
                  selected: _mode == 'simple',
                  onTap: () => setState(() {
                    _mode = 'simple';
                    _notifySettingsChange();
                  }),
                ),
                _ModeTab(
                  label: 'Target Size',
                  selected: _mode == 'target',
                  onTap: () => setState(() {
                    _mode = 'target';
                    _notifySettingsChange();
                  }),
                ),
              ],
            ),
          ),

          if (!widget.hideSizeInfo) ...[
            const SizedBox(height: 14),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'Current size: '),
                  TextSpan(
                    text: _formatSize(widget.originalSize),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          if (_mode == 'simple') _buildSimpleMode(),
          if (_mode == 'target') _buildTargetMode(),

          if (!widget.hideButton) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (!_isValid || widget.isProcessing) ? null : _handleCompress,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primaryDisabled,
                ),
                child: widget.isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Compress PDF',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleMode() {
    final levels = [
      (CompressionLevel.light, 'Light', 'Higher quality, larger file'),
      (CompressionLevel.balanced, 'Balanced', 'Good balance between quality and size'),
      (CompressionLevel.strong, 'Strong', 'Smallest file, lower quality'),
    ];

    return Column(
      children: levels.map((entry) {
        final (value, label, desc) = entry;
        final selected = _level == value;
        return GestureDetector(
          onTap: () => setState(() {
            _level = value;
            _notifySettingsChange();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Custom radio
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTargetMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Target Size',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  hintText: 'Enter size',
                  errorText: _targetError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _targetError != null
                          ? AppColors.error
                          : AppColors.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _targetError != null
                          ? AppColors.error
                          : AppColors.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _targetError != null
                          ? AppColors.error
                          : AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (v) {
                  setState(() {
                    _targetError = _validateTargetSize(v, _unit);
                  });
                  _notifySettingsChange();
                },
              ),
            ),
            const SizedBox(width: 8),
            // Unit selector
            _UnitSelector(
              selected: _unit,
              onChanged: (unit) {
                setState(() {
                  _unit = unit;
                  _targetError =
                      _validateTargetSize(_targetCtrl.text, unit);
                });
                _notifySettingsChange();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.amberLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.amberBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Setting a very small target size may significantly reduce image quality.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.amberText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    final kb = bytes / 1024;
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(2)} MB';
    return '${kb.toStringAsFixed(0)} KB';
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _UnitSelector extends StatefulWidget {
  final String selected;
  final void Function(String) onChanged;

  const _UnitSelector({required this.selected, required this.onChanged});

  @override
  State<_UnitSelector> createState() => _UnitSelectorState();
}

class _UnitSelectorState extends State<_UnitSelector> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.selected,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: ['KB', 'MB'].map((unit) {
                final isSel = unit == widget.selected;
                return GestureDetector(
                  onTap: () {
                    setState(() => _open = false);
                    widget.onChanged(unit);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        if (isSel)
                          const Icon(Icons.check, size: 14, color: AppColors.primary)
                        else
                          const SizedBox(width: 14),
                        const SizedBox(width: 6),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSel ? FontWeight.w600 : FontWeight.w400,
                            color: isSel
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
