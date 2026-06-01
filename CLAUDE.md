# posturapp — CLAUDE.md

macOS menu bar app that uses the camera + Apple Vision to monitor sitting posture and send funny alerts when bad posture is detected. Target: Mac App Store.

## Stack

- Swift + SwiftUI, macOS 13+, App Store sandbox
- `AVFoundation` — camera capture
- `Vision` — `VNDetectHumanBodyPoseRequest`, `VNHumanBodyPoseObservation`
- `Swift Charts` — statistics views
- `UserNotifications` — local notifications
- `MenuBarExtra` (.window style) — menu bar popover
- `ImageRenderer` — report card export to PNG

## Project structure

```
posturapp/
├── PostureApp.swift              @main, MenuBarExtra scene
├── AppState.swift                owns all managers, wires Combine pipeline
├── AppSettings.swift             singleton, UserDefaults-backed settings
├── CameraManager.swift           AVCaptureSession, publishes CGImage + forwards CMSampleBuffer
├── PoseDetector.swift            VNDetectHumanBodyPoseRequest, publishes joints dict
├── PostureAnalyzer.swift         heuristics + pro classifier, publishes PostureState
├── PostureStatsStore.swift       PostureEvent persistence, daily/weekly queries
├── PostureReport.swift           funny report copy, factory methods daily/weekly
├── NotificationManager.swift     UNUserNotificationCenter, funny copy pool, daily report at 18:00
├── AlertOverlayManager.swift     NSWindow at screenSaver level, spring animation + shake
├── SettingsWindowManager.swift   opens NSWindow with SwiftUI content, activation policy mgmt
├── Memes/                        meme1-6.png for notification attachments
└── Views/
    ├── MenuBarView.swift          camera + status + calibrate + on/off toggle + settings button
    ├── CameraView.swift           camera feed + skeleton overlay + pulsing red border
    ├── SkeletonOverlayView.swift  Canvas drawing joints and bones
    ├── AlertOverlayView.swift     full-screen alert card
    └── Settings/
        ├── SettingsWindowView.swift     TabView: General + Statistics
        ├── GeneralSettingsView.swift    calibration, pro calibration, sliders, toggles
        ├── StatisticsView.swift         Swift Charts + Posture Wrapped share section
        ├── ProCalibrationView.swift     wizard: camera preview + good/bad capture buttons
        └── ReportCardView.swift         shareable gradient card (exported via ImageRenderer)
```

## Data flow

```
AVCaptureSession
  ├── previewImage (CGImage) ──────────────────────→ CameraView
  └── CMSampleBuffer → PoseDetector (throttle 0.3s)
                           └── joints (published)
                                 ├── SkeletonOverlayView
                                 └── PostureAnalyzer
                                       ├── postureState → MenuBarView status + icon
                                       └── shouldAlert → NotificationManager + AlertOverlayManager
```

## Detection pipeline

### Subject selection (PoseDetector)
When multiple bodies are detected, `isHuman()` filters out objects/chairs by requiring:
- At least one face joint (nose/ear/eye) with confidence > 0.15
- Both shoulders detected
- Head geometrically above shoulders (Vision Y: 0=bottom, 1=top)
- Minimum 5 joints total

After filtering, selection priority:
- **With calibration anchor**: pick observation whose shoulder midX is closest to `subjectAnchorX`
- **Without anchor**: pick observation with most detected joints (closest person to camera wins)

### PostureAnalyzer modes

**Basic calibration** (`PostureBaseline`):
- User sits straight → captures earWidth, earShoulderGap, shoulderWidth, shoulderMidX
- Heuristics compare % deviation from baseline: lean forward, slouch, shoulder asymmetry
- `shoulderMidX` synced to `PoseDetector.subjectAnchorX` via Combine in AppState

**Pro calibration** (`ProCalibrationBaseline`):
- User records labeled examples: good posture (≥2) and bad posture (≥2), up to 10 each
- Feature vector (4D, normalized by shoulderWidth): earWidthRatio, earShoulderGapRatio, shoulderAsymmetryRatio, lateralLeanRatio
- Centroid classifier: euclidean distance to good vs bad centroid, 0.85 bias toward good
- **Pro takes priority over basic** in `analyze()`

## Critical Swift/Xcode gotchas

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26) — background-thread stored properties need `nonisolated(unsafe)`
- `CameraManager` and `PoseDetector` are `@unchecked Sendable`
- `@preconcurrency import Vision` required in PoseDetector and AppState
- Vision coordinate system: Y=0 is BOTTOM, Y=1 is TOP — flip for SwiftUI: `y = (1 - vision.y) * height`
- No camera mirroring — both feed and skeleton use raw Vision coordinates
- `PBXFileSystemSynchronizedRootGroup` (Xcode 16) — Swift files auto-discovered, no manual pbxproj edits needed
- `GENERATE_INFOPLIST_FILE = YES` — camera key set as `INFOPLIST_KEY_NSCameraUsageDescription`
- `LSUIElement = YES` (via `INFOPLIST_KEY_LSUIElement`) — no Dock icon
- Settings window needs `NSApp.setActivationPolicy(.regular)` to appear, `.accessory` on close

## Settings window environment

`SettingsWindowManager.open()` injects these environment objects:
```swift
.environmentObject(appState.cameraManager)
.environmentObject(appState.postureAnalyzer)
.environmentObject(appState.poseDetector)
.environmentObject(appState.statsStore)
.environmentObject(AppSettings.shared)
```
`ProCalibrationView` needs `cameraManager` + `poseDetector` + `postureAnalyzer`.

## AppSettings (UserDefaults-backed)

| Property | Default | Purpose |
|---|---|---|
| `alertThreshold` | 30s | Bad posture duration before alert |
| `alertCooldown` | 30s | Min time between consecutive alerts |
| `leanForwardTolerance` | 0.20 | % deviation to trigger lean forward |
| `slouchTolerance` | 0.25 | % deviation to trigger slouch |
| `showSkeleton` | true | Skeleton overlay in camera feed |
| `enableFullScreenOverlay` | true | AlertOverlayManager full-screen effect |
| `enableNotifications` | true | UNUserNotificationCenter alerts |

## PostureStatsStore

Persists `[PostureEvent]` as JSON in UserDefaults, pruned after 30 days.
Key queries: `dailyStats(forLast:)`, `todayHourlyBuckets()`, `todayScore()`, `longestGoodStreak()`, `totalBadToday()`.

## Posture Wrapped (report)

`PostureReport.daily/weekly(from: statsStore)` builds a funny report in 5 score tiers (≥85, 70-84, 50-69, 30-49, <30).
`ReportCardView` renders it as a gradient card, exported via `ImageRenderer` at 2x scale to a temp PNG.
Shared via `ShareLink(item: url)` or `NSPasteboard` (copy image).
Daily notification scheduled at 18:00 via `UNCalendarNotificationTrigger` when auth is granted.

## App Store checklist

- `com.apple.security.app-sandbox = true`
- `com.apple.security.device.camera = true`
- `ENABLE_HARDENED_RUNTIME = YES`
- Deployment target: macOS 13.0
- Privacy label: Camera (required, core functionality)
- No Dock icon: `LSUIElement = YES`
