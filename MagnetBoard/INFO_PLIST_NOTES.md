# Info.plist and Xcode Capability Notes

The iOS target merges `Config/MagnetBoard-Info.plist` into its generated Info.plist in Debug and Release.

## Calendar / EventKit

The app exports exact-time planned items to Apple Calendar using EventKit.

The first export requests write-only access. Updating an earlier export requires full access because EventKit must look up the saved event identifier. If the user declines the upgrade, the app leaves the earlier export alone.

The supplied plist declares both `NSCalendarsWriteOnlyAccessUsageDescription` and `NSCalendarsFullAccessUsageDescription`.

## Location / MapKit

Current code uses MapKit search and selected coordinates. It does not intentionally request live GPS location permission.

If future code asks for the user's current location, add:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Magnet Board uses your location only when you choose to search or plan around your current area.</string>
```

## Background modes

No background modes are currently required.

## Notifications

No notification permission is currently required.

## URL schemes / sharing

No custom URL scheme is currently required.

## Frameworks used

The Swift files import/use:

- SwiftUI
- Foundation
- MapKit
- CoreLocation
- EventKit
- UIKit

Xcode normally links these automatically when referenced, but check target settings if build errors appear.
