import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Reusable legal footer widget with Privacy Policy and Terms of Service links
/// Use this on any screen where users can make purchases or sign up
class LegalFooter extends StatelessWidget {
  final TextStyle? textStyle;
  final Color? linkColor;
  final double fontSize;

  const LegalFooter({
    super.key,
    this.textStyle,
    this.linkColor,
    this.fontSize = 12,
  });

  static const String privacyPolicyUrl = 'https://sites.google.com/view/notieai/privacy-policy';
  static const String termsOfServiceUrl = 'https://sites.google.com/view/notieai/terms-of-service';

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = TextStyle(
      fontSize: fontSize,
      color: AppTheme.textTertiary,
      height: 1.4,
    );
    
    final effectiveTextStyle = textStyle ?? defaultTextStyle;
    final effectiveLinkColor = linkColor ?? AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'By continuing, you agree to our ',
            style: effectiveTextStyle,
            textAlign: TextAlign.center,
          ),
          GestureDetector(
            onTap: () => _openUrl(privacyPolicyUrl),
            child: Text(
              'Privacy Policy',
              style: effectiveTextStyle.copyWith(
                color: effectiveLinkColor,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            ' and ',
            style: effectiveTextStyle,
          ),
          GestureDetector(
            onTap: () => _openUrl(termsOfServiceUrl),
            child: Text(
              'Terms of Service',
              style: effectiveTextStyle.copyWith(
                color: effectiveLinkColor,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '.',
            style: effectiveTextStyle,
          ),
        ],
      ),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      debugPrint('Could not launch $url');
    }
  }
}

/// Compact version for tight spaces (like bottom of paywalls)
class CompactLegalFooter extends StatelessWidget {
  final Color? textColor;
  final Color? linkColor;

  const CompactLegalFooter({
    super.key,
    this.textColor,
    this.linkColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _openUrl(LegalFooter.privacyPolicyUrl),
          child: Text(
            'Privacy Policy',
            style: TextStyle(
              fontSize: 11,
              color: linkColor ?? Colors.grey.shade400,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '•',
            style: TextStyle(
              fontSize: 11,
              color: textColor ?? Colors.grey.shade500,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _openUrl(LegalFooter.termsOfServiceUrl),
          child: Text(
            'Terms of Service',
            style: TextStyle(
              fontSize: 11,
              color: linkColor ?? Colors.grey.shade400,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      debugPrint('Could not launch $url');
    }
  }
}

