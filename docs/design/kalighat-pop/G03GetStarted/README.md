# G03 Get started (GS1 · G3 Sign up)

The screen after Welcome's "Get started". **A reference, not a spec** (founder, 2026-11-26: "just a reference … it has
lots of issues … make it the best"). The app keeps its content, states and flow and improves the design; see
`docs/product/specs/getting-in.md` (GS1) for what was built.
Source: Design canvas "ApneDoctors: Get started" (https://claude.ai/artifact/UeejZSbcyme8LKSX759ecM).

| File | State |
|---|---|
| `Main.dc.html` | Interactive: type a number (entrance, typing, wrong, ready, sending, sent) |
| `Typing.dc.html` | Typing, keyboard open, 4 digits to go |
| `Ready.dc.html` | 10 valid digits: tick, happy "a", Send code ready |
| `WrongNumber.dc.html` | Starts with 0–5: worried "a", red field, message |
| `Sending.dc.html` | Sending: field locked, "a" looks up, Google off |
| `Offline.dc.html` | Offline strip, both buttons off |
| `SmallPhone.dc.html` | 360×640 with the keyboard open: compact layout, the "a" in the top bar |

Shared styles: `../kp.css` (identical copy). `canvas.json` holds the canvas layout and the Flutter build note.
What the app does differently: the number field (painted dot slots that become digits), body-size help text, an
offline pill instead of a strip that moves the page, animated mood and layout changes, and the walk through Welcome's
doorway on the way in.
