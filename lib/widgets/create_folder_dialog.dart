import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';

class CreateFolderDialog extends StatefulWidget {
  const CreateFolderDialog({super.key});

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final _nameController = TextEditingController();
  String _selectedIcon = '📁';
  Color? _selectedColor;

  // Common folder icons
  final List<String> _folderIcons = [
    '📁', '📂', '📚', '📝', '💼', '🎯', '🏠', '💡', '🎨', '🎵',
    '📊', '🔧', '🎮', '✈️', '🍎', '💪', '🧘', '🛒', '💰', '🎓',
  ];

  // Preset colors
  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleCreate() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    HapticService.success();
    
    // Build result map with nullable colorHex
    final result = <String, String?>{
      'name': name,
      'icon': _selectedIcon,
      'colorHex': _selectedColor?.value.toRadixString(16).padLeft(8, '0'),
    };
    
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: const Color(0xEE1A1F2E), // 93% opacity dark blue-grey
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              border: Border.all(
                color: AppTheme.glassBorder.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Folder',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Folder name input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Folder Name',
                hintText: 'e.g., Work, Personal, Books',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _handleCreate(),
            ),
            const SizedBox(height: 24),

                    // Icon picker
                    const Text(
                      'Icon',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _folderIcons.length,
                itemBuilder: (context, index) {
                  final icon = _folderIcons[index];
                  final isSelected = icon == _selectedIcon;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIcon = icon;
                      });
                      HapticService.light();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          icon,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

                    // Color picker (optional)
                    const Text(
                      'Color (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // None option
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColor = null;
                    });
                    HapticService.light();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedColor == null
                            ? Theme.of(context).primaryColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _selectedColor == null
                        ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                        : const Icon(Icons.close, color: Colors.grey),
                  ),
                ),
                // Color options
                ..._colors.map((color) {
                  final isSelected = _selectedColor == color;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                      HapticService.light();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }),
                    ],
                  ),
                ],
              ),
            ),
          ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        HapticService.light();
                        Navigator.of(context).pop();
                      },
                      child: Text(LocalizationService().t('cancel')),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _handleCreate,
                      child: Text(LocalizationService().t('create')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

