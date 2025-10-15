# Bug Fix: Onboarding Crash After Review

## Issue
The app was crashing after clicking "review" in the onboarding flow with the following errors:
1. Layout overflow: "A RenderFlex overflowed by 49 pixels on the bottom" in `onboarding_interstitial.dart`
2. Semantics error: "Failed assertion: '!semantics.parentDataDirty': is not true"
3. Video initialization error (non-critical)

## Root Cause
The `OnboardingInterstitial` widget had two issues:
1. **Layout Overflow**: Column with too much content for smaller screens, causing a RenderFlex overflow of 49 pixels
2. **Semantics Error**: Using a `Spacer()` widget inside a `SingleChildScrollView` caused rendering assertion failures

Both issues were causing the app to crash when navigating to the privacy interstitial page after the review prompt.

## Solution
Fixed both the layout overflow and semantics error:

### Changes Made
**File**: `lib/widgets/onboarding_interstitial.dart`

- Changed `Container` to `SizedBox` for better performance and linter compliance
- Wrapped the Column in a `SingleChildScrollView` with `BouncingScrollPhysics`
- Added a `ConstrainedBox` to ensure the content fills the available space while being scrollable
- **Removed `Spacer()` widget** (which doesn't work inside scroll views) and replaced it with a `SizedBox` with responsive height
- This prevents overflow on any screen size while maintaining the visual design and fixing semantics errors

### Video Error (Not Critical)
The video initialization error for `assets/onboarding/videos/recording_to_note.mp4` is non-critical because:
- The onboarding screen already has proper error handling for missing videos
- If the video fails to load, it displays a placeholder with a mic icon
- The error is caught and logged but doesn't block the user flow

## Testing
To verify the fix:
1. Run the app and complete the onboarding flow
2. Click "review" when prompted
3. Verify the privacy interstitial page displays without crashing
4. Test on smaller screen sizes to ensure content is scrollable

## Status
✅ Fixed - The onboarding flow should now complete without crashes on all screen sizes.

