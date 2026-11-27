# G04 Code (GS2 · G4)

The screen after Send code. **A reference, not a spec** (founder, 2026-11-26: "just a reference … make design very
nice"). The app keeps its content, states and flow and designs them its own way; see
`docs/product/specs/getting-in.md` (GS2) for what was built.
Source: Design canvas "ApneDoctors: Get started" (https://claude.ai/artifact/UeejZSbcyme8LKSX759ecM).

| File | State |
|---|---|
| `Code.dc.html` | Interactive (482913 works there) |
| `CodeAutofill.dc.html` | Waiting, the code suggested above the keyboard |
| `CodeChecking.dc.html` | Checking |
| `CodeWrong.dc.html` | Wrong code |
| `CodeNoSms.dc.html` | Didn't get it? (after 30 s) |
| `CodeTooMany.dc.html` | Too many tries |
| `CodeExpired.dc.html` | Code expired |
| `CodeVerified.dc.html` | Verified |
| `CodeSmallPhone.dc.html` | 360×640 with the keyboard open |

What the app does differently: the move from the phone screen (the number flies up, the a stays seated), painted
tiles that match the number field, a celebration when verified (green ripple, the a jumps, marigold petals), a
"Send a new code" pill and the help card's live countdown, and body-size text throughout.
