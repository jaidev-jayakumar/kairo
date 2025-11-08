# kaira - App Store Submission Checklist

**Status:** Ready for submission after completing items marked with 🔴

---

## ✅ COMPLETED

### 1. ✅ API Keys Secured

- APIKeys.plist is in .gitignore
- Keys never committed to git
- App works without exposed credentials

### 2. ✅ Privacy Policy Created

- Located at: `PRIVACY_POLICY.md`
- **ACTION REQUIRED:** Update email address `[your-email@example.com]`
- **ACTION REQUIRED:** Host online and add URL to App Store Connect

### 3. ✅ Terms of Service Created

- Located at: `TERMS_OF_SERVICE.md`
- **ACTION REQUIRED:** Update email address and jurisdiction

### 4. ✅ Info.plist Configured

- Location permission: ✅ Added
- Microphone permission: ✅ Added (for future voice features)
- Speech recognition permission: ✅ Added (for future voice features)
- All permissions use casual, human language

### 5. ✅ Build Configuration

- Version: **1.0** ✅
- Build number: **1** ✅
- Bundle ID: **com.github.jaidev-jayakumar.kairo** ✅
- Development Team: **M27AX84WTG** ✅
- Code signing: Automatic ✅

### 6. ✅ Debug Code

- Print statements present but harmless
- No test code in production paths
- `TestAstrologyView.swift` exists but unused

### 7. ✅ App Store Listing Content

- Description, keywords, and all text prepared
- Located at: `APP_STORE_LISTING.md`

---

## 🔴 CRITICAL - MUST COMPLETE

### 1. 🔴 App Icon (BLOCKER)

**Status:** Missing - App cannot be submitted without this

**What you need:**

- 1024x1024px PNG image (no transparency)
- Cosmic/astrological theme
- Matches app's red/coral color scheme

**How to add:**

1. Create or design your icon
2. Open Xcode → kairo project
3. Assets.xcassets → AppIcon
4. Drag 1024x1024px image into "iOS App Store" slot

**Design suggestions:**

- Crescent moon with stars
- Zodiac wheel
- Constellation pattern
- Cosmic gradient with symbols
- Consider using Figma, Canva, or hiring a designer on Fiverr ($10-50)

### 2. 🔴 Screenshots (REQUIRED)

**Status:** Need to create

**Requirements:**

- Minimum 3 screenshots per device size
- Need at least 2 device sizes (recommend 6.9" and 6.1")

**Recommended screenshots:**

1. Today View (daily insights + scores)
2. Cycles View (active transits)
3. Birth Chart Display
4. Weekly Forecast
5. Onboarding screen

**How to capture:**

```bash
# Run app in simulator
# cmd + S to save screenshot
# Screenshots saved to Desktop by default

# For different sizes, change simulator:
# iPhone 16 Pro Max (6.9")
# iPhone 16 Pro (6.1")
```

**Tools to add text/polish:**

