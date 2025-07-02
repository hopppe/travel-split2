# EquiSplit Universal Links Website

This repository contains the web files for EquiSplit's Universal Links functionality. When users share invite links, this website handles the deep linking logic.

## How it works

1. **User shares a link**: `https://equisplit.ingenuitylabs.net/join/ABC123`
2. **User with app installed**: Link opens the EquiSplit app directly
3. **User without app**: Link shows a web page with App Store download link

## File Structure

```
├── apple-app-site-association    # Apple's configuration file for Universal Links
├── index.html                   # Main landing page
├── join/
│   └── index.html              # Handles invite links and app detection
├── vercel.json                 # Vercel deployment configuration
└── app-icon.png               # App icon for web pages (you need to add this)
```

## Setup Instructions

1. **Deploy to Vercel**:
   - Create a new repository with these files
   - Connect it to Vercel
   - Set up custom domain: `equisplit.ingenuitylabs.net`

2. **Add App Icon**:
   - Add your app icon as `app-icon.png` (recommended size: 512x512px)

3. **Update Team ID**:
   - In `apple-app-site-association`, replace `TEAMID` with your actual Apple Developer Team ID
   - Find this in your Apple Developer account

4. **Test Universal Links**:
   - After deployment, test the link: `https://equisplit.ingenuitylabs.net/join/TEST123`
   - Should show the join page and attempt to open your app

## Important Notes

- The `apple-app-site-association` file must be served from the root domain without a file extension
- Universal Links only work on real devices, not simulators
- Make sure your app's entitlements include the correct domain
- Test both scenarios: with app installed and without app installed

## Domain Setup

Make sure your domain `equisplit.ingenuitylabs.net` is properly configured:
1. DNS points to Vercel
2. SSL certificate is active
3. The `apple-app-site-association` file is accessible at: `https://equisplit.ingenuitylabs.net/apple-app-site-association` 