# Build and Run Instructions

## Prerequisites
- Xcode 14.0 or later
- iOS 16.0+ deployment target
- SwissEphemeris package already added

## Build Steps

1. **Open the project in Xcode**
   ```bash
   open kairo.xcodeproj
   ```

2. **Select your target device**
   - Choose a simulator (e.g., iPhone 15 Pro)
   - Or connect a physical device

3. **Build and Run**
   - Press `Cmd + R` or click the Play button
   - The app should compile and launch

## What to Expect

### First Launch
1. Launch screen with constellation animation
2. Onboarding flow:
   - Welcome screen
   - Astrology explanation
   - Notification permissions
   - Birth data input

### Main App
1. **Today Tab**: Daily horoscope based on current transits
2. **Birth Chart Tab**: Your calculated birth chart with planets
3. **Chat Tab**: Oracle-style interface (placeholder for now)
4. **Profile Tab**: View and edit your birth details

## Troubleshooting

### If you get build errors:

1. **SwissEphemeris not found**
   - Go to File → Add Package Dependencies
   - Re-add the package from: https://github.com/vsmithers1087/SwissEphemeris

2. **Type errors with Planet or HouseCusps**
   - Make sure you're using SwissEphemeris version 0.0.99 or compatible
   - Check that all imports are correct

3. **Runtime crashes**
   - Check console for error messages
   - Verify birth data is being saved correctly
   - Ensure location permissions are granted for geocoding

## Testing the Astrology Calculations

1. Go through onboarding and enter your birth details
2. Check the Birth Chart tab - it should show:
   - Accurate planetary positions
   - Your Sun, Moon, and Rising signs
   - House cusps

3. Check the Today tab - it should show:
   - Current planetary transits
   - Personalized daily insight

## Next Steps

Once everything is working:
1. Test with different birth dates and locations
2. Verify calculations against other astrology apps
3. Consider adding more features from the todo list