import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import '../services/haptic_service.dart';

class TagEditor extends StatefulWidget {
  final List<String> tags;
  final Function(List<String>) onTagsChanged;
  final bool showSuggestions;

  const TagEditor({
    super.key,
    required this.tags,
    required this.onTagsChanged,
    this.showSuggestions = true,
  });

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!widget.showSuggestions) return;

    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    // Get all tags from notes provider
    final notesProvider = context.read<NotesProvider>();
    final allTags = notesProvider.getAllTags();

    // Filter suggestions
    final suggestions = allTags
        .where((tag) => 
            tag.toLowerCase().contains(text.toLowerCase()) &&
            !widget.tags.contains(tag))
        .take(5)
        .toList();

    setState(() {
      _suggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim().toLowerCase();
    if (trimmedTag.isEmpty || widget.tags.contains(trimmedTag)) {
      return;
    }

    HapticService.light();
    
    final newTags = [...widget.tags, trimmedTag];
    widget.onTagsChanged(newTags);
    
    _controller.clear();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
  }

  void _removeTag(String tag) {
    HapticService.light();
    
    final newTags = widget.tags.where((t) => t != tag).toList();
    widget.onTagsChanged(newTags);
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _addTag(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tag chips
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.tags.map((tag) => _TagChip(
              tag: tag,
              onDeleted: () => _removeTag(tag),
              onTap: () {
                // Search for this tag
                // This will be handled by the parent screen
              },
            )).toList(),
          ),
        
        const SizedBox(height: 8),

        // Input field
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Add tag...',
            prefixIcon: const Icon(Icons.tag, size: 20),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: _handleSubmit,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => _handleSubmit(),
        ),

        // Suggestions
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggestions',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _suggestions.map((tag) => ActionChip(
                    label: Text(tag),
                    onPressed: () => _addTag(tag),
                    avatar: const Icon(Icons.add, size: 16),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onDeleted;
  final VoidCallback? onTap;

  const _TagChip({
    required this.tag,
    required this.onDeleted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(tag),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      visualDensity: VisualDensity.compact,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      labelStyle: TextStyle(
        color: Theme.of(context).primaryColor,
        fontSize: 13,
      ),
    );
  }
}

/// Simple tag display widget (non-editable)
class TagDisplay extends StatelessWidget {
  final List<String> tags;
  final Function(String)? onTagTap;
  final int maxDisplay;

  const TagDisplay({
    super.key,
    required this.tags,
    this.onTagTap,
    this.maxDisplay = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final displayTags = tags.take(maxDisplay).toList();
    final remaining = tags.length - displayTags.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...displayTags.map((tag) => GestureDetector(
          onTap: onTagTap != null ? () => onTagTap!(tag) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tag,
                  size: 12,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  tag,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        )),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+$remaining',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// Tag filter bar for searching
class TagFilterBar extends StatelessWidget {
  final List<String> selectedTags;
  final Function(String) onTagToggle;
  final VoidCallback onClear;

  const TagFilterBar({
    super.key,
    required this.selectedTags,
    required this.onTagToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedTags.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 18,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedTags.map((tag) => FilterChip(
                label: Text(tag),
                selected: true,
                onSelected: (_) => onTagToggle(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => onTagToggle(tag),
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.clear_all, size: 20),
            onPressed: onClear,
            tooltip: 'Clear filters',
          ),
        ],
      ),
    );
  }
}

