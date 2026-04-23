# GrowWise User Flow Diagrams

## Overview

This document outlines the key user flows for the GrowWise iOS gardening app, providing detailed navigation paths and interaction patterns based on the UI research findings.

## 1. App Launch & Onboarding Flow

```
App Launch
    ↓
Check Onboarding Status
    ↓
┌─────────────────────────────────────┐
│ First Launch: Onboarding Required  │ 
└─────────────────────────────────────┘
    ↓
Welcome Screen
├─ App introduction
├─ Core value proposition
├─ Continue button
└─ Skip option (leads to basic setup)
    ↓
Permission Requests
├─ Location Services (for hardiness zone)
├─ Notifications (for plant reminders)
├─ Camera/Photos (for plant journal)
└─ Optional: Allow all or configure individually
    ↓
Skill Assessment
├─ "How experienced are you with gardening?"
├─ Beginner (60% of users)
├─ Intermediate (30% of users)
└─ Advanced (10% of users)
    ↓
Location Setup
├─ Auto-detect location (if permitted)
├─ Manual zip code entry
├─ Hardiness zone identification
└─ Climate information display
    ↓
Garden Profile Creation
├─ Garden type: Indoor/Outdoor/Both
├─ Space size: Small/Medium/Large
├─ Sun exposure: Full/Partial/Shade
└─ Container types: In-ground/Raised beds/Pots
    ↓
Interest Selection
├─ Plant types of interest:
│  ├─ Vegetables
│  ├─ Herbs
│  ├─ Flowers
│  ├─ Houseplants
│  ├─ Fruits
│  └─ Succulents
└─ Growing goals (food, beauty, learning, etc.)
    ↓
First Plant Addition
├─ Curated starter plant suggestions
├─ Based on skill level and interests
├─ Simple one-tap addition
└─ Automatic reminder setup
    ↓
┌─────────────────────────────────────┐
│ Complete: Navigate to Main App     │
└─────────────────────────────────────┘
```

## 2. Main Navigation Structure

```
TabView (Bottom Navigation)
├─ Plants Tab 🌱
│  ├─ My Garden (default view)
│  ├─ Plant Catalog
│  └─ Plant Search
├─ Journal Tab 📖
│  ├─ Recent Entries
│  ├─ Plant Timeline
│  └─ Add Entry
├─ Reminders Tab ⏰
│  ├─ Today's Tasks
│  ├─ Upcoming Care
│  └─ Calendar View
├─ Learning Tab 📚
│  ├─ Tutorials
│  ├─ Plant Guides
│  └─ FAQ
└─ Profile Tab 👤
   ├─ Account Settings
   ├─ Garden Profile
   └─ Preferences

Navigation Stack per Tab:
- Independent NavigationPath for each tab
- Maintains separate history
- Deep linking support
- State preservation across tab switches
```

## 3. Plant Discovery & Addition Flow

```
Plant Catalog Entry Points:
├─ Plants Tab → "Browse Catalog"
├─ "+" Button in My Garden
└─ Search from any plant context

Plant Catalog View
├─ Search Bar (prominent placement)
├─ Filter Options
│  ├─ Plant Type (vegetables, herbs, etc.)
│  ├─ Difficulty Level
│  ├─ Space Requirements
│  ├─ Sun Requirements
│  └─ Care Intensity
├─ Sort Options (A-Z, Difficulty, Popularity)
└─ Plant Grid/List Toggle
    ↓
Plant Selection
├─ Tap plant card
└─ Navigate to Plant Detail
    ↓
Plant Detail View
├─ Hero image gallery
├─ Basic info (name, type, difficulty)
├─ Care requirements overview
├─ Detailed growing guide (expandable)
├─ Companion planting suggestions
├─ User reviews/tips (if available)
└─ Action Buttons:
   ├─ "Add to My Garden" (primary CTA)
   ├─ "Save for Later" (bookmark)
   └─ "Share Plant"
    ↓
Add to Garden Flow
├─ Quick Add (uses defaults)
│  ├─ Auto-generates care reminders
│  ├─ Sets planted date to today
│  └─ Assigns default garden location
└─ Custom Add (advanced users)
   ├─ Planting date selection
   ├─ Garden location assignment
   ├─ Custom reminder preferences
   ├─ Growth stage selection
   └─ Initial notes
    ↓
┌─────────────────────────────────────┐
│ Success: Plant added to garden     │
│ ├─ Confirmation message            │
│ ├─ Next reminders preview          │
│ └─ Navigate to Plant Profile       │
└─────────────────────────────────────┘
```

