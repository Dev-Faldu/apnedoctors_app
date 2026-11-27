# ApneDoctors: screens

The full patient screen list (by journey step, with IDs) is the founder's private Claude Doc. This file
tracks what is built in this repo. `[x]` built · `[ ]` to build.

## Patient app

### Getting in
- [x] App icon (vermilion "a" with ink eyes on paper)
- [x] Native splash (paper, the "a" at scale 1)
- [x] Opening: splash with alpana, the name writing itself (`N00Splash`)
- [x] Hand-off into Welcome (`N00Splash`)
- [x] Welcome (`N01Welcome`)
- [x] GS1 · G3 Get started: your phone number (`G03GetStarted`, reference)
- [x] GS2 · G4 Code (`G04Code`, reference)
- [x] GS3 · G7 About you: name, birth month and year or age, gender (`G05AboutYou`, reference); saving waits on the
      migration deploy
- [x] G12 See you at 13 (in About you, and at launch while this phone is locked)
- [ ] Google sign-in (keys from the founder)
- [ ] GS4 · G11 Parent consent, GS5 · G10 Your data, and the rest of onboarding
- [ ] Sign in (returning): phone number or Google
