# Getting in: every way into ApneDoctors (Flutter build spec)

Status: approved direction, to build (founder, 2026-11-24). Revision 2 (2026-11-24): matched to the final screen
list ("ApneDoctors: the final screen list", section 1, G1–G19, and section 11, P1–P5) and the founder's answers.
Patient app, Flutter, `apps/patient/` in `Dev-Faldu/apnedoctors_app`, Supabase project `yljfnbudjdijwjshqaba`.
Design language: Kalighat pop (see `docs/design/kalighat-pop/N00Splash.dc.html` and `N01Welcome.dc.html`).
Edge cases have IDs `GI-xx`; screens have this spec's IDs (GS, SI, WB, HL, PR) and the final list's IDs (G, P).
Name both in tests and commits (`GS3 · G7`, `GI-41`). The older `EC-AUTH` and `EC-AGE` lists were for the Expo app;
this spec replaces them for Flutter, and keeps their lessons.

What changed in revision 2:
- About you (G7) asks gender, and adults may give just their age ("about 52"). Teens and under-13s still give birth
  month and year.
- After the data consent: Health (G8), Medicines and emergency contact (G9), ABHA (G13–G14), Connect your apps (G15),
  all optional with Skip.
- Permissions (G16): only notifications during onboarding; camera and location are asked at first use.
- After "you're in": First-time home (G17), not the regular Today.
- New: Hospital landing (G18), I have a token already (G19), and a launch row for a hospital's QR (GI-19).
- Pro: Pro mode welcome (P1) comes before "Who are you?".
- GI-01: `openedBefore` is set once Welcome is shown (not when the opening starts).
- GI-34: Sign in never reveals whether a number has an account.
- Get started is renumbered GS1–GS12 to fit the new screens.

---

## 1. What happens when the app opens (the launch router)

One pure function decides the first screen: `decideLaunch(LaunchState) -> LaunchRoute`. It is unit-tested against every row below. Nothing else in the app decides where launch goes.

`LaunchState` is built from:
- **Device flags** (shared_preferences): `openedBefore`, `remembered`, `under13LockUntil`, `lastWakeAt`, `pendingPhone`, `otpResendAt`, `proIntent`.
  - `remembered` holds first name, last method (phone or google), masked phone `+91 98•••••210` or masked email `p•••@gmail.com`. Keep it in flutter_secure_storage, because it is personal.
- **Session** (Supabase, kept in secure storage): none, valid, refresh failed, or offline with a stored session.
- **Profile from the server** (`public.my_launch_state()`): onboarding step reached, age band, parent consent status, roles (patient, doctor, pharmacy, lab, hospital), pro application status, account status (active, deletion scheduled, suspended), whether First-time home was seen, last mode (patient or pro).
- **Remote config** (`public.app_requirements()`): minimum supported app version.
- **Launch link**: deep link, notification target or a hospital's QR link, if any.

