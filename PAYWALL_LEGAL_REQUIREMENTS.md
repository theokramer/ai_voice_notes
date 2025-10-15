# Paywall Legal Requirements - Quick Reference

## ✅ What's Already Done

### 1. Settings Screen
- ✅ Added "Legal" section with Privacy Policy and Terms links
- ✅ URLs updated to your Google Sites:
  - Privacy: `https://sites.google.com/view/notieai/privacy-policy`
  - Terms: `https://sites.google.com/view/notieai/terms-of-service`

### 2. Onboarding Privacy Page
- ✅ Added legal footer with clickable links
- ✅ Shows "By continuing, you agree to our Privacy Policy and Terms of Service"
- ✅ Links open in Safari (external browser)

### 3. Reusable Widgets Created
- ✅ `lib/widgets/legal_footer.dart` - Full legal footer
- ✅ `CompactLegalFooter` - Compact version for tight spaces

---

## 🔴 What You Still Need to Do

### 1. **Superwall Paywall Configuration** (REQUIRED)

Since you're using Superwall's hosted paywalls, you MUST add legal links in the Superwall Dashboard:

#### Steps:
1. **Log into [Superwall Dashboard](https://superwall.com)**
2. **Go to Paywalls** → Select your paywall templates
3. **Edit each paywall** (both `onboarding_hard_paywall` and `app_launch_paywall`)
4. **Add a text element at the bottom** with links:

```
By subscribing, you agree to our Privacy Policy and Terms of Service
```

5. **Make text clickable:**
   - Highlight "Privacy Policy"
   - Add link: `https://sites.google.com/view/notieai/privacy-policy`
   - Highlight "Terms of Service"
   - Add link: `https://sites.google.com/view/notieai/terms-of-service`

6. **Style the text:**
   - Small font (10-12px)
   - Gray color (#999999)
   - Center aligned
   - Place at bottom with padding

#### Example Footer Layout in Superwall:
```
┌─────────────────────────────────────────┐
│                                         │
│  [Your Paywall Content]                 │
│  [Pricing Options]                      │
│  [Subscribe Button]                     │
│                                         │
│  By subscribing, you agree to our       │
│  Privacy Policy and Terms of Service    │
│                                         │
└─────────────────────────────────────────┘
```

---

### 2. **App Store Connect** (REQUIRED)

Add your Privacy Policy URL to App Store Connect:

1. **Log into [App Store Connect](https://appstoreconnect.apple.com)**
2. **Go to:** My Apps → Notie AI → App Information
3. **Scroll to:** General Information section
4. **Add Privacy Policy URL:** `https://sites.google.com/view/notieai/privacy-policy`
5. **Click Save**

This is REQUIRED by Apple - they will reject your app without it.

---

### 3. **Install Dependencies** (REQUIRED)

Run this command to add the `url_launcher` package:

```bash
flutter pub get
```

The package has already been added to `pubspec.yaml`.

---

### 4. **Test Everything** (REQUIRED)

Before submitting to App Store:

**Settings Screen:**
- [ ] Open app → Settings
- [ ] Tap "Privacy Policy" → Opens in Safari
- [ ] Tap "Terms of Service" → Opens in Safari
- [ ] Verify pages load correctly

**Onboarding:**
- [ ] Go through onboarding flow
- [ ] On privacy page, verify legal footer appears
- [ ] Tap Privacy Policy link → Opens in Safari
- [ ] Tap Terms of Service link → Opens in Safari

**Paywalls:**
- [ ] Trigger first paywall (onboarding)
- [ ] Verify legal footer visible at bottom
- [ ] Links should open in Safari
- [ ] Trigger second paywall (if applicable)
- [ ] Verify legal footer visible

---

## 📋 Apple App Store Requirements

### What Apple Checks:
1. ✅ Privacy Policy is accessible from within the app
2. ✅ Privacy Policy describes data collection
3. ✅ Privacy Policy URL in App Store Connect
4. ✅ Legal links on all purchase screens
5. ✅ Links actually work and load properly

### What They'll Reject For:
- ❌ No Privacy Policy link in Settings
- ❌ No legal links on paywall/purchase screens
- ❌ Broken links (404 errors)
- ❌ No Privacy Policy URL in App Store Connect
- ❌ Privacy Policy doesn't match actual data practices

---

## 🎯 Quick Checklist

Before App Store submission:

- [ ] Superwall paywalls have legal footer
- [ ] Settings screen has legal links
- [ ] Onboarding privacy page has legal footer
- [ ] All links open in Safari (not in-app browser)
- [ ] All links load correctly (no 404)
- [ ] Privacy Policy URL added to App Store Connect
- [ ] Tested on physical device
- [ ] `flutter pub get` completed successfully

---

## 🆘 Troubleshooting

### Links Don't Open
**Issue:** Tapping links does nothing

**Solution:** Make sure you ran `flutter pub get` after adding `url_launcher` to `pubspec.yaml`

### Links Open In-App Instead of Safari
**Issue:** Links open inside app instead of Safari

**Solution:** Check that `LaunchMode.externalApplication` is used (already implemented)

### Superwall Links Not Clickable
**Issue:** Legal footer text in Superwall isn't clickable

**Solution:** In Superwall dashboard, you need to:
1. Add the text as a separate text element
2. Use Superwall's rich text editor
3. Manually make each link clickable
4. Or add two separate text elements with tap actions

---

## 💡 Pro Tips

1. **Keep URLs consistent** - Use the same URLs everywhere
2. **Test on real device** - Simulator might behave differently
3. **Screenshot for App Review** - If rejected, you can show Apple the screenshots
4. **Update regularly** - Review legal docs annually
5. **Monitor analytics** - Check how many users tap legal links (most don't!)

---

## 📞 Need Help?

If Apple rejects your app for privacy policy issues:

1. **Check rejection reason** - Apple usually specifies exactly what's missing
2. **Send screenshots** - Show Apple where your legal links are
3. **Update Superwall** - Most rejections are because paywall doesn't have links
4. **Verify all links work** - Test from multiple devices

---

**Your URLs:**
- Privacy Policy: https://sites.google.com/view/notieai/privacy-policy
- Terms of Service: https://sites.google.com/view/notieai/terms-of-service

**Last Updated:** October 15, 2025

