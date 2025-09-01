# SwissEphemeris Setup Instructions

## Adding SwissEphemeris to your Xcode project:

1. Open your project in Xcode
2. Go to File → Add Package Dependencies...
3. In the search field, enter: `https://github.com/vsmithers1087/SwissEphemeris`
4. Click "Add Package"
5. Select version 2.0.0 or later
6. Add to target: kairo
7. Click "Add Package"

## Alternative: If the package doesn't work directly

We can use a simplified calculation approach first, then add the package later.

## Note:
The AstrologyService.swift file is ready but needs the SwissEphemeris import to be commented out until the package is added.