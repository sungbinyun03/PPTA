# Firestore rules

`firestore.rules` is the source of truth. Tests run against the local emulator only (project `demo-ppta`).
Needs a JDK: `brew install openjdk@21`, then `PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH" npm test`.
First time: `npm install`. Run from this folder.
Deploy: paste `firestore.rules` into Firebase console > Firestore > Rules > Publish. Nothing here deploys.
