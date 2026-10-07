# Mobile-native UX and PWA technical audit

Mandatory whenever the product has a phone-sized UI or a web manifest.

**The bar:** "it is responsive" is not a pass. Responsive means it *fits*; native-quality means it
was *designed for a hand*. Ask of every screen:

> If this had been designed for a phone first, would it look and behave this way?

Draw on platform conventions — Apple HIG, Material 3, the best current iOS/Android banking,
productivity and enterprise apps — without copying any one system. Name the convention you
invoke so the finding is a UX PRINCIPLE, not a preference.

## A. The native-feel walk

At 360–390 px wide (and a 320 px sanity check), with touch emulation, for every role:

1. **Launch → land.** Is the first screen the one this role needs most? Is the primary action
   visible without scrolling?
2. **Navigate.** Persistent bottom navigation for 3–5 top-level destinations? Is the current
   destination obvious? Is depth shallow (≤ 3 levels to any task)? Does back go where the user
   expects — including the device/browser back and a back gesture closing an open sheet?
3. **Find.** Search reachable with a thumb? Filters in a bottom sheet, not a desktop toolbar
   squeezed into a row? Results update without a hidden "Apply" the user must discover?
4. **Act.** Primary action near the thumb (bottom of screen, sticky where the task needs it)?
   Destructive actions separated, confirmed, undoable where possible?
5. **Input.** Keyboard type matches the field (`inputmode`, `type`, `autocomplete`,
   `enterkeyhint`)? The focused field and the submit button stay visible when the keyboard opens?
   No zoom on focus (iOS zooms inputs under 16 px font)?
6. **Feedback.** Every tap acknowledges within ~100 ms (pressed state, spinner, optimistic update)?
   Success and failure are announced where the user is looking?
7. **Leave and return.** State survives backgrounding, a reload and a lost connection?

## B. Desktop patterns forced onto a phone — name them, prescribe the mobile pattern

| Desktop pattern seen on phone | Mobile pattern to recommend |
|---|---|
| Data table with horizontal scroll or crushed columns | Compact list rows: primary line, secondary meta, trailing value/status; tap for detail |
| Sidebar / hamburger as the main navigation | Bottom tab bar for top-level; hamburger only for rare destinations |
| Centered modal dialog for a form | Bottom sheet (with drag handle and safe-area padding) or a full-screen page for long forms |
| Dropdown/select with many options | Searchable sheet / list picker |
| Hover-dependent actions, tooltips | Visible actions, long-press or a row-actions sheet |
| Toolbar of small icon buttons | One primary action + overflow menu / action sheet |
| Inline multi-column forms | Single column, grouped, progressive disclosure |
| Pagination controls (page 1 2 3 …) | Infinite scroll or "Load more", with position preserved |
| Desktop date picker grid | Native `type=date` or a wheel/sheet picker |
| Command palette, keyboard shortcuts as primary path | Search field + recents |
| Breadcrumbs | Back button + clear title |
| Toasts in a top corner | Bottom snackbar above the tab bar, with action (Undo) |

## C. Touch and ergonomics

- Targets ≥ 44×44 pt (HIG) / 48×48 dp (Material); WCAG 2.5.8 minimum 24×24 with spacing.
  Measure, do not eyeball. Inputs count.
- ≥ 8 px between adjacent targets; destructive next to primary is a defect.
- Thumb zone: frequent actions in the bottom half; nothing critical in the top corners only.
- Gesture conflicts: horizontal swipes inside a scroller, pull-to-refresh vs sheet drag, edge
  swipe vs in-app carousels.
- Pressed/active states exist (`:active`, not only `:hover`); no 300 ms tap delay (viewport meta).

## D. Visual restraint — "modern" is clarity, not decoration

Flag as findings when they hurt clarity or density: cards inside cards, every element in a
rounded box, decorative gradients and heavy shadows, oversized headers eating the first screen,
icons that add no meaning, animations that delay the task, modals for things that should be
inline. Recommend hierarchy through type weight, spacing and alignment first.

