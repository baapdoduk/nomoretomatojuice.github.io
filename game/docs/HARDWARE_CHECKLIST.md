# DualShock 4 Hardware Checklist (macOS)

Automated tests run headless without a gamepad, so **everything below must be checked by hand**
on the real target: macOS (M4 MacBook Air) + DualShock 4. Do the whole list over **USB first**,
then repeat it over **Bluetooth** (System Settings > Bluetooth; hold PS + Share until the light bar
flashes to pair). Fill in the tables at the end.

Rule: a feature that turns out to be unsupported must never block progression. Vibration, light bar,
motion sensors and touchpad are optional extras; every gameplay action also works on the keyboard.

## 0. Setup

1. Open `game/project.godot` in Godot 4.7.2 and press F5 (main scene = Test Hub).
2. Connect the DS4. The hub status line (bottom) must change from `Controller: none (keyboard)`
   to `Controller: <name> (device N)`. Note the name: ______________________
3. In the hub, navigate with the D-pad and the left stick, select with Cross. Open the pause menu
   with Options. If Cross does not select, report it (see "Known limitations").

## 1. Controller Lab - mapping (Hub > Controller Lab)

The lab reads the pad but is controlled from the **keyboard** (Tab = next page, Backspace = hub).

Page 1 "Buttons & sticks": every cell shows `index name`. Hold each button and write down which
index lights up (and check the "Last raw pad events" line). Expected SDL layout:

| Physical button | Expected index | Lit index (USB) | Lit index (BT) |
|---|---|---|---|
| Cross | 0 | | |
| Circle | 1 | | |
| Square | 2 | | |
| Triangle | 3 | | |
| Share | 4 | | |
| PS | 5 | | |
| Options | 6 | | |
| L3 | 7 | | |
| R3 | 8 | | |
| L1 | 9 | | |
| R1 | 10 | | |
| D-Up / Down / Left / Right | 11 / 12 / 13 / 14 | | |
| Touchpad click | 20 | | |
| L2 / R2 (digital, if any) | (none expected) | | |

Note: macOS may open Launchpad / Game Center overlays on the PS button - that is OS behaviour.

## 2. Sticks, dead-zone, triggers (page 1)

1. Move the left stick fully in a circle: the grey dot (raw) reaches the outer ring; the yellow dot
   (`Input.get_vector` of the move actions) stays at the centre inside the red dead-zone circle.
2. Release the stick: raw values should return to about 0.00 (note drift: ______).
3. Repeat for the right stick (processed with the same radial dead-zone).
4. Pause menu (Esc / Options) > Settings > Stick dead-zone: change it (0.05 - 0.60) and confirm the
   red circle changes size and small movements are ignored/accepted accordingly.
5. Press L2 / R2 slowly: bars fill 0 -> 1 smoothly; `context_left/right` strengths follow.
   Raw axes: L2 = a4, R2 = a5 (expected).

## 3. Gameplay actions (page 2 "Actions & devices")

Press each and confirm `PRESSED = YES` and strength 1.00 (triggers: analog):
`move_left/right/up/down` (stick + D-pad), `jump` (Cross), `dash` (Circle), `attack` (Square),
`interact` (Triangle), `context_left` (L2), `context_right` (R2), `pause` (Options).
Also check the device section (name, GUID, known mapping = yes, `get_joy_info` fields).

Then in **each lab** (Side-View, Top-Down, Combat, Puzzle, Integration) play for a minute with the pad:
move, jump, dash, attack, interact, use L2/R2 context actions, open/close the pause menu, use
"Restart from checkpoint", "Restart chapter" and "Return to hub". Note anything that feels wrong.

## 4. Pause menu / Options

1. Options opens the menu, the game freezes, any running vibration stops.
2. Navigate with D-pad and left stick, select with Cross, back with Circle or Options.
3. Settings: vibration on/off, strength, dead-zone, assist combat timing, assist context actions.
   Each change applies immediately (vibration change gives a short "ui" rumble).
4. "Restart from checkpoint" counts as a death (death counter / assist tip) - by design.

## 5. Disconnect / reconnect

1. In a lab with gameplay (not the hub / Controller Lab), unplug the USB cable (or turn the pad off:
   hold PS ~10 s for Bluetooth).
2. Expected: game auto-pauses with "Controller disconnected. Reconnect it, or press any key to
   continue with keyboard."
3. Press a keyboard key: game resumes with keyboard prompts.
4. Repeat, but reconnect instead: the overlay shows "Controller connected: <name>"; press any pad
   button (or Resume) to continue. Pad works again without restarting.
5. In the hub / Controller Lab a disconnect only shows a toast and the status line updates.
   Controller Lab page 2 logs connect/disconnect events.

## 6. Vibration (page 3 "Feedback & support")

Keys: `1` weak, `2` strong, `3` both, `4` stop (through InputFeedback, honours the settings);
`5` weak, `6` strong, `7` both, `0` stop (raw `Input.start_joy_vibration`, ignores settings).
Check: weak = high-frequency right motor, strong = low-frequency left motor, both, stop works,
disabling vibration in Settings silences 1-3 but not 5-7. In combat labs, hits / damage rumble.

## 7. Light bar, motion, touchpad (page 3)

1. `L`: cycles the light bar colour (red, green, blue, orange, magenta, white). The line
   "Last test" says `sent` or `not supported`.
2. `M`: toggles motion sensors. Tilt / rotate the pad: gyro / accel / gravity values change.
   `C`: start calibration (pad flat and still), `C` again to stop.
3. Click the touchpad: "Touchpad click: PRESSED" and the support table shows "seen".
   Touchpad coordinates and the DS4 speaker are not available in Godot (out of scope).

## 8. Results

Fill in Supported / Not supported / Untested. The Controller Lab page 3 shows the automatic
columns ("API in build", "device reports"); copy them here and add your hardware result.

| Feature | API in build | Device reports (USB) | macOS HW result USB | Device reports (BT) | macOS HW result BT |
|---|---|---|---|---|---|
| Button mapping (section 1) | yes | - | Untested | - | Untested |
| Sticks + dead-zone | yes | - | Untested | - | Untested |
| L2 / R2 analog | yes | - | Untested | - | Untested |
| All gameplay actions | yes | - | Untested | - | Untested |
| Pause / Options | yes | - | Untested | - | Untested |
| Disconnect / reconnect | yes | - | Untested | - | Untested |
| Vibration weak | | | Untested | | Untested |
| Vibration strong | | | Untested | | Untested |
| Light bar colour | | | Untested | | Untested |
| Gyro / accelerometer | | | Untested | | Untested |
| Motion calibration | | | Untested | | Untested |
| Touchpad click | yes | - | Untested | - | Untested |
| Touchpad coordinates | no | n/a | Not supported | n/a | Not supported |
| DS4 speaker | no | n/a | Not supported (out of scope) | n/a | Not supported |

## Known limitations

- Godot 4.7's default `ui_accept` / `ui_cancel` have no joypad events. The PauseMenu bridges
  Cross -> ui_accept and Circle -> ui_cancel while a menu control has focus. If menus still do not
  react to Cross, report it.
- Unsupported features must degrade silently (no errors, no blocked progress). Report any crash.
