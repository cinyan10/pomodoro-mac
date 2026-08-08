# Pomodoro

A tiny native macOS menu bar Pomodoro timer.

## Build

```sh
swift build
```

To build a `.app` bundle:

```sh
bash scripts/build-app.sh
```

## Run

```sh
swift run Pomodoro
```

Or, after building the app bundle:

```sh
open dist/Pomodoro.app
```

## Controls

- `Control + F19`: start a 25-minute focus session.
- `Option + F19`: start a 5-minute rest session.
- `Command + F19`: stop the active session.
- Click the menu bar item to see the detailed timer and quit.
- Choose and preview a session-end sound from the menu bar item's `Session Sound` submenu.
- Use the app window buttons if macOS or a keyboard utility captures a shortcut.

Focus mode shows a white timer icon without focus time in the menu bar. Rest mode shows a white timer icon with green rest time remaining. When a timer ends, the app plays the selected session sound and posts a macOS notification.
