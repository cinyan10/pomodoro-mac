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

- `Control + F16`: start a 25-minute focus session.
- `Control + F17`: start a 5-minute rest session.
- `Control + F18`: stop the active session.
- Click the menu bar item to see the detailed timer and quit.
- Use the app window buttons if macOS or a keyboard utility captures a shortcut.

Focus mode shows a white timer icon without focus time in the menu bar. Rest mode shows a white timer icon with green rest time remaining. When a timer ends, the app plays the default system sound and posts a macOS notification.
