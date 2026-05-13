# Textream iOS Device Test Checklist

## Purpose

This checklist is for validating the current **iOS MVP teleprompter implementation** on real devices.

It focuses on:
- installation and first-launch behavior
- editor and local document workflow
- Classic mode
- Voice-Activated mode
- Word Tracking mode
- state restoration and interruption handling
- identifying release-blocking bugs early

---

## 0. Test setup

### Required environment
- [ ] Xcode has the required iOS platform installed
- [ ] Device runs **iOS 17+**
- [ ] App installs successfully on device
- [ ] First test run starts from a clean app state
- [ ] At least one iPhone is available
- [ ] Optional: one iPad for large-screen validation

### Recommended test scripts

#### A. Short English script

```text
Welcome to Textream on iPhone. This is a short script for testing classic mode, voice-activated mode, and word tracking.
```

#### B. Chinese script

```text
欢迎使用 Textream 的 iOS 版本。这个测试文稿用于验证中文分词、自动滚动、语音驱动滚动，以及逐词跟读能力。请保持正常语速朗读，观察高亮、进度和翻页行为是否符合预期。
```

#### C. Multi-page script

Page 1:

```text
This is page one. Read to the end and then switch to the next page.
```

Page 2:

```text
This is page two. Verify page switching and state reset behavior.
```

---

## 1. Install and first launch

### Basic launch
- [ ] App opens successfully
- [ ] Home / Editor screen renders correctly
- [ ] No crash on startup
- [ ] Title field, page list, editor, mode picker, and Start Reading button are visible

### First-time permissions
#### Triggered by Voice-Activated / Word Tracking
- [ ] Microphone permission prompt appears when expected
- [ ] Speech recognition permission prompt appears when expected
- [ ] Allowing permission continues the flow normally
- [ ] Denying permission shows a clear error state
- [ ] App does not crash when permission is denied

---

## 2. Editor and document basics

### Text editing
- [ ] User can type text
- [ ] User can paste text
- [ ] Edited content remains on the current page
- [ ] Switching pages and returning does not lose content

### Page management
- [ ] Add page works
- [ ] Delete current page works
- [ ] At least one page always remains
- [ ] Current page selection updates correctly
- [ ] Selected page highlight is correct

### Title and documents
- [ ] Changing title affects save behavior correctly
- [ ] New document resets to a clean state
- [ ] Opening a saved document restores title and content
- [ ] Deleting a document updates the list correctly

---

## 3. Classic mode

### Launch and reading flow
- [ ] Select `Classic`
- [ ] Tap `Start Reading` to enter Reader
- [ ] Text advances automatically
- [ ] Current word / highlight moves with progress

### Controls
- [ ] Pause works
- [ ] Resume works
- [ ] Slider changes progress
- [ ] Tapping a word jumps to that position
- [ ] Previous page works
- [ ] Next page works
- [ ] Returning to Home does not crash

### Expected result
- [ ] Works without microphone permissions
- [ ] Progress percentage updates reasonably
- [ ] Page switch starts from the beginning of the next page
- [ ] No stale state from previous page remains

---

## 4. Voice-Activated mode

### Permissions
- [ ] First entry requests microphone permission
- [ ] Denied permission shows a clear message
- [ ] Allowed permission enables mic state correctly

### Core behavior
- [ ] Select `Voice-Activated`
- [ ] Reader does not advance while silent
- [ ] Reader advances while speaking
- [ ] Reader mostly stops when speech stops
- [ ] Mic toggle stops listening
- [ ] Mic toggle resumes listening

### Waveform and status card
- [ ] Waveform reacts to voice
- [ ] Speaking state message is reasonable
- [ ] Silence state message is reasonable
- [ ] Mic on/off indicator matches actual behavior

### Edge cases
- [ ] Very quiet speech does not trigger excessively
- [ ] Normal environmental noise does not cause heavy false scrolling
- [ ] Rapid mic toggle does not crash
- [ ] Page switch restores listening state reasonably

### Expected result
- [ ] Scrolling mostly tracks actual speech activity
- [ ] No persistent false-positive scrolling
- [ ] Mic off should not continue advancing

---

## 5. Word Tracking mode

This is the **highest-risk path** in the current MVP.

### Permissions
- [ ] Requests microphone permission when needed
- [ ] Requests speech recognition permission when needed
- [ ] Denying either permission shows clear error feedback

### Reading progression
- [ ] Select `Word Tracking`
- [ ] Speaking advances highlight position
- [ ] Highlight position looks consistent with spoken text
- [ ] Current word roughly tracks what is being spoken
- [ ] Small pauses do not cause large jumps
- [ ] Continuing after a pause resumes correctly

### Interaction
- [ ] Tapping a word jumps recognition progress near that word
- [ ] Slider drag changes tracked position
- [ ] Turning mic off stops recognition
- [ ] Turning mic back on resumes from current position, not from the beginning
- [ ] Switching to next page starts recognition on the new page