- [screenshots.pro](https://screenshots.pro) (free)
- Figma (free)
- Apple's own Screenshot Creator in App Store Connect

### 3. 🔴 Host Privacy Policy

**Status:** File created, needs hosting

**Options:**

**A. GitHub Pages (Easiest, Free)**

```bash
# 1. Enable GitHub Pages in repo settings
# 2. Your privacy policy will be at:
#    https://[your-username].github.io/kairo/PRIVACY_POLICY
```

**B. Convert to HTML & host anywhere**

```bash
# Install markdown converter
brew install pandoc

# Convert to HTML
pandoc PRIVACY_POLICY.md -o privacy.html --standalone

# Host on Vercel/Netlify/Render (all free)
```

**C. Quick HTML wrapper**

- Open PRIVACY_POLICY.md
- Copy content
- Use https://markdowntohtml.com/
- Host resulting HTML file

### 4. 🔴 Update Email Addresses

**Files to update:**

- `PRIVACY_POLICY.md` (line with `[your-email@example.com]`)
- `TERMS_OF_SERVICE.md` (line with `[your-email@example.com]`)
- `APP_STORE_LISTING.md` (replace GitHub username)

---

## 🟡 RECOMMENDED (Before Launch)

### 1. 🟡 Test on Real Device

**Why:** Simulator doesn't catch all issues

**How:**

1. Connect iPhone via USB
2. In Xcode, select your iPhone as the destination
3. Press Run (cmd + R)
4. Test key flows:
   - Onboarding
   - Date selection in Today view
   - Switching between tabs
   - Weekly/Monthly views
   - Birth data input

**Common real-device issues to check:**

- Location permission prompt appears correctly
- Fonts render properly
- Performance (should be smooth)
- Landscape mode (if you support it)

### 2. 🟡 Add App Store Connect Account

**Steps:**

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Sign in with your Apple ID
3. If you don't have a developer account:
   - Enroll at [developer.apple.com](https://developer.apple.com/programs/)
   - Cost: $99/year
   - Takes 24-48 hours to activate

### 3. 🟡 Create App in App Store Connect

1. Log into App Store Connect
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - Platform: iOS
   - Name: kaira
   - Primary Language: English
   - Bundle ID: com.github.jaidev-jayakumar.kairo
   - SKU: kairo-001 (or any unique identifier)
4. Follow prompts to complete setup

---

## 🟢 OPTIONAL (Can Add Later)

### 1. 🟢 Local Notifications

**Feature:** Daily horoscope reminders

**Benefits:**

- Re-engagement
- Better user experience
- No server/cost required (local notifications are free)

**Implementation later if desired:**

- Would take ~2-3 hours to implement
- Requires notification permission (UI already requests this)
- Can be added in v1.1 update

### 2. 🟢 App Preview Video

**Optional but helpful:**

- 15-30 second video showing app features
- Can significantly improve conversion
- Not required for submission

### 3. 🟢 TestFlight Beta

**Before public launch:**

- Upload build to TestFlight
- Invite 5-10 friends to test
- Catch bugs before public sees them
- Free, built into App Store Connect

---

## 📋 SUBMISSION PROCESS (Once Above Complete)

### Step 1: Archive Build

```bash
# In Xcode:
# 1. Select "Any iOS Device (arm64)" as destination
# 2. Product → Archive
# 3. Wait for archive to complete (~5 min)
```

### Step 2: Upload to App Store Connect

```bash
# In Xcode Organizer (opens after archive):
# 1. Select your archive
# 2. Click "Distribute App"
# 3. Choose "App Store Connect"
# 4. Follow prompts
# 5. Upload (~5-10 min)
```

### Step 3: Complete App Store Connect Listing

1. Add screenshots for all device sizes
2. Paste description from `APP_STORE_LISTING.md`
3. Add keywords
4. Add privacy policy URL
5. Set pricing (free for now)
6. Choose categories (Lifestyle, Entertainment)
7. Set age rating (4+)

### Step 4: Submit for Review

1. Select your uploaded build
2. Answer export compliance questions (No encryption = easier)
3. Click "Submit for Review"

### Step 5: Wait for Review

- **Timeline:** 24-48 hours typically
- **Possible outcomes:**
  - ✅ Approved → App goes live!
  - ⚠️ Metadata Rejected → Fix description/screenshots, resubmit (no new build needed)
  - ❌ Binary Rejected → Fix code issue, upload new build
- Check App Store Connect daily for status updates

---

## 🚨 COMMON REJECTION REASONS (We've Avoided)

✅ **Exposed API keys** → Fixed (in .gitignore)  
✅ **Missing privacy policy** → Created  
✅ **Missing location permission description** → Added  
✅ **Placeholder content** → All real content  
✅ **Broken features** → All features work offline  
✅ **No value to users** → Clear astrology functionality  
✅ **Misleading description** → Honest about what app does

---

## 📊 CURRENT STATUS

| Task                    | Status                | Blocker? |
| ----------------------- | --------------------- | -------- |
| API Keys                | ✅ Done               | No       |
| Privacy Policy          | ✅ Done               | No       |
| Terms of Service        | ✅ Done               | No       |
| Info.plist Config       | ✅ Done               | No       |
| Build Settings          | ✅ Done               | No       |
| **App Icon**            | 🔴 **Missing**        | **YES**  |
| **Screenshots**         | 🔴 **Need to create** | **YES**  |
| **Host Privacy Policy** | 🔴 **Not hosted**     | **YES**  |
| Test on Device          | 🟡 Recommended        | No       |
| App Store Listing       | ✅ Content ready      | No       |
| Local Notifications     | 🟢 Optional           | No       |

---

## 🎯 ESTIMATED TIME TO LAUNCH

**If you have an icon ready:**

- Complete remaining tasks: **2-3 hours**
- Upload and submit: **1 hour**
- Apple review: **24-48 hours**
- **Total:** 3-5 days

**If you need to create icon:**

- Design icon: **2-4 hours** (or $20-50 to hire)
- Complete remaining tasks: **2-3 hours**
- Upload and submit: **1 hour**
- Apple review: **24-48 hours**
- **Total:** 5-7 days

---

## 💡 HELPFUL RESOURCES

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Guide](https://developer.apple.com/testflight/)

---

## ✉️ NEED HELP?

Common issues and solutions:

**Q: "I don't have an Apple Developer account"**
A: Sign up at developer.apple.com ($99/year, required to publish)

**Q: "I'm not a designer, how do I make an icon?"**
A: Options:

1. Use Canva's app icon templates (free)
2. Hire on Fiverr ($10-50, 24-48 hours)
3. Use AI tools like Midjourney or DALL-E
4. Use free icon generators online

**Q: "Do I really need all those screenshot sizes?"**
A: Minimum is 2 device sizes. Apple will show your 6.9" screenshots on smaller devices if you don't provide all sizes.

**Q: "What if Apple rejects my app?"**
A: Common reasons are fixable:

- They'll tell you exactly what's wrong
- Most rejections are metadata/description issues (easy fix)
- Binary rejections need code changes but are rare if you followed this checklist

---

**You're closer than you think! The core app is solid. Just need icon, screenshots, and hosting. You've got this! 🚀**
