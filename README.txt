PLANNER
Your whole week on your Mac's desktop.

Created by Victor Tognollo · Free forever (see LICENSE.txt)
Version 1.0 · macOS 14 (Sonoma) or later · Mac with Apple silicon or Intel
Languages: English and Portuguese (⋯ > Language)

The illustrated step-by-step guide is in "Installation Guide.pdf".
Em português: "Guia de instalação.pdf" e LEIA-ME.txt.


HOW TO INSTALL

1. Drag Planner.app to your Applications folder.

2. Open Planner from Applications.
   macOS warns that it can't verify the app, because it doesn't come from the
   App Store. Click "Done".

3. Open System Settings > Privacy & Security, scroll down to Security and click
   "Open Anyway" next to Planner. Confirm with your password or Touch ID and
   click "Open Anyway" again.

4. When Planner asks to send notifications, click "Allow".

That's it. Planner shows up at the bottom of the screen and opens by itself
whenever your Mac starts.

Shortcut for step 3 (optional): in the Terminal app, paste this line and press Return.
xattr -dr com.apple.quarantine /Applications/Planner.app


HOW TO USE

- Move: drag the top strip, where the month is. Resize from the edges.
- Add: click the + on any day (task, meeting with a link, or reminder with a time).
- Edit: double-click an item's text, or right-click it.
- Calendars: calendar button at the top > "Sync with your Mac calendars".
  For Google Calendar, sign in under System Settings > Internet Accounts.
- Settings: the ⋯ button on the right (language, horizontal or vertical layout,
  text size, position on screen, open at login).

Your tasks are stored only on this Mac, in ~/Library/Application Support/Planner.

To uninstall: ⋯ > Quit Planner, then drag Planner.app to the Trash.
