# PPTA Privacy Policy

**Effective date:** 9/22/2026
**Last updated:** 9/22/2026

---

## 1. Who we are

PPTA ("Peer Pressure The App", "we", "us") is an iOS app for peer accountability around screen
time. It is operated by Damien Koh.

This policy explains what data PPTA collects, why, who can see it, and what control you have
over it.

**The most important thing to understand about PPTA:** the app is built to share your screen time
behavior with specific people you choose. That sharing is the product, not a side effect. Section 4
explains exactly what those people see.

---

## 2. Who this policy is for

PPTA is intended for users aged 13 and over.

PPTA is often used between parents and children, but the app has no separate child account type,
no parental-consent flow, and no age verification. Every account is a regular peer account. If you
are under 13, do not create an account. If you believe a child under 13 has created an account,
contact us at peerpressuretheapp@gmail.com and we will delete it.

---

## 3. What we collect

### 3.1 Account information

Collected when you sign up, and required to use the app:

| Data | Why |
|---|---|
| Name | Shown to your friends, coaches, and trainees |
| Email address | Account identity and sign-in |
| Phone number | So people who have your number in their contacts can find you |
| Profile photo *(optional)* | Shown on your profile and to your friends |

If you sign in with Apple or Google, we receive your name and email address from that provider.
We do not receive your password. If you use Sign in with Apple's private relay, we only ever see
the relay address.

Your phone number is stored as a 10-digit US number. PPTA does not currently support international
phone formats.

### 3.2 Screen time and app limits

PPTA uses Apple's Screen Time frameworks (Family Controls, Device Activity, Managed Settings).
This is worth reading carefully, because two different kinds of data are involved.

**What stays private to your device.** When you choose which apps to monitor, iOS gives PPTA an
opaque token for each app — not a name, not a bundle ID. These tokens are meaningless outside your
device and cannot be read by us or by anyone else. Your actual minute-by-minute usage data is
computed on your device by iOS and is never transmitted to us. We cannot see your total screen
time, what you use, or when.

**What we do store:**

| Data | Why |
|---|---|
| Your daily time limit | Enforcement; shown to your coaches |
| Your pressure level (Off / Standard / Hardcore) | Enforcement; shown to your coaches |
| Your current status (within limit / limit reached / locked / snoozed) | Shown to your coaches |
| The date you last changed your limits | Powers your Commitment Streak |
| Which coach locked you, and their name | Shown to you and to your coaches |
| Which coaches you have asked to snooze a lock | So that coach sees the request |
| The opaque app tokens described above | So the app can enforce your limits |

**Names of apps that blocked you.** When you open an app that PPTA has locked, iOS shows you a
PPTA lock screen. That lock screen is the only part of PPTA that is allowed to read the app's real
name. When it appears, PPTA records the app's name and counts that block. Those names, and a
30-day count per app, are stored and **shown to your coaches**.

This means: your coaches can see that you tried to open Instagram 14 times in the last month. They
can only see this for apps you have actually been blocked from — apps you never hit a lock screen
for are never named.

### 3.3 Contacts

If you grant contacts permission, PPTA reads the names and phone numbers in your address book to
find which of your contacts already use PPTA.

**We do not upload or store your address book.** Phone numbers are normalized on your device and
sent to our database as a lookup query to check for matches. The numbers are used to run that
query and are not written to any database or retained by us. Contacts who do not use PPTA are
listed for you on-device so you can invite them, and nothing about them is sent anywhere.

You can use PPTA without granting contacts access; you would then add friends by typing their
phone number.

### 3.4 Notifications

PPTA registers your device with Apple's push notification service and Firebase Cloud Messaging.
We store the resulting device token so we can send you notifications, and so your coaches'
actions can reach your device.

PPTA registers for push notifications even if you decline notification permission, because Apple's
phone-number verification requires a silent push to work. Declining notification permission means
you will not see any alerts.

### 3.5 Reinstall detection

PPTA stores a marker in your device's Keychain containing your user ID. Unlike normal app storage,
the Keychain survives app deletion. If you delete PPTA and reinstall it while signed into the same
account, we detect this and **notify your coaches that you reinstalled the app.**