Check: readable body size (≥ 16 px for inputs, ~15–17 px body), line length, contrast in both
themes, consistent vertical rhythm, one clear primary per screen, light/dark parity.

## E. Layout mechanics

- Safe areas: `viewport-fit=cover` + `env(safe-area-inset-*)` on app bar, tab bar, sheets and
  sticky footers. Content must not hide behind the notch or home indicator.
- Viewport units: `100vh` is wrong on mobile browsers; expect `dvh`/`svh`/`lvh` or JS-measured.
- Keyboard: Android `interactive-widget=resizes-content` (or equivalent); iOS overlays the
  keyboard — needs `visualViewport` handling for sheets and sticky actions.
- No horizontal document scroll at 320 px. Long words, emails, numbers and currency wrap or
  truncate deliberately.
- Scroll: one scroll container per view; sticky headers/footers do not jitter; momentum scrolling;
  `overscroll-behavior` set where pull-to-refresh or sheet bounce would misfire.

## F. PWA technical audit

| Area | Check |
|---|---|
| Manifest | `name`, `short_name`, `start_url`, `scope`, `display` (`standalone`), `theme_color`, `background_color`, maskable + any-purpose icons (192, 512), `id` |
| iOS meta | `apple-touch-icon` 180 px, `apple-mobile-web-app-capable`/`status-bar-style`, splash behavior understood (iOS builds it from manifest/meta, limited control) |
| Service worker | Registration scope; precache only the app shell; versioned caches; old caches cleaned on activate |
| Caching strategy | Static assets cache-first with hashed names; HTML network-first or stale-while-revalidate; **API/auth responses never cached** unless deliberately designed (user data leaking across accounts on a shared device is a security finding) |
| Updates | How does a new version reach users? `skipWaiting` + reload prompt vs silent? Can a user be stuck on a stale shell forever? Is there a "new version available" UX? |
| Offline | Offline fallback page or a usable read-only mode; writes queued with clear "pending" status; replay is idempotent; conflicts handled; queue scoped to the signed-in user |
| Network recovery | Online/offline detection that doesn't trust `navigator.onLine` alone; retry with backoff; no silent data loss |
| Storage | What is in localStorage/IndexedDB? Tokens or personal data persisted? Cleared on sign-out? Quota/eviction considered (iOS evicts after inactivity)? |
| Install | Install prompt timing (not on first load); iOS has no prompt — is there an "Add to Home Screen" hint? |
| Push | Permission requested in context after a user gesture, never on load; iOS requires an installed PWA (16.4+); payload contains no secrets; unsubscribe on sign-out |
| Permissions | Camera, location, notifications requested just in time with explanation; denial handled |

## G. Say what a PWA can and cannot do — honestly

| Reliable in PWAs | Unreliable / platform-dependent | Requires native |
|---|---|---|
| Installable icon, standalone window, offline shell, cache, IndexedDB, Web Push (Android; iOS 16.4+ installed only), camera via `getUserMedia`, geolocation, share target (Android), Web Share | Background sync (Chromium only), periodic sync, badging, file system access, Web Bluetooth/NFC/USB (Chromium/Android only), storage persistence on iOS, reliable launch splash on iOS, orientation lock | Guaranteed background execution, geofencing, true background location, deep OS integration (widgets on iOS, Siri/Shortcuts actions), reliable silent push, in-app purchases via stores, Bluetooth on iOS |

Never recommend a capability the target browsers do not provide. When a requirement needs native,
say so and name the smallest native wrapper option (e.g. Capacitor/TWA) as a JUDGMENT, not a fact.

## H. What cannot be verified without a device

Real standalone launch, real safe-area values, real keyboards, real gesture back, real push
delivery, real performance on a low-end phone. List them in the report's Coverage line rather
than claiming them.