## 4. Plant Care & Management Flow

```
My Garden Entry Points:
├─ Plants Tab (default view)
├─ Plant notification tap
└─ Reminders completion action

My Garden View
├─ Garden overview stats
├─ Health status summary
├─ Quick action buttons
├─ Plant grid/list view
└─ Filter by status/type
    ↓
Plant Selection
├─ Tap plant card
└─ Navigate to Plant Profile
    ↓
Plant Profile View
├─ Plant photo gallery
├─ Current status indicators
├─ Growth stage progress
├─ Care action buttons:
│  ├─ Water
│  ├─ Fertilize
│  ├─ Prune
│  └─ Repot
├─ Care history timeline
├─ Next scheduled care
├─ Journal entries link
└─ Edit plant details
    ↓
Care Action Flow
├─ Tap care action (e.g., "Water")
├─ Confirmation dialog
│  ├─ "Mark as Done"
│  ├─ "Reschedule"
│  └─ "Add Note"
├─ Optional photo capture
├─ Optional notes
└─ Update plant status
    ↓
┌─────────────────────────────────────┐
│ Care Logged Successfully           │
│ ├─ Update plant health status      │
│ ├─ Schedule next reminder          │
│ ├─ Add to care history             │
│ └─ Return to plant profile         │
└─────────────────────────────────────┘
```

## 5. Journal Entry Creation Flow

```
Journal Entry Entry Points:
├─ Journal Tab → "Add Entry"
├─ Plant Profile → "Add Journal Entry"
├─ Care action completion
└─ Notification action

Add Journal Entry
├─ Plant selection (if not from plant context)
├─ Entry type selection:
│  ├─ General observation
│  ├─ Care activity
│  ├─ Problem/issue
│  ├─ Growth milestone
│  └─ Harvest log
└─ Pre-filled templates based on type
    ↓
Photo Capture Options
├─ Camera (direct capture)
├─ Photo Library (PhotosPicker)
├─ Multiple photo selection (up to 5)
└─ Photo organization/reordering
    ↓
Entry Details
├─ Title (optional, auto-generated suggestions)
├─ Growth stage selection
├─ Notes/observations (text input)
├─ Care actions performed (checkboxes)
├─ Health status update
└─ Date/time (defaults to now)
    ↓
Entry Review
├─ Photo thumbnail gallery
├─ Text summary
├─ Associated plant verification
└─ Publish/Save options
    ↓
┌─────────────────────────────────────┐
│ Entry Saved Successfully           │
│ ├─ Update plant profile            │
│ ├─ Add to journal timeline         │
│ ├─ Trigger any follow-up reminders │
│ └─ Navigate to journal entry view  │
└─────────────────────────────────────┘
```

## 6. Reminder Management Flow

```
Reminders Entry Points:
├─ Reminders Tab
├─ Push notification tap
├─ Today widget
└─ Plant profile reminders

Reminders List View
├─ Today's reminders (priority section)
├─ Overdue reminders (alert styling)
├─ This week preview
├─ Filter/sort options
└─ Bulk actions (mark multiple done)
    ↓
Reminder Interaction
├─ Swipe Actions:
│  ├─ Mark Done (leading swipe)
│  ├─ Snooze 1 hour
│  ├─ Reschedule
│  └─ Edit details
├─ Tap for full details
└─ Long press for context menu
    ↓
Reminder Details
├─ Plant information
├─ Care instructions
├─ Last performed date
├─ Photo guidance (if applicable)
├─ Weather considerations
└─ Action buttons:
   ├─ Mark as Done
   ├─ Postpone options
   ├─ Edit reminder
   └─ View plant profile
    ↓
Completion Flow
├─ Quick completion (one tap)
└─ Detailed completion:
   ├─ Add notes
   ├─ Capture photos
   ├─ Update plant status
   └─ Schedule next occurrence
    ↓
┌─────────────────────────────────────┐
│ Reminder Completed                 │
│ ├─ Update plant care history       │
│ ├─ Generate next reminder          │
│ ├─ Update plant health status      │
│ └─ Show completion confirmation    │
└─────────────────────────────────────┘
```

