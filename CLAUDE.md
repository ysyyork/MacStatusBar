# Claude Code Guidelines for MacStatusBar

## Project Overview
MacStatusBar is a macOS menu bar app for system monitoring (CPU, GPU, Memory, Network, Disk).

## Development Checklist

### When Adding New Features
1. **Implement the feature** in the appropriate files:
   - ViewModels: `Sources/ViewModels/` (CPUMonitor, NetworkMonitor, DiskMonitor)
   - Views: `Sources/Views/` (content views for each monitor)
   - Utilities: `Sources/Utilities/` (formatters, logger, process runner)

2. **Add tests** in `MacStatusBarTests/MacStatusBarTests.swift`:
   - Create a new test class if needed (e.g., `final class FeatureNameTests: XCTestCase`)
   - Test validation logic, edge cases, and data structures
   - Test any new formatters or utility functions

3. **Update Xcode project** if adding new files:
   - Add file references to `MacStatusBar.xcodeproj/project.pbxproj`

4. **Verify build passes** before committing

5. **Update README.md** if the feature is user-facing

### Testing Requirements
- All new features MUST have corresponding tests
- Test classes follow the pattern: `final class FeatureNameTests: XCTestCase`
- Run tests via Xcode (`⌘U`) or `xcodebuild test`

### Code Style
- Use `// MARK: -` for section organization
- Use `private` for internal methods
- Use `guard` for early returns
- Follow existing naming conventions (camelCase for variables, PascalCase for types)
- Use `AppLogger` for logging (categories: cpu, network, disk, process, general)

### Robustness Patterns
- Use `ProcessRunner` for external command execution (with timeout)
- Implement health checks for monitors (auto-restart if stale)
- Validate and clamp data values to reasonable ranges
- Handle counter wraparound for cumulative metrics
- Clean up timers properly in `deinit`

## File Structure
```
Sources/
├── App/MacStatusBarApp.swift
├── Models/AppSettings.swift
├── ViewModels/
│   ├── CPUMonitor.swift
│   ├── DiskMonitor.swift
│   └── NetworkMonitor.swift
├── Views/
│   ├── CPUContentView.swift
│   ├── DiskContentView.swift
│   ├── NetworkContentView.swift
│   ├── SettingsView.swift
│   └── SharedViews.swift
└── Utilities/
    ├── Formatters.swift
    ├── Logger.swift
    └── ProcessRunner.swift

MacStatusBarTests/
└── MacStatusBarTests.swift
```

## Commit Message Format
```
Short description of change

- Bullet points for details
- Include test information

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```