| # | Situation | First screen |
|---|---|---|
| GI-01 | App never opened on this device | Native splash → full animated splash (G1, N00) → handoff → **Welcome** (G2, N01). Set `openedBefore` only once Welcome is shown. |
| GI-02 | Opened before, signed out, a remembered account exists | Native splash → short brand moment (the "a" opens its eyes and blinks, ≤ 0.8 s, no writing animation) → **Welcome back, {name}** (G5). |
| GI-03 | Opened before, signed out, nothing remembered (the user tapped "Not you?", or was never signed in) | Short brand moment → **Welcome** (N01) with its normal entrance. No full splash. |
| GI-04 | Signed in, profile complete, adult or teen with consent | Native splash → **quick wake** (the "a" wakes: eyes open, one blink, ≤ 1 s) → **Today**. If 3 h or more since `lastWakeAt`, Today opens with a time-of-day greeting ("Good morning, Priya"). At night (22:00–05:00 IST) the wake is dimmer and quieter. If First-time home (G17) has not been seen yet, it opens instead of Today. |
| GI-05 | Signed in, onboarding not finished (app killed mid-way) | Resume at the first missing step (About you, Your data, Health, Medicines, ABHA, Apps, Notifications). Never restart from Sign up. |
| GI-06 | Signed in, teen, waiting for a parent | **Waiting for your parent** screen. |
| GI-07 | Signed in, teen, parent said no or the link expired | **Parent consent didn't go through** screen (ask again, or change parent number). |
| GI-08 | Signed in, pro application pending, rejected or needs changes | **Pro status** screen, with "Use ApneDoctors as a patient" always available. |
| GI-09 | Signed in, approved pro, last used mode was pro | Pro home (placeholder screen for now: "Pro home is coming next"). |
| GI-10 | Stored session but the refresh failed (revoked, expired, account deleted elsewhere) | **Welcome back, {name}** with a calm banner: "You were signed out to keep your account safe. Sign in again." Clear the dead session first. |
| GI-11 | Offline with a stored session | Open **Today** from cache with an offline strip ("You're offline. Showing what we saved."). Never sign out for being offline. With no cache, show an **Offline** screen with Retry. |
| GI-12 | Offline, no session | Welcome / Welcome back as usual. "Send code" and Google show "You're offline. Connect and try again." |
| GI-13 | Account scheduled for deletion (inside the grace period) | **Your account is set to be deleted on {date}**: "Keep my account" or "Continue deletion" (which signs out). |
| GI-14 | Account suspended | **Account on hold**: reason in plain words and how to appeal (grievance officer contact). No crash loop, no retry loop. |
| GI-15 | App version below the minimum | **Update needed** screen that blocks everything, with a store button. Checked before anything else. |
| GI-16 | Under-13 lock active on this device or account | **See you at 13** (G12) until the lock has passed. Childline 1098 shown. |
| GI-17 | Opened from a deep link or notification while signed out | Normal sign-in path. After sign-in, go to the link target (if the user may see it), not Today. |
| GI-18 | Opened from a deep link while signed in as someone else (e.g. a family link meant for another account) | Ask "This link is for another account. Switch?" Never switch silently. |
| GI-19 | Opened from a hospital's QR (signed in or out) | **Hospital landing** (HL1 · G18) for that hospital: its name, Check in, I have a token already. Signed out, Check in goes through sign-up or sign-in and comes back. No splash, no Welcome in between. |

Order of checks: update needed → under-13 lock → session and refresh → account status → hospital QR → onboarding → teen consent → pro → First-time home → Today.
While the router waits on the network, the native splash stays up for at most 1.5 s. After that, show the brand moment and decide from cache.

---

## 2. The doors on Welcome (G2 · N01)

Welcome has three doors, and each is its own path:
1. **Get started** → new patient (section 3).
2. **I already have an account** → returning patient signing in (section 4).
3. **For doctors ›** → pro mode (section 6).

The signed-out returning case (GI-02) skips Welcome and gets its own screen (section 5). A hospital's QR opens
its own landing (section 7).

---

## 3. Get started (new patient)

