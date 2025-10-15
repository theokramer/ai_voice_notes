# Legal Documents Integration Guide

This guide explains where and how to integrate your Privacy Policy and Terms of Service in Notie AI for App Store compliance.

## 📋 Required Locations

### 1. ✅ **Settings Screen** (ALREADY ADDED)

**Location:** `lib/screens/settings_screen.dart`

**What was added:**
- New "Legal" section in Settings
- "Privacy Policy" tile
- "Terms of Service" tile
- Both open in external browser when tapped

**Action Required:**
Replace the placeholder URLs in `settings_screen.dart`:
```dart
Line 1361: const url = 'https://your-website.com/privacy-policy';
Line 1375: const url = 'https://your-website.com/terms-of-service';
```

Replace with your actual URLs where you'll host the HTML files.

---

### 2. 🔴 **Onboarding Flow** (NEEDS TO BE ADDED)

Apple prefers users to see and accept terms during onboarding.

**Option A: Privacy Interstitial (Recommended)**
Add a "I agree to Privacy Policy and Terms of Service" to your existing privacy page.

**Location:** `lib/screens/onboarding_screen.dart` around line 1500-1600 (privacy interstitial section)

Add this after the privacy description:

```dart
// In the privacy interstitial page, add:
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text(
      'By continuing, you agree to our ',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppTheme.textSecondary,
      ),
    ),
    GestureDetector(
      onTap: () => _openUrl('https://your-website.com/privacy-policy'),
      child: Text(
        'Privacy Policy',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: themeConfig.primaryColor,
          decoration: TextDecoration.underline,
        ),
      ),
    ),
    Text(' and ', style: Theme.of(context).textTheme.bodySmall),
    GestureDetector(
      onTap: () => _openUrl('https://your-website.com/terms-of-service'),
      child: Text(
        'Terms of Service',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: themeConfig.primaryColor,
          decoration: TextDecoration.underline,
        ),
      ),
    ),
  ],
),
```

And add this helper method:
```dart
void _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

---

### 3. 🔴 **Paywall/Subscription Screen** (NEEDS TO BE ADDED)

When showing the paywall/purchase screen, you MUST include links to these documents.

**Location:** Wherever Superwall is configured or custom paywall screen

**Add footer text:**
```dart
Padding(
  padding: const EdgeInsets.all(16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      GestureDetector(
        onTap: () => _openUrl('https://your-website.com/privacy-policy'),
        child: Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
      Text(' • ', style: TextStyle(color: Colors.grey)),
      GestureDetector(
        onTap: () => _openUrl('https://your-website.com/terms-of-service'),
        child: Text(
          'Terms of Service',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    ],
  ),
),
```

---

### 4. 🔴 **App Store Listing** (MANUAL ENTRY)

**Where:** App Store Connect → Your App → App Information

**Fields to fill:**
1. **Privacy Policy URL:** `https://your-website.com/privacy-policy`
2. **Terms of Service URL:** `https://your-website.com/terms-of-service` (optional but recommended)

**Steps:**
1. Log into App Store Connect
2. Go to My Apps → Notie AI
3. Click on "App Information" in left sidebar
4. Scroll to "General Information"
5. Add Privacy Policy URL (REQUIRED)
6. Add Terms of Service URL (optional)
7. Click Save

---

### 5. 🔴 **Support Website/Marketing Site** (RECOMMENDED)

If you have a website for your app, add footer links:

```html
<footer>
  <a href="https://your-website.com/privacy-policy">Privacy Policy</a>
  <a href="https://your-website.com/terms-of-service">Terms of Service</a>
  <a href="https://your-website.com/support">Support</a>
</footer>
```

---

## 🌐 Hosting the Documents

### Option 1: Google Sites (Easiest)
1. Create a new Google Site
2. Add a page for Privacy Policy
3. Add a page for Terms of Service  
4. Paste the HTML content from the files I created
5. Publish and get the URLs

**Example URLs:**
- `https://sites.google.com/view/notie-ai-privacy`
- `https://sites.google.com/view/notie-ai-terms`

### Option 2: Your Own Website
If you have your own domain:
- `https://notie-ai.com/privacy-policy.html`
- `https://notie-ai.com/terms-of-service.html`

### Option 3: GitHub Pages (Free)
1. Create a GitHub repository
2. Upload PRIVACY_POLICY.html and TERMS_OF_SERVICE.html
3. Enable GitHub Pages in repository settings
4. URLs will be like:
   - `https://your-username.github.io/notie-ai-legal/privacy-policy.html`
   - `https://your-username.github.io/notie-ai-legal/terms-of-service.html`

---

## 📝 Update Checklist

Before submitting to App Store:

- [ ] Host Privacy Policy and Terms of Service online
- [ ] Update URLs in `settings_screen.dart` (lines 1361 and 1375)
- [ ] Add legal links to onboarding privacy page
- [ ] Add legal links to paywall/subscription screen
- [ ] Add Privacy Policy URL in App Store Connect
- [ ] Test all links work correctly
- [ ] Verify links open in Safari (not in-app)
- [ ] Update contact email placeholders in legal documents

---

## 🚨 Critical Notes

### For App Store Approval:

1. **Privacy Policy is REQUIRED** - Apple will reject without it
2. **Must be accessible without account** - Links in Settings work for this
3. **Must be current/accurate** - Update if you change data practices
4. **Must load properly** - Test URLs before submission

### Apple's Requirements:

- Privacy Policy must describe:
  - ✅ What data you collect (audio, notes, device info)
  - ✅ How you use it (transcription, AI features)
  - ✅ Who you share it with (OpenAI, Superwall, RevenueCat)
  - ✅ How users can delete their data
  - ✅ Contact information

All of this is already covered in the Privacy Policy I created! ✅

---

## 🔧 Testing

Before submitting:

1. **Open Settings** → scroll to "Legal" section
2. **Tap Privacy Policy** → should open in Safari
3. **Tap Terms of Service** → should open in Safari
4. **Check onboarding flow** → legal links should be visible
5. **Check paywall** → legal footer should be present
6. **Verify URLs** → make sure they're your actual URLs, not placeholders

---

## 📱 Required iOS Configuration

For URL launching to work, you need to configure iOS:

**File:** `ios/Runner/Info.plist`

Add this before `</dict>`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>https</string>
    <string>http</string>
</array>
```

This allows the app to open web URLs in Safari.

---

## 💡 Pro Tips

1. **Keep PDFs as backup** - Convert your HTML to PDF and store locally
2. **Version control** - Keep dated versions of your legal docs
3. **Update regularly** - Review annually or when you change features
4. **Translations** - If you support multiple languages, translate legal docs
5. **Easy to find** - Users should always be able to access these quickly

---

## 📞 Need Help?

If you have questions about legal requirements:
- **Apple:** [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Privacy:** [Apple Privacy Requirements](https://developer.apple.com/app-store/review/guidelines/#privacy)
- **Legal advice:** Consult with a lawyer for your specific situation

---

**Last Updated:** October 15, 2025  
**App Version:** 1.0.0

