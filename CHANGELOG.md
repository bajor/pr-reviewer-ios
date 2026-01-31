# Changelog

All notable changes to PR Reviewer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-31

### Added
- In-memory caching system (PRCacheService) with TTL-based expiration
- Lazy loading for PR details - only loads when PR becomes visible
- Shared view model store to reuse PR detail view models across swipes
- File content caching across PRs

### Changed
- PR list uses cache-first loading pattern for instant display
- Change detection skips PRs that haven't been updated (checks `updatedAt`)
- Background refresh no longer blocks UI

### Fixed
- Eliminated constant loading pauses when switching between PR cards
- Reduced redundant API calls during 5-minute refresh cycle

## [1.0.0] - 2026-01-31

### Added
- PR discovery: View all open PRs you're involved in (author, reviewer, or mentioned)
- Horizontal swipe navigation between PRs
- Syntax-highlighted diff view with dark red/green backgrounds
- Full-width code display with no navigation overlays
- Inline comments displayed below code lines
- Comment resolution with 5-minute undo window
- Swipe gestures: right to close PR, left to approve
- Merge conflict detection before approval
- Multi-account support (up to 5 GitHub accounts)
- Local notifications for new commits/comments (5-minute polling)
- Tap notification to navigate directly to PR
- Landscape-only orientation optimized for iPhone 13 Mini
- Dark theme throughout
- Secure token storage in iOS Keychain
