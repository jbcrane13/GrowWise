# Cultivation — Path to Complete
**Last updated:** April 2026

---

## Before Launch — Blockers

These aren't polish items. The app shouldn't ship without them.

**Fix the club share composer**
The club tab is the core bet. Right now the share flow is a placeholder. A user who tries to post to their club and hits a dead end will leave and leave a bad review. This is the highest priority item in the codebase.

**Add annual pricing tiers**
Monthly-only pricing ($4.99 / $9.99) makes Cultivation look like the expensive option against Planta ($35.99/yr) and Greg ($29.99/yr) before a user ever tries the app. Suggested tiers: $34.99/yr Premium, $79.99/yr Pro. Keep monthly as an option — just stop anchoring on it.

**Reframe diagnostics**
The disease reference knowledge base is useful but it's not AI inference. Marketing it as AI will generate bad reviews when users compare it to PictureThis. Rename to "Plant care guidance" or "Disease reference." Either build the real thing (v1.1 or v2.0) or position the KB honestly.

---

## v1.0 — Launch State

With the blockers addressed, here's what ships and what the app's promise is at launch:

- A structured garden management app for outdoor and mixed gardeners — beds, soil, composting, seed inventory, weather-adjusted reminders, hardiness zone awareness
- A private community layer — invite-code clubs with chat, events, activity feeds, and a public garden showcase
- The best beginner onboarding in the category — skill assessment, zone detection, guided first plant
- A clean, premium design identity that stands apart from every competitor in the space

**The pitch at launch:** *Grow alongside people you actually know.*
That's the position nobody else owns. Planta owns indoor plant parents. Greg owns houseplant enthusiasts. Cultivation owns outdoor gardeners who grow together.

---

## What Comes Next — v1.1

The goal of v1.1 is to deepen the community loop and close the gaps that outdoor gardeners will hit first.

**Collaborative plant tasks**
Let club members water, fertilize, and log care on shared plants. Right now clubs are a chat room inside a garden app. This makes them a genuinely integrated experience — the activity feed shows who watered what, members can coordinate care, and the garden becomes a shared object rather than a private one. No competitor has this.

**Harvest tracking**
Every vegetable gardener expects to track what they grew. It's also the most natural share moment in the club feed — posting a harvest to your plot partners closes the loop on the whole growing season. Add it to the plant record, surface it in the club feed, let users log weight/quantity over time.

**Frost and weather alerts**
The weather infrastructure already exists. Extending it to proactive alerts — "frost expected tonight, cover your tomatoes" — makes the app feel like it's actively watching out for the user rather than just reminding them of scheduled tasks. High perceived value, low lift given what's already built.

**Real-time chat polish**
Typing indicators and read receipts. Small details, but without them the club chat feels like a bulletin board rather than a live group. Sets the right expectations for what a club actually is.

**Light meter**
A one-to-two day build. Planta, Greg, and PictureThis all have it. Rounds out the experience for users with any indoor plants in their collection.

---

## What Comes After — v2.0

These are the moves that take Cultivation from good to excellent. Don't rush them — getting v1.0 and v1.1 right matters more.

**Real ML plant diagnostics**
Build an actual CoreML model for disease identification. Once this exists, the AI diagnostics positioning becomes defensible and genuinely differentiating — on-device, private, no server required. Until it's built, keep the positioning honest.

**Android**
Every competitor has it. You're leaving half the market on the table without it. Set a trigger — once the iOS product is stable and user metrics are healthy, start the Android build. Don't let it drift indefinitely.

**Garden layout map**
A visual bed layout editor. Even a simple drag-and-drop grid would let users plan spatially rather than just via text groupings. Natural companion to the companion planting data already in the app.

**Planting calendar with frost dates**
Zone-aware guidance on when to start seeds, when to transplant, when to expect last/first frost. Extends the seasonal planner into something genuinely prescriptive rather than informational.

**IoT / sensor connectivity**
Smart garden sensors are becoming mainstream. Getting there before competitors establishes a hardware-adjacent moat. Not urgent now — get the social layer right first.

---

## What to Leave Alone

**AR visualization** — It works, it's a nice demo feature, but deepening it before the community loop is solid would be misplaced effort.

**Competing on plant ID database size** — PictureThis has 400K species at 98% accuracy and has been building this for years. The Perenual integration closes the practical gap. Don't make database breadth a marketing story.

**Indoor plant care depth** — Planta owns this with 7 million users. Adding misting schedules and repotting reminders doesn't help win the outdoor gardener who is the core target.
