# Environment Variables Template

Copy this content to create your `.env` file:

```env
# OpenAI API Key for transcription and AI features
# Get your key from: https://platform.openai.com/api-keys
OPENAI_API_KEY=your_openai_api_key_here

# Superwall API Key for paywall management
# Get your key from: https://superwall.com/dashboard → Settings → Keys → Public API Key
SUPERWALL_API_KEY=your_superwall_api_key_here
```

## How to Set Up

1. Create a file named `.env` in the project root (same level as `pubspec.yaml`)
2. Copy the content above
3. Replace the placeholder values with your actual API keys
4. Save the file
5. Restart your app

## Security Notes

- ⚠️ **Never commit `.env` to version control**
- ⚠️ The `.env` file is already in `.gitignore`
- ⚠️ Keep your API keys secure and don't share them
- ⚠️ Use different keys for development and production

## Getting Your API Keys

### OpenAI API Key
1. Go to [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Sign in or create an account
3. Click "Create new secret key"
4. Copy the key (you won't be able to see it again!)
5. Add billing information if needed

### Superwall API Key
1. Go to [https://superwall.com/dashboard](https://superwall.com/dashboard)
2. Sign up or log in
3. Navigate to Settings → Keys
4. Copy your Public API Key
5. Paste it in your `.env` file

