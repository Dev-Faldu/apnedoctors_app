# G05 About you (GS3 · G7, and G12 See you at 13)

The screens after the code is verified. **A reference, not a spec** (founder, 2026-11-26: "just a reference … make
design very nice"; 2026-11-27: "make it amazing … take reference and design it"). The app keeps their content, states
and flow and designs them its own way; see `docs/product/specs/getting-in.md` (GS3, G12) for what was built.
Source: Design canvas "ApneDoctors: Get started" (https://claude.ai/artifact/UeejZSbcyme8LKSX759ecM).

| File | State |
|---|---|
| `AboutYou.dc.html` | Interactive: the whole flow |
| `AboutName.dc.html` | "what should we call you?", empty |
| `AboutNameTyped.dc.html` | A name typed: the bubble says it back |
| `AboutBirthday.dc.html` | The month and year wheel, "That makes you 22." |
| `AboutAgeOnly.dc.html` | "Only know your age?" (adults) |
| `AboutConfirm.dc.html` | "born in March 2004?" sheet |
| `AboutGender.dc.html` | "which fits you best?" |
| `AboutUnder13.dc.html` | See you at 13, Childline 1098 |
| `AboutSmallPhone.dc.html` | 360×640 with the keyboard open |

What the app does differently:
- The a keeps its seat from the code screen and hosts every step; its bubble says "namaste!" and then your name as you
  type it, and with the keyboard open the a and its bubble glide up into the top bar.
- Labels sit inside the name fields, so both names and Continue fit above the keyboard on a 360×640 phone.
- Continue is docked in one place for every step (above the keyboard when it is open).
- The wheel's chosen row is a vermilion band with a painted white dot border; the age under it rolls.
- The a hops down onto the confirm sheet and back.
- The chosen gender gets a painted dot border in one sweep; the board's order is kept (name, birthday, gender), so a
  child is stopped before being asked anything else.
- Saved: "nice to meet you, Priya!", marigold petals and a card of what you told us (the birth date with a lock).
- See you at 13 has no button to carry on: the Childline card is the one thing to tap (it calls 1098).