## 7. Search & Discovery Flow

```
Search Entry Points:
├─ Search bar in plant catalog
├─ Global search (navigation bar)
├─ Quick search in my garden
└─ Voice search (if implemented)

Search Interface
├─ Search suggestions (as user types)
├─ Recent searches
├─ Popular searches
├─ Category shortcuts
└─ Search filters panel
    ↓
Search Results
├─ Plants (catalog + user plants)
├─ Journal entries
├─ Care guides
├─ Tutorial content
└─ Community content (future)
    ↓
Result Categories
├─ My Plants (if applicable)
├─ Plant Catalog
├─ Learning Resources
└─ Journal Entries
    ↓
Filter & Sort Options
├─ Content type filter
├─ Date range (for journals)
├─ Plant characteristics
├─ Relevance/date sorting
└─ Save search option
    ↓
Result Selection
├─ Tap to view details
├─ Context-aware actions
├─ Quick add to garden
└─ Share/bookmark options
```

## 8. Settings & Customization Flow

```
Settings Entry Points:
├─ Profile Tab → Settings
├─ Notification settings prompt
└─ Onboarding skip recovery

Settings Categories
├─ Account & Profile
│  ├─ Personal information
│  ├─ Garden profile updates
│  ├─ Skill level adjustment
│  └─ Location settings
├─ Notifications
│  ├─ Push notification preferences
│  ├─ Reminder timing
│  ├─ Quiet hours
│  └─ Notification types
├─ App Preferences
│  ├─ Theme (light/dark/auto)
│  ├─ Measurement units
│  ├─ Default views
│  └─ Data sync settings
├─ Privacy & Data
│  ├─ Data export
│  ├─ Delete account
│  ├─ Privacy policy
│  └─ Terms of service
└─ Help & Support
   ├─ FAQ
   ├─ Contact support
   ├─ Feature requests
   └─ App version info
```

## 9. Error Handling & Recovery Flows

```
Common Error Scenarios:
├─ Network connectivity issues
├─ Photo upload failures
├─ Sync conflicts
├─ Invalid input data
└─ Permission denials

Error Recovery Patterns:
├─ Graceful degradation
│  ├─ Offline mode indicators
│  ├─ Cached data display
│  └─ Retry mechanisms
├─ User guidance
│  ├─ Clear error messages
│  ├─ Suggested actions
│  └─ Alternative paths
├─ Data preservation
│  ├─ Auto-save drafts
│  ├─ Offline queue
│  └─ Conflict resolution
└─ Progressive retry
   ├─ Immediate retry
   ├─ Background sync
   └─ Manual intervention
```

## 10. Accessibility Navigation Flows

```
VoiceOver Navigation:
├─ Logical reading order
├─ Semantic grouping
├─ Skip navigation options
└─ Custom gesture support

Voice Control:
├─ Numbered overlay support
├─ Voice command recognition
├─ Alternative input methods
└─ Command customization

Switch Control:
├─ Focus management
├─ Group navigation
├─ Timing adjustments
└─ Scanning patterns

Dynamic Type:
├─ Layout adaptation
├─ Content reflow
├─ Navigation preservation
└─ Interaction target sizing
```

## Navigation Implementation Notes

### State Management
- Each tab maintains independent `NavigationPath`
- Deep link handling preserves tab context
- State restoration on app lifecycle events
- Memory-efficient path management

### Performance Considerations
- Lazy loading for large plant catalogs
- Image caching and optimization
- Background data sync
- Efficient list rendering

### User Experience Principles
- Consistent navigation patterns
- Clear visual hierarchy
- Intuitive gesture support
- Responsive feedback
- Error prevention and recovery

These user flows provide a comprehensive guide for implementing navigation and interaction patterns that align with iOS 17+ best practices while serving the specific needs of gardening app users.