import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Beautiful read-only summary display widget with rich formatting
/// Parses structured summary with [SECTION] markers and renders them beautifully
class SummaryDisplay extends StatelessWidget {
  final String? summary;
  final bool isLoading;
  final VoidCallback? onGenerateSummary;
  final Color accentColor;

  const SummaryDisplay({
    super.key,
    required this.summary,
    this.isLoading = false,
    this.onGenerateSummary,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Generating summary...',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will take a few seconds',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (summary == null || summary!.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 64,
                color: AppTheme.textTertiary.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'No Summary Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Summaries are generated automatically\nwhen you create a note',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textTertiary,
                  height: 1.5,
                ),
              ),
              if (onGenerateSummary != null) ...[
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onGenerateSummary,
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text('Generate Summary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Parse and display summary
    final sections = _parseSummary(summary!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections.map((section) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildSection(section, accentColor),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Parse summary into sections
  List<SummarySection> _parseSummary(String summary) {
    final sections = <SummarySection>[];
    final lines = summary.split('\n');
    
    SummarySection? currentSection;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      if (trimmedLine.isEmpty) continue;
      
      // Check for section markers
      if (trimmedLine.startsWith('[') && trimmedLine.endsWith(']')) {
        // Save previous section
        if (currentSection != null) {
          sections.add(currentSection);
        }
        
        // Start new section
        final sectionName = trimmedLine.substring(1, trimmedLine.length - 1);
        currentSection = SummarySection(
          type: _getSectionType(sectionName),
          title: _formatSectionTitle(sectionName),
          content: [],
        );
      } else if (currentSection != null) {
        // Add content to current section
        currentSection.content.add(trimmedLine);
      }
    }
    
    // Add last section
    if (currentSection != null) {
      sections.add(currentSection);
    }
    
    return sections;
  }

  SectionType _getSectionType(String sectionName) {
    final name = sectionName.toUpperCase();
    if (name.contains('MAIN') || name.contains('TOPIC')) return SectionType.mainTopic;
    if (name.contains('KEY') || name.contains('POINT')) return SectionType.keyPoints;
    if (name.contains('ACTION') || name.contains('ITEM')) return SectionType.actionItems;
    if (name.contains('CONTEXT')) return SectionType.context;
    return SectionType.other;
  }

  String _formatSectionTitle(String sectionName) {
    // Convert MAIN_TOPIC to "Main Topic"
    return sectionName
        .split('_')
        .map((word) => word.isEmpty 
            ? '' 
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Widget _buildSection(SummarySection section, Color accentColor) {
    switch (section.type) {
      case SectionType.mainTopic:
        return _buildMainTopicSection(section, accentColor);
      case SectionType.keyPoints:
        return _buildKeyPointsSection(section, accentColor);
      case SectionType.actionItems:
        return _buildActionItemsSection(section, accentColor);
      case SectionType.context:
        return _buildContextSection(section, accentColor);
      case SectionType.other:
        return _buildOtherSection(section, accentColor);
    }
  }

  Widget _buildMainTopicSection(SummarySection section, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.15),
            accentColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.stars,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            section.content.join(' '),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyPointsSection(SummarySection section, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb,
                  color: Colors.blueAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueAccent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...section.content.map((point) {
            final text = point.startsWith('-') ? point.substring(1).trim() : point;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildActionItemsSection(SummarySection section, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.shade800.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.orangeAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.orangeAccent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...section.content.map((item) {
            final text = item.startsWith('-') ? item.substring(1).trim() : item;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.orangeAccent,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildContextSection(SummarySection section, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade800.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade700.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            section.content.join(' '),
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherSection(SummarySection section, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            section.content.join('\n'),
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class SummarySection {
  final SectionType type;
  final String title;
  final List<String> content;

  SummarySection({
    required this.type,
    required this.title,
    required this.content,
  });
}

enum SectionType {
  mainTopic,
  keyPoints,
  actionItems,
  context,
  other,
}

