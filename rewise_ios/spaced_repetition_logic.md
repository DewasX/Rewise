# Spaced Repetition Logic Architecture

## SECTION 1 — CURRENT ALGORITHM
The spaced repetition logic uses a variation of the SuperMemo-2 (SM-2) algorithm. The logic updates when a user reviews a topic and chooses a rating.

**Ratings:**
- `forgot` (value: 2)
- `hard` (value: 3)
- `medium` (value: 4)
- `easy` (value: 5)

**How ease_factor is calculated:**
- Formula: `EF = EF + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02))`
- The Ease Factor is bounded with a floor value of `1.3`.

**How interval_days is calculated:**
- If rating depends on memory retention (`rating >= 3`): `NewInterval = round(CurrentInterval * EF)`. (If it's a new topic where the current interval is 0, the default new interval is `1`).
- If the user forgot (`rating < 3`), the interval is immediately reset to a flat `1` day.

**How memory_score is calculated:**
Memory score is computed purely on the frontend as a real-time decay curve mapping elapsed time against the static `stability` field captured during the previous review.
- Formula: `Retention = exp(-daysSinceLastReview / Stability)`
- Memory Score evaluates directly to `Retention * 100.0`.
- Priority is ranked dynamically utilizing this decay: `PriorityScore = (100 - Retention) + OverdueDays * 5 + WeaknessWeight`.

**How repetition_count and next_review_date are updated:**
- Repetition Count: Increments locally (`current count + 1`) during the review evaluation.
- Next Review Date: Evaluates to exactly `DateTime.now() + Duration(days: NewInterval)`.

---

## SECTION 2 — DATA SOURCE
The repetition system utilizes static database snapshots during a given review.

**`topics` table:**
- `ease_factor` (Reads previous EF, updates with calculation)
- `interval_days` (Reads current interval, updates to new interval)
- `stability` (Acts as the exponent decay baseline. Currently maps exactly to `interval_days` * 1.0; fallback goes to 1.0)
- `memory_score` (Resets static field to `100.0`)
- `repetition_count` (Increments + 1)
- `last_reviewed_at` (Sets to the review timestamp)
- `next_review_date` (Sets to updated `DateTime.now() + NewInterval`)

**`review_history` table:**
- `topic_id`
- `user_id`
- `rating` (Integer value of the selected rating)
- `interval_before`
- `interval_after`
- `retention_before` (Evaluates the dynamic frontend score at the exact moment of the review before executing the update)
- `retention_after` (Forces flat `1.0` evaluating a perfect 100% memory score immediately post-review).

---

## SECTION 3 — REVIEW FLOW
1. **User opens topic:** The `StudySessionScreen` displays the topic attributes.
2. **User reviews & rates:** The user triggers "Start Focus Timer", evaluates their memory, clicks "Mark as Reviewed", and selects a rating.
3. **App performs optimistic UI update:** Instead of waiting for the database, Riverpod (`todaysTopicsProvider`) instantly removes the topic from the frontend study queue ensuring the UI remains perfectly snappy.
4. **Algorithm runs:** `TopicService.recordReview` calls `SpacedRepetitionEngine` functions locally dynamically compiling the New EF, Interval, and next dates. 
5. **Database updated:** Updates to the `topics` table and inserts an audit log into the `review_history` table are sent to Supabase.

---

## SECTION 4 — LOCATION OF THE ALGORITHM
The entire logic operates natively on the **Flutter frontend code**:
- Calculations: `lib/core/spaced_repetition_engine.dart` (Pure Dart mathematical logic).
- Topic Scoring & Getters: `lib/models/topic.dart` (`currentMemoryScore` and `priorityScore` logic).
- Database Push & Integration mapping: `lib/core/topic_service.dart`.
There is currently no compute running in a Supabase Edge Function or external API for algorithm logic.

---

## SECTION 5 — DAILY GOAL LOGIC
- **Where daily_goal is stored:** In the `users` table on Supabase within the user's profile database row. The default fallback rests at `10`.
- **How reviews_today is calculated:** Dispatched via `UserService.getReviewsCompletedToday()` counting rows generated within the `review_history` tables mapped strictly to today's date bounds for the current user ID.
- **How the dashboard progress is updated:** The computation binds to `TodaysTopicsNotifier` exposing a `progress` getter. The value represents `(completedToday / dailyGoal).clamp(0.0, 1.0)`. Increments resolve locally without demanding round-trip queries mid-session.

---

## SECTION 6 — ANALYTICS CALCULATION
All analytics are computed dynamically on the frontend inside `analytics_screen.dart` leveraging the cached or current DB payloads:
- **Total topics:** `topics.length` via the fully loaded DB topics list. 
- **Subject breakdown:** Topics list gets mapped to bins structured by unique `subjectId`. Loop renders UI cards displaying total bin sizes (`count`) alongside dynamic evaluation averaging the total memory strength of the topics within that particular subject bin.
- **Memory strength:** Averaged real-time against `topic.currentMemoryScore` running the decay formula across the global array of topics.

---

## SECTION 7 — EDGE CASE HANDLING
- **forgot rating:** Heavily penalizes the topic by decreasing EF and completely stripping the `intervalDays` back down to `1`.
- **first review of a topic:** Topics naturally initiate default schema structures mapping flat initial values (`interval=1`, `EF=2.5`, `repetitions=0`, `stability=1.0`).
- **repeated failures:** Re-strips EF back down using a mathematical floor of `1.3` ensuring no exponential reverse breakdown of math logic ensuring intervals are suppressed infinitely tracking 1 flat day.
- **overdue reviews:** Priority system forcefully pushes these topics to the top of the queue factoring in a robust priority equation. Computed retention continues decaying tracking 0 memory score naturally.

---

## SECTION 8 — DATA SYNC
- **mobile app <-> web app:** Native application communicates directly over the internet to the Supabase backend utilizing the standard REST API hooks. Any modification immediately updates Supabase tables allowing web clients synchronized context assuming queries trigger appropriately on web.
- **Offline Reliability:** Supabase updates funnel natively using `TopicService.recordReview()`. In networking failures, payloads bounce to the `OfflineSyncService` queuing reviews into SharedPreferences natively handling retry-loops silently in the background enforcing consistency. 

---

## SECTION 9 — PERFORMANCE DESIGN
- **recalculates everything on each review:** Specifically NO. The platform implements a lightweight caching system. Database elements like `stability` and `interval` operate strictly as historical snapshots recorded perfectly upon a review cycle completing and never mutate mid-flight. 
- **Dynamic Getters:** Dynamic variables like Memory Decay are executed exclusively via extremely lightweight pure Dart getters natively binding to UI render cycles without requiring round-trip computations. Memory arrays sort entirely in the UI.

---

## SECTION 10 — OUTPUT
**Technical Implementation Summary:**
The spaced repetition workflow heavily leverages a "fat-client" methodology natively built within Dart/Flutter lacking dependency on scheduled external CRON jobs or Supabase edge functions. System utilizes an SM-2 structure driving exponential interval gaps evaluated natively during study cycles pushing static output snapshots into general database structures. 

Realtime retention physics leverage historical snapshots to draw linear or exponential decay patterns natively bound to Flutter states ensuring the backend acts exclusively as a dumb datastore. Another system collaboratively analyzing integration can universally restructure the algorithms output metrics reliably mapping identical update payload schemas (`ease_factor`, `interval_days`, `stability`) injected gracefully utilizing the predefined `TopicService` dispatch commands without demanding database migrations or sweeping schema re-writes.
