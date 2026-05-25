# Info.plist and Xcode Capability Notes

This source bundle does not include a complete Xcode project file. When creating the real iOS app target, add the appropriate privacy strings and capabilities.

## Calendar / EventKit

The app exports exact-time planned items to Apple Calendar using EventKit.

Recommended privacy key for iOS 17+ write-only event access:

```xml
<key>NSCalendarsWriteOnlyAccessUsageDescription</key>
<string>Magnet Board uses Calendar access only when you choose to export an exact plan item to Apple Calendar.</string>
```

For older OS targets or fallback EventKit access, also consider:

```xml
<key>NSCalendarsUsageDescription</key>
<string>Magnet Board uses Calendar access only when you choose to export an exact plan item to Apple Calendar.</string>
```

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
