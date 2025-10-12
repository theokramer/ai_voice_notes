# Security Guidelines for Nota AI

## ⚠️ Critical Security Information

### API Key Management

**Current Implementation:**
- API keys (OpenAI, Superwall) are stored in a `.env` file
- The `.env` file is loaded at app startup using `flutter_dotenv`
- **WARNING**: In the current setup, API keys are bundled with the app and can be extracted by determined users

### Security Risks

1. **API Key Exposure**: The `.env` file is compiled into the app bundle. While Flutter obfuscates the code, the keys can still be extracted through:
   - Decompilation of the app binary
   - Inspection of app resources
   - Memory dumps during runtime

2. **Potential Abuse**: Exposed API keys could lead to:
   - Unauthorized API usage
   - Unexpected costs from OpenAI API calls
   - Abuse of your Superwall account

### Current Mitigation (Development/MVP)

For development and early releases, the current setup is acceptable with these precautions:

1. **Monitor API Usage**: 
   - Set up billing alerts in OpenAI Dashboard
   - Monitor Superwall analytics for unusual activity
   - Set rate limits on API keys if possible

2. **Rotate Keys Regularly**:
   - Generate new API keys periodically
   - Revoke old keys after rotation
   - Update app with new keys

3. **Development vs Production Keys**:
   - Use separate API keys for development and production
   - Never commit production keys to version control
   - Keep production keys in a secure location

### Recommended Production Solution

For a production-ready, secure implementation, consider:

#### Option 1: Backend Proxy (Recommended)
```
iOS App → Your Backend Server → OpenAI API
                              → Superwall API
```

**Benefits:**
- API keys never leave your server
- You can implement rate limiting per user
- You can add authentication/authorization
- You can monitor and log all API calls
- You can switch providers without app updates

**Implementation:**
1. Create a simple backend (Node.js, Python, etc.)
2. Store API keys as environment variables on the server
3. Expose authenticated endpoints for your app
4. Update app to call your backend instead of APIs directly

#### Option 2: Firebase Cloud Functions

Use Firebase to host serverless functions that proxy API calls:

```dart
// Instead of direct API calls
final response = await http.post(
  'https://your-region-your-project.cloudfunctions.net/transcribe',
  headers: {'Authorization': 'Bearer $userToken'},
  body: audioFile,
);
```

### `.env` File Security

**DO:**
- ✅ Keep `.env` in `.gitignore`
- ✅ Use different keys for dev and production
- ✅ Document required environment variables
- ✅ Set up monitoring and alerts
- ✅ Rotate keys regularly

**DON'T:**
- ❌ Commit `.env` to version control
- ❌ Share production keys in team chats
- ❌ Use production keys during development
- ❌ Leave default/placeholder keys in production builds

### User Data Protection

1. **Local Storage**:
   - User notes are stored locally using `shared_preferences`
   - No notes are sent to external servers (only audio is sent to OpenAI for transcription)
   - Consider encrypting sensitive data at rest

2. **Audio Recording**:
   - Audio files are temporarily stored for transcription
   - Files should be deleted after successful transcription
   - Consider adding user preference for audio retention

3. **Privacy Policy**:
   - Clearly state what data is collected
   - Explain how OpenAI processes audio (transcription only)
   - Detail data retention and deletion policies

### iOS App Store Requirements

1. **Privacy Manifest** (if required):
   - Declare API tracking domains
   - Specify data collection practices

2. **App Store Privacy Labels**:
   - Audio recording: Required for core functionality
   - Data usage: Transcription processing (not retained by OpenAI)

3. **Encryption Export Compliance**:
   - If you implement encryption, you may need to submit compliance documentation

### Audit Checklist

Before production release:

- [ ] Review all API key locations
- [ ] Set up API usage monitoring
- [ ] Configure billing alerts
- [ ] Test with production API keys
- [ ] Verify `.env` is in `.gitignore`
- [ ] Document key rotation process
- [ ] Consider backend proxy implementation
- [ ] Update privacy policy
- [ ] Test rate limiting behavior
- [ ] Review App Store security requirements

### Getting Help

If you experience:
- Unexpected API charges
- Suspicious activity
- Key exposure

**Immediate Actions:**
1. Revoke compromised API keys immediately
2. Generate new keys
3. Monitor for unusual activity
4. Consider implementing backend proxy

## Additional Resources

- [OpenAI API Best Practices](https://platform.openai.com/docs/guides/safety-best-practices)
- [Flutter Security Guidelines](https://docs.flutter.dev/security)
- [App Store Review Guidelines - Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)

---

**Last Updated**: December 2024
**Version**: 1.0.0

