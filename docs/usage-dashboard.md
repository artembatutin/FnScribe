# Feature 6.1 — Usage Dashboard

## Overview
The Usage Dashboard brings structured analytics to FnScribe so users can understand how dictation impacts their daily workflow. It aggregates per-session data into daily metrics, estimates time saved vs. typing, surfaces top applications, and tracks usage streaks. The dashboard ships as the first tab inside Settings and is powered by the `AnalyticsManager` for persistence and calculations.

## Key Components
| Component | Location | Responsibility |
|-----------|----------|----------------|
| `UsageMetrics` | `FnScribe/Domain/Models/UsageMetrics.swift` | Codable data model storing daily aggregates, lifetime totals, per-app stats, and streak data |
| `AnalyticsManager` | `FnScribe/Application/Managers/AnalyticsManager.swift` | Records sessions, persists metrics (`usage_metrics.json`), exposes queries for the dashboard |
| `UsageDashboardView` | `FnScribe/Presentation/Dashboard/UsageDashboardView.swift` | Main SwiftUI view combining period picker, metric cards, chart, app breakdown, streak section |
| `MetricCardView` | `FnScribe/Presentation/Dashboard/MetricCardView.swift` | Reusable card component with icon, value, subtitle, and trend badge |
| `UsageChartView` | `FnScribe/Presentation/Dashboard/UsageChartView.swift` | Swift Charts bar visualization with metric toggle (words / sessions / time saved) |
| `AppBreakdownView` | `FnScribe/Presentation/Dashboard/AppBreakdownView.swift` | Lists top apps plus relative share of sessions |

## Data Pipeline
1. When a transcription completes, `AppDependencies` creates a `TranscriptionSession`, informs `SessionManager`, then calls `analyticsManager.recordSession(_:)`.
2. `AnalyticsManager` calculates time saved (difference between typing @ 40 WPM and dictation @ 150 WPM) and delegates storage to `UsageMetrics`.
3. `UsageMetrics` updates lifetime totals, daily aggregates, per-app breakdown, and streak counters. Data persists to `~/Library/Application Support/FnScribe/usage_metrics.json`.
4. `UsageDashboardView` reads from the shared `analyticsManager`, showing live metrics whenever the Settings window is open.

## Settings Integration
- `SettingsView` now requires an `AnalyticsManager` instance and exposes the dashboard as the first tab (`Label("Dashboard", systemImage: "chart.bar.fill")`).
- `SettingsWindowController` and the `Settings {}` scene in `FnScribeApp` inject the shared manager from `AppDependencies` so both the Settings window and previews work.

## UI Sections
### 1. Period Picker
- Segmented control (`Today`, `Week`, `Month`, `All Time`).
- Drives metric cards and chart data via `AnalyticsManager.Period`.

### 2. Key Metrics Cards
Each card uses `MetricCardView`:
- **Words Dictated**: Sum of words for the selected period, includes trend vs previous period (except for all-time).
- **Sessions**: Total dictation sessions.
- **Time Saved**: Minutes/hours saved against typing baseline.
- **Avg Words/Session**: Derived average for context.

### 3. Usage Chart
- `UsageChartView` renders a 7/30-day bar chart (or single day for "Today").
- Metric toggle for `Words`, `Sessions`, `Time Saved` (minutes).
- Empty state when no data exists.

### 4. App Breakdown
- `AppBreakdownView` lists the top 5 applications by session count.
- Shows icon heuristic (IDE, browser, messaging, etc.), word totals, and percentage share.

### 5. Streaks
- Displays current and longest streak with icons (`flame`, `trophy`).
- Shows last active date (Today/Yesterday/explicit date).

## Persistence & Files
- Metrics stored in `usage_metrics.json` under Application Support.
- `AnalyticsManager` auto-loads on init, saving after each session.
- Streak logic only keeps last 90 days of daily metrics to limit file size.

## Extensibility Ideas
- Add export/share for analytics data.
- Surface per-app trend lines or pie chart.
- Implement goals (e.g., target words/day) with progress rings.
- Provide filters for bundle-specific dashboards.

Update this document whenever new metrics or visualizations are added to the dashboard.