### GS1 · G3 Sign up
Built 2026-11-26. Reference board: `docs/design/kalighat-pop/G03GetStarted/` (a reference, not a copy: the founder
asked for the best design, not the board's exact pixels).
- **Arriving (the walk through the doorway):** from Welcome's Get started, Welcome's doorway grows towards you and
  dissolves, the living "a" steps out of it and glides on one curve to sit beside the headline, the toran drops in
  across the top and the page rises in (0.9 s). Back plays it in reverse (0.7 s). Reduced motion: a cross-fade.
- Headline: **"let's get you in."** Line: "Your number keeps your care in one place. We'll text you a code."
- The "a" beside the headline: *listening* (leans in, eyes follow the digits), *happy* (a good number, code sent),
  *worried* (starts with 0–5, offline, a failed send), *thinking* (sending).
- **Phone field:** fixed `+91`, then ten slots in the shape of an Indian mobile (five, a breath, five). An empty slot
  is a painted dot; each digit drops into its slot and takes the dot's place; a paste fills slot after slot. A tick pops
  in when the number looks right. Numeric keyboard, autofill `telephoneNumber`, one real (invisible) text field for
  typing, pasting, autofill and screen readers ("Mobile number, plus 91").
- **Help line** (16 px, under the field): "We'll text a 6-digit code to this number." when valid; "Indian mobiles start
  with 6, 7, 8 or 9." as soon as a number starts with 0–5 (GI-21); the server's answers (GI-26, GI-66, GI-67).
- **Send code**: primary vermilion, resting until the number is valid; "Sending code" with three dots while it works;
  then an ink "Code sent · change number" and "Code sent to +91 98765 43210." (GS2 takes over here once built).
- A divider ("or"), then **Continue with Google** (Google's own G, the app's type). Until the keys arrive it says
  GI-37's "Google sign-in isn't working right now. Use your phone number instead."
- Offline (GI-12): an ink pill slides in under the toran ("You're offline. Connect and try again."), both buttons rest,
  nothing on the page moves.
- Keyboard open (GI-63): Send code stays above it. On a short phone the line folds away and the "a" glides up into the
  top bar.
- Footer: "By continuing you agree to our Terms and Privacy Policy" (both links), and "Already have an account?
  **Sign in**".
- Android back goes to Welcome.

### GS2 · G4 Code (OTP)
Built 2026-11-27. Reference board: `docs/design/kalighat-pop/G04Code/` (a reference, not a copy).
- **Arriving from GS1:** after a beat of "Code sent", the page changes around a still toran, back button and "a": the
  phone page steps aside to the left, the code page slides in from the right, and the phone number lifts out of its
  field and flies up into the line below the headline (0.7 s). Back reverses it and the number flies home.
- Headline: **"check your messages."** (sized to sit beside the "a"; with large text the "a" moves to the top bar and
  the headline grows only as far as its longest word fits).
- Line: "We texted a 6-digit code to" and a pill **+91 98765 43210 · Change** (tap to change, GI-31).
- **Code tiles:** six painted tiles (3 + 3) in the language of the number field: an empty tile holds a dot, the next
  one the vermilion caret, digits drop in. One invisible text field types, pastes and autofills (`oneTimeCode`);
  screen readers hear one field, "6-digit code".
- It checks by itself when the 6th digit lands, exactly once (no button). Checking: the tiles ripple in a slow wave,
  the "a" looks up, "Checking…".
- **Verified:** the tiles turn green one after another, the "a" jumps for joy twice, marigold petals go up,
  "Verified. You're signed in." (Supabase `verifyOTP`; the session is saved). About you (GS3) comes next.
- **Wrong (GI-25):** red tiles shake, then the digits drop out (the wrong code stays visible for 0.7 s, reduced motion
  too). "That code didn't match. 2 tries left." Our own cap of 3 per code; then "That's 3 tries. Send a new code to try
  again." with a Send a new code button.
- **Expired (GI-27):** Supabase answers the same for wrong and expired codes, so a rejected code older than the code's
  life (60 s, as set in Supabase) is called expired: "That code has expired. Send a new one." with one tap.
- **Too many tries (GI-26):** the server's real wait, counting down; tiles locked.
- **A new code:** "Send a new code in 0:42", then a pill to send it. Waits grow: 1, 2, then 3 minutes (the server allows
  one a minute).
- **Didn't get it? (GI-28):** after 30 s a card offers Send it again (with the live countdown until allowed), Check the
  number (back to GS1, GI-31) and Use Google instead (GI-37's line until the keys arrive).
- Keyboard open on a short phone (GI-63): the "a" glides into the top bar, the headline folds to one line, and the
  tiles and the line under them stay above the keyboard.
- The sent code is kept for 10 minutes (number, time, sends); reopening the app returns here (GI-29). Back keeps the
  number on GS1 (GI-30).
- Android SMS User Consent API: not wired yet (needs a native plugin, tested on a real phone).
- When the person came from a hospital's QR (GI-19), the trouble line also says "Having trouble? Go to the reception desk."

### GS3 · G7 About you
- **"what should we call you?"**: first name required, last name optional.
- **"how do you describe yourself?"**: Woman, Man, Another identity, Prefer not to say. Why: "Some care differs by body. Only your doctors see this."
- **"when were you born?"**: month and year wheels.
  - **"Only know your age?"** opens a single age field instead. Allowed for adults only. The age is stored as an estimate (birth year worked out, no month, marked estimated) and shown as "about 52".
  - An estimated age under 18 is not accepted: "For anyone under 18 we need the birth month and year, so we can follow the law on consent." Back to the wheels.
- Why we ask: "Doctors need your age. We never show it to anyone else."
- Confirm before saving: "Born in March 2009? You can't change this later." (or "About 52? You can't change this later.") with **Yes, that's right** and **Change**.
- Age is computed on the server in IST from month and year (an estimate counts as its year). Then:
  - 18+ → GS5;
  - 13–17 → GS4;
  - under 13 → **See you at 13** (G12).

### G12 See you at 13
- "ApneDoctors is for 13 and up. A parent can add you to their family so you're still looked after." Childline 1098.
- Nothing about the child is saved. The account is blocked for 24 h and the device for 7 days (GI-41).

### GS4 · G11 Parent consent (13–17 only)
- **"one quick yes from a parent."**
- Line: "India's privacy law (DPDP) needs a parent's okay before you can see doctors or order medicines."
- Parent's phone number → **Send request**.
- Then **Waiting for your parent**:
  - live status and resend (after 60 s);
  - change number;
  - "What you can do meanwhile": read Discover, set up your profile.
  - No consults, orders or public posts until approved.
- Until a parent says yes, a teen's health details are not collected: GS5–GS9 wait and follow straight after the yes.

### GS5 · G10 Your data, your rules (DPDP consent)
- **"your health, your rules."**
- Three plain points:
  - what we keep (consults, prescriptions, reports);
  - who sees it (only doctors you choose, and family you add);
  - your control (download or delete any time).
- **I agree**, plus "Read the full privacy notice".
- Consent is recorded per purpose, each with its notice version and time, and each withdrawable later from Settings.
  This screen records the purpose `care`. Linking ABHA (GS8) and connecting apps (GS9) ask for their own purposes
  when the person chooses them.
- This consent is separate from the Terms.

### GS6 · G8 Health (optional)
- **"anything doctors should know?"**
- Blood group (or "I don't know"), allergies, conditions you already know. Chips for common ones, and type your own.
- Line: "Only what you already know. You can skip any of it."
- **Save** and **Skip**. Nothing here is required or guessed; the app never suggests a condition.

### GS7 · G9 Medicines and emergency contact (optional)
- **"what do you take now?"**: medicines you take, as you call them, with how often (your words).
- **"who should we call in an emergency?"**: name, phone, relation.
- **Save** and **Skip**. The app never suggests or doses a medicine.

### GS8 · G13–G14 ABHA (optional)
- **"link your health ID."** Link an existing ABHA (number or address, then a code), or create one with Aadhaar
  inside the app (G14). **Skip for now**.
- Records the consent purpose `abha_link` when the person links.

### GS9 · G15 Connect your apps (optional)
- **"bring your steps and sleep."** Health Connect (Android) or Apple Health (iOS), read only, chosen types.
  **Skip**. Records the consent purpose `connected_apps` when the person connects.

### GS10 · G16 Notifications
- **"can we tap you on the shoulder?"**
- Line: "Only for doctor replies, medicine and test updates, and family alerts. Never spam."
- **Allow notifications** opens the system prompt. **Not now** carries on without asking.
- Camera is asked the first time someone scans ("To scan the hospital's QR or your report."), and location the first
  time someone looks for care ("To show doctors and hospitals near you."). Never during onboarding.

### GS11 You're in
- **"you're in, Priya."** The "a" celebrates, a soft confetti of marigold petals falls, then First-time home.
- "Let's go" button, or it moves on by itself after 1.6 s.
- With reduced motion: no confetti, just a cross-fade.

### GS12 · G17 First-time home
- One clear first action, nothing empty-looking. Placeholder for now ("Today is coming next"), with the real first
  action designed with Today.

### Google path
- Google gives name and email. Prefill the name in GS3, but still ask for gender and birth month and year (or age).
- Phone verification is not asked at sign-up. It is asked later, at the first booking or order.

---

## 4. I already have an account (returning patient)

### SI1 · G6 Sign in
- **"good to see you again."**
- Same phone field and Google button as GS1, but different words and a different "a" mood (*happy* to see you).
- Phone OTP is requested with `shouldCreateUser: false`, so this door never creates an account.
- Footer: "New here? Get started".

### SI2 · G4 Code
- Same component as GS2, with its own copy: "welcome back. enter the code we sent."
- It never says whether the number has an account (GI-34): the line reads "We've sent a code if this number has an
  account." with **Create an account** beside it.

After sign-in, the router decides: Today, or resume onboarding, teen wait, pro status, and so on.

---

## 5. Welcome back (signed out, opened before)

### WB1 · G5 Welcome back
- **"welcome back, Priya."** The "a" wakes up: eyes open slowly, then it smiles.
- Primary button, by last method:
  - phone → **Continue as +91 98•••••210** (sends the code straight away);
  - Google → **Continue with Google** showing `p•••@gmail.com`.
- Secondary: **Use another account** goes to SI1.
- Small: **Not you? Remove** clears the remembered account and shows Welcome.
- Footer: "New here? Get started".
- If the user was signed out by the system (GI-10), show the safety banner.

---

## 6. For doctors (pro mode)

Pro screens use **ink** as the main colour, with each partner type's colour as an accent:

| Partner type | Accent colour |
|---|---|
| doctors | ink `#0E0E0E` |
| pharmacy | pink `#FFB8E0` |
| labs | orange `#FF9F5A` |
| hospitals | blue `#A9D6FF` |

Same Kalighat pop base, calmer: no mascot jokes.

### PR0 · P1 Pro mode welcome
- The switch into ink: the screen settles into ink and the "a" puts on its stethoscope.
- **"care for patients, your way."** with **Join as a partner** and **Back to ApneDoctors**.
- The verified tick on the "a" appears only once an application is approved (PR5), never before.

### PR1 · P2 Who are you?
- **"join as a partner."**
- Four large choices: **Doctor**, **Pharmacy**, **Lab**, **Hospital or clinic**, each with one line on what they get.

### PR2 Sign in
- Phone or Google (the same components).
- One person, one account. A doctor can also be a patient; pro is a role added to that account.

### PR3 · P3 Your details (per type)
- **Doctor:**
  - full name as registered;
  - medical council (NMC or state);
  - registration number and year;
  - speciality;
  - HPR ID, optional (ABDM).
- **Pharmacy** (Q2):
  - store name;
  - drug licence numbers (Form 20 and 21);
  - GSTIN;
  - pharmacist registration number.
- **Lab:**
  - lab name;
  - licence or registration;
  - NABL number, optional.
- **Hospital or clinic:**
  - name;
  - HFR ID, optional;
  - registration number;
  - contact person.

### PR4 · P3 Documents
- Certificate, government ID and a selfie (camera or file; PDF, JPG or PNG up to 10 MB).
- Each file shows its own progress and retry.
- Files go to the private `pro-docs` bucket, in the person's own folder.

### PR5 · P4 Under review
- Timeline: Submitted → Checking → Approved.
- "We'll tell you as soon as it's done." Never promise a time we can't keep.
- **Needs changes:** the reason in plain words, and "Fix and resubmit" opens only the fields that need fixing.
- **Rejected:** the reason and how to appeal.
- Always offer: "Use ApneDoctors as a patient meanwhile".

---

## 7. From a hospital's QR

### HL1 · G18 Hospital landing
- Opened by scanning a hospital's QR (GI-19): the hospital's name and place, **Check in**, **I have a token already**.
- The same link works as a web page for people without the app (built with the website, not here).
- Check in signed out → GS1/SI1 with the hospital kept, then back to check-in.

### HL2 · G19 I have a token already
- Token from the desk + phone number, then follow the token live (queue position, called, done).

---

## 8. Edge cases (each needs handling and a test)

### Phone number
- **GI-20** Input with spaces, dashes, a leading 0, +91 or 91 → normalised to `+91XXXXXXXXXX`.
- **GI-21** Must be 10 digits starting 6–9. As soon as a number starts with 0–5: "Indian mobiles start with 6, 7, 8 or 9."
  (and "That doesn't look like an Indian mobile number." wherever a whole number is judged at once).
- **GI-22** Pasting a number with a country code or spaces → parsed correctly.
- **GI-23** International and premium-rate numbers are blocked (SMS fraud). India-only for the beta.
- **GI-24** Double-tapping Send code sends only one request.

### OTP
- **GI-25** Wrong code → the boxes shake, haptic: "That code didn't match. {n} tries left."
- **GI-26** Too many wrong codes or too many sends (server limits) → show the actual wait: "Too many tries. Try again in 12 minutes." Never a raw error.
- **GI-27** Code expired → "That code has expired." with a one-tap resend.
- **GI-28** SMS doesn't arrive → after 30 s show "Didn't get it?" with three options: resend, check the number, use Google.
- **GI-29** App killed or backgrounded on the code screen → reopening returns to the code screen with the number and the resend timer kept (`pendingPhone`, `otpResendAt`, 10-minute life).
- **GI-30** Back from the code screen → the phone screen with the number still filled.
- **GI-31** Change number → back to the phone screen, the old code is ignored.
- **GI-32** An old SMS autofilled after the number changed → ignored.

### Account exists or not
- **GI-33** Get started with a number that already has an account → after the code, sign in with "Welcome back! You already had an account, so we signed you in." No duplicate, no onboarding redo.
- **GI-34** I already have an account with any number → the code screen says "We've sent a code if this number has an account." with **Create an account** beside it (Get started with the number prefilled). The app never says whether a number is registered, and never reveals a role (doctor, pharmacy). Supabase rate-limits the sends.
- **GI-35** Google email already used by a phone account → link to the same user (Supabase identity linking), never a duplicate.
- **GI-36** Google sign-in cancelled → stay on the screen, no error.
- **GI-37** Google fails (no Play Services, network, misconfigured SHA-1) → "Google sign-in isn't working right now. Use your phone number instead."
- **GI-38** Account deleted earlier, signing up again → a fresh account; nothing old comes back.

### Age and teens
- **GI-40** Future, current or absurd birth year → friendly rejection. Age over 100 needs a confirm.
- **GI-41** Under 13 → See you at 13 with Childline 1098. Nothing is saved. The account is blocked for 24 h and the device for 7 days. Never hint which year would pass.
- **GI-42** Birth date is locked after saving. Changes go through support only.
- **GI-43** Parent number is the same as the teen's → "This needs to be your parent's own number."
- **GI-44** Parent link expired (7 days) or declined → GI-07 screen.
- **GI-45** Teen turns 18 while waiting → consent is no longer needed (a daily server job), with a "welcome to 18" moment.
- **GI-46** "Only know your age?" with an age under 18 → back to month and year; an estimate never decides a teen's or child's path.

### Sessions and devices
- **GI-50** Sign out → clears the session, cache and push token binding. Remembers the account for Welcome back unless the user chooses "Sign out and forget me".
- **GI-51** Sign out while offline → clear locally now, revoke on the server when back online.
- **GI-52** Two people share one phone → "Not you?" fully clears the remembered account. The push token re-registers on every sign-in, so A's notifications never reach B.
- **GI-53** Signed in on a new phone → the old phone stays signed in (no surprise sign-outs), unless the user signs out of all devices from Settings.
- **GI-54** The device clock is wrong → codes and sessions rely on server time, never device time.

### The phone itself
- **GI-60** Text size up to 200% → no clipping. Headlines wrap, buttons grow taller, screens scroll.
- **GI-61** Screen reader → every control labelled. The "a" is decorative except where it means something. The code boxes read as one field.
- **GI-62** Reduced motion → no splash writing animation and no confetti; cross-fades only.
- **GI-63** Small screen (360×640) and keyboard open → the primary button stays visible above the keyboard. Nothing hides under it.
- **GI-64** Android back on Welcome → leaves the app. On every other screen → the previous step, keeping what was typed.
- **GI-65** Portrait only. Light theme only for now (the paper look); dark mode is a later decision.
- **GI-66** Poor network → every call has a timeout and a retry. Spinners never run forever. After 10 s: "This is taking longer than usual." with Retry.
- **GI-67** Server or Supabase down → "We can't reach ApneDoctors right now. Try again in a minute."

### Hospital QR
- **GI-70** A QR for a hospital we don't know, or one no longer on ApneDoctors → "We couldn't find this hospital. Ask at the desk." No crash.
- **GI-71** Token not found or for another day → "We couldn't find that token. Check it with the desk."

---

## 9. Backend work (Supabase project `yljfnbudjdijwjshqaba`)

- Clean new migrations in `supabase/migrations/` (append-only), with none of the old game columns (xp, streaks, buddy,
  handle, goals). The old project's `profiles`, `pro_applications` and age rules are the reference for the rules,
  not for the schema.
- Tables and functions (each with RLS, explicit grants and tests in `supabase/tests/test_database.py`):
  - `profiles`: names, gender, birth year and month (or an estimated year), age band, parent consent status,
    onboarding step, account status, last mode, First-time home seen;
  - `consents`: user, purpose, notice version, granted at, withdrawn at;
  - `parent_consent_requests`: teen, parent phone, status, expiry (7 days), resend wait;
  - the under-13 account block (24 h);
  - `pro_applications`, `pro_documents`, `user_roles`, the private `pro-docs` bucket (10 MB, PDF/JPG/PNG, own folder);
  - `app_requirements()` (minimum app version) and `my_launch_state()` (everything the router needs, one call).
- Clients never write age, consent status, roles or pro status directly. They call `security definer` RPCs that check
  the rules; internal functions are revoked from `public, anon, authenticated`.
- Auth providers:
  - **Phone (SMS).** On, with Supabase **test phone numbers** (fixed codes, no SMS sent, free) for development. The
    numbers are in `memory.md`; the codes are never committed.
    - Real SMS in India costs money and needs DLT registration (sender ID and template, TRAI rules). **Ask the founder before setting up any paid SMS provider.**
  - **Google.** Native `google_sign_in`, then `signInWithIdToken`. Needs the iOS client ID, the web client ID, the Android SHA-1 and SHA-256 of the debug and release keys, and a Supabase provider config. The founder sends the keys; never commit secrets.
- Don't deploy migrations or change auth config without asking.

---

## 10. Build notes (Flutter)

- go_router with one redirect that calls `decideLaunch`. Riverpod for state. supabase_flutter for auth. flutter_secure_storage for the session and the remembered account; shared_preferences for harmless flags.
- `smart_auth` or `sms_autofill` for the Android SMS User Consent API.
- Shared widgets:
  - `PhoneField`, `OtpBoxes`, `GoogleButton`, `PrimaryButton`;
  - `LivingA` (the logo character with moods: listening, happy, waking, asleep, celebrating, worried; built with CustomPainter);
  - `KpScaffold` (paper, margins, keyboard-safe bottom area).
- Every screen gets:
  - a widget test for its states (empty, invalid, loading, error, success);
  - golden tests at 360×640 and 390×844, with text at 100% and 200%.
- `decideLaunch` gets a table-driven unit test covering GI-01 to GI-19.
- One integration test per path (Get started, Sign in, Welcome back, pro sign-up), using Supabase test phone numbers.
- Copy: short, friendly, lowercase headlines as on Welcome, sentence case elsewhere. Errors always say what to do next. No emoji; draw icons.