### Speech quality scenarios
- [ ] Normal speaking speed
- [ ] Fast speaking speed
- [ ] Slow speaking speed
- [ ] Small mistakes / substitutions
- [ ] Skipping one or two words
- [ ] Repeating a phrase

### Language coverage
- [ ] English
- [ ] Chinese
- [ ] Optional: one additional supported language

### Expected result
- [ ] No frequent large false-positive jumps
- [ ] No total freeze where progress never moves
- [ ] Resuming mic should not reset progress unexpectedly
- [ ] Chinese should at least progress forward in a mostly sensible way

---

## 6. Document storage

### Save
- [ ] New script can be saved
- [ ] First save creates a `.textream` document
- [ ] Re-saving updates the current document
- [ ] Same-title saves do not overwrite the wrong document unexpectedly

### Open
- [ ] Saved Scripts list shows correct documents
- [ ] Tapping a document opens it
- [ ] Opened title and content are correct
- [ ] Opened document can immediately be used in Reader

### Delete
- [ ] Swipe delete works
- [ ] List refreshes after delete
- [ ] Deleting the currently opened document leaves app state in a reasonable condition

### Relaunch persistence
- [ ] Quit app and relaunch
- [ ] Saved documents still exist
- [ ] Saved documents can be reopened

---

## 7. State restoration and mode switching

### Mode switching on Home
- [ ] Classic → Voice-Activated
- [ ] Voice-Activated → Word Tracking
- [ ] Word Tracking → Classic

After each mode switch:
- [ ] Mode description updates correctly
- [ ] Start Reading launches the selected mode
- [ ] Old mode state is not incorrectly reused

### Reader state recovery
- [ ] Switching pages resets progress correctly
- [ ] Page switch does not keep stale highlight from the old page
- [ ] Exiting Reader and re-entering does not keep stale mic / recognition state
- [ ] New document does not inherit previous document state

---

## 8. Interruptions and system behavior

### Background / foreground
- [ ] Enter Reader, then send app to background
- [ ] Return to foreground without crash
- [ ] State restores reasonably

### System interruptions
If possible, simulate:
- [ ] Lock and unlock device
- [ ] Open and close Control Center
- [ ] Notification interruption
- [ ] Headphone / Bluetooth route change

Watch for:
- [ ] incorrect mic state
- [ ] speech recognition stopping without feedback
- [ ] hangs or crashes

---

## 9. UI and readability

### Reading experience
- [ ] Font size is large enough
- [ ] Highlight is obvious
- [ ] Read vs unread contrast is clear
- [ ] Dark theme remains readable
- [ ] Long scripts feel smooth enough

### Small-screen experience (iPhone)
- [ ] Controls are not cramped
- [ ] Page switching feels easy
- [ ] Slider is usable

### Large-screen experience (iPad)
- [ ] Layout is not awkwardly sparse
- [ ] Text width feels reasonable
- [ ] Editing experience is comfortable

---

## 10. Release-blocking bug criteria

Any of the following should be considered **P1**:
- [ ] Crash on app launch
- [ ] Crash when entering Reader
- [ ] Crash during save/open/delete
- [ ] Microphone permission cannot be requested in Voice-Activated
- [ ] Speech recognition permission cannot be requested in Word Tracking
- [ ] Word Tracking never advances
- [ ] Word Tracking jumps wildly and frequently
- [ ] Page switching corrupts state
- [ ] Mic / recognition remains active after leaving Reader
- [ ] Saved content is lost or corrupted

---

## 11. Recommended execution order

Run tests in this order:
1. [ ] Install / first launch
2. [ ] Editor basics
3. [ ] Save / open documents
4. [ ] Classic mode
5. [ ] Voice-Activated mode
6. [ ] Word Tracking mode
7. [ ] Mode switching / state restoration
8. [ ] Background / interruptions
9. [ ] iPad pass if available

---

## 12. Test report template

```text
Device:
OS version:
Build version:

[Classic]
- Pass/Fail:
- Notes:

[Voice-Activated]
- Pass/Fail:
- Notes:

[Word Tracking]
- Pass/Fail:
- Notes:

[Documents]
- Pass/Fail:
- Notes:

[State restore]
- Pass/Fail:
- Notes:

[P1/P2 Bug List]
- ...
```

---

## Suggested follow-up after testing

After running this checklist, classify issues into:
- **P1**: must fix before wider testing
- **P2**: usability or reliability issue
- **P3**: polish / follow-up enhancement

Recommended next step after first real-device pass:
1. fix all P1 issues,
2. re-run core flows,
3. then decide whether to add:
   - `UIDocumentPicker`
   - structured document persistence
   - further macOS/iOS matcher unification