This exists because deleting the app is the simplest way to escape a lock, and accountability is
the point of the product. The marker is per-device, never syncs to iCloud, and contains nothing
but your user ID.

### 3.6 What we do not collect

PPTA does not collect location data, advertising identifiers, browsing history, health data,
contacts of contacts, or the contents of anything you type outside the app. We do not use
analytics or advertising SDKs. We do not sell data.

---

## 4. What other people can see

This is the section that matters most.

### 4.1 Your coaches

Anyone you accept as a coach can see:

- Your name and profile photo
- Your current status: within your limit, limit reached, locked, or snoozed
- Your daily time limit and pressure level
- Your Commitment Streak
-  Which coach locked you, if you are locked
- Whether you have asked them to snooze your lock

Your coaches also receive push notifications when:

- You reach your daily limit
- You are locked, by them, by another coach, or automatically
- A snooze they granted you expires
- You change your app limits or pressure level
- You delete and reinstall the app

**Your coaches can lock your selected apps remotely, at any time, without warning.** In Hardcore
mode, your apps also lock automatically when you hit your limit.

### 4.2 Your trainees

You see the same information about anyone who has accepted you as their coach, and you can lock
and snooze their apps.

### 4.3 Your friends

Friends who are not coaches or trainees see your name, profile photo, and whether a request between
you is pending. They do not see your status, limits, streak, or app names.

### 4.4 Leaving a relationship

You can end a coach or trainee relationship at any time, and you can unfriend anyone. Once a
relationship ends, that person stops receiving your updates and no longer sees your status.
Notifications they already received are not recalled.

---

## 5. Who we share data with

We do not sell your data and we do not share it for advertising. We use the following service
providers, who process data on our behalf:

| Provider | What they handle |
|---|---|
| **Google Firebase** (Authentication, Firestore, Cloud Storage, Cloud Messaging) | Account records, app settings, friend and role relationships, profile photos, push delivery |
| **Google Cloud Run** | Our backend functions: locking, unlocking, status updates, role requests, account deletion |
| **Apple** | Sign in with Apple, push notification delivery, the Screen Time frameworks |

Google's handling of this data is governed by Google's privacy policy; Apple's by Apple's.

We may also disclose data if required by law, or to protect the rights or safety of our users.

---

## 6. How data is protected

- All communication with our backend uses HTTPS.
- Lock, unlock, and status requests are signed with HMAC-SHA256, so a third party cannot forge a
  lock or unlock against your account.
- Account deletion requires your authenticated identity and runs server-side.
- Your Screen Time usage data never leaves your device.

No system is perfectly secure, and we cannot guarantee absolute security.

---

## 7. Retention and deletion

We keep your data for as long as your account exists.

**You can delete your account from within the app** (Settings → Delete Account). Deletion is
permanent and removes:

- Your user record and app settings
- Your profile photo
- Your friendships and coach/trainee relationships, including the references to you held in other
  users' accounts
- Your pending and past role requests
- Your sign-in credentials

Some data may persist briefly in backups after deletion. Notifications already delivered to other
people's devices cannot be recalled.

---

## 8. Your rights

Depending on where you live, you may have the right to access, correct, export, or delete your
personal data, to object to or restrict processing, and to withdraw consent.

You can exercise most of these directly in the app: edit your profile in Settings, revoke contacts
or notification permissions in iOS Settings, and delete your account from Settings. For anything
else, contact us at peerpressuretheapp@gmail.com and we will respond within 30 days.

If you are in the EEA or UK, our legal basis for processing is the performance of our contract with
you (running the account and its accountability features), your consent (contacts and notification
access), and our legitimate interest in keeping the service working and secure.

If you are in California, we do not sell or share personal information as those terms are defined
under the CCPA, and we will not discriminate against you for exercising your rights.

---

## 9. Changes to this policy

We may update this policy as the app changes. If we make a material change — particularly one that
widens what your coaches can see — we will notify you in the app before it takes effect. The
"last updated" date above always reflects the current version.

---

## 10. Contact

Questions about this policy or your data:

peerpressuretheapp@gmail.com
