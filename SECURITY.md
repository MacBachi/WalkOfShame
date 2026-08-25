# Security and safety

## Reporting a vulnerability

Open a [security advisory](https://github.com/MacBachi/WalkOfShame/security/advisories/new)
rather than a public issue. This is a hobby project maintained by one person, so
please do not expect an SLA — but anything that affects the safety rules below
will be looked at first.

## What the threat model actually is

The app has no network code, no account, no server and no third-party
dependencies. There is no data to breach remotely and no session to hijack. The
interesting attack surface is smaller and more physical than in a typical app:

**Bluetooth input is untrusted.** Everything arriving over `0x2ACD` is parsed
without assuming the device follows the specification. Payloads are read strictly
sequentially with bounds checks; a truncated or oversized packet produces an
error or a `nil` field, never a crash and never a misaligned read. Bytes the
flags did not announce are reported rather than silently discarded, because a
firmware deviation that goes unnoticed is worse than one that shows up in a log.

**The control point can move hardware.** `0x2AD9` lets the app set the target
speed of a machine somebody may be standing on. Three rules are treated as
security properties, not as UX preferences:

1. every speed command requires an explicit confirmation in the UI,
2. every target value is validated against the range the device reports in
   `0x2AD4` *before* transmission — relying on the device to reject an invalid
   parameter means trusting the device while a person stands on it,
3. the emergency stop bypasses confirmation and validation entirely.

If you find a way to make the app send a speed command without confirmation, or
outside the validated range, that is a security issue in the sense that matters
here, and I want to hear about it.

**Health data is write-only.** Authorisation is requested for writing distance,
active energy and heart rate. The app never requests read access, so it cannot
exfiltrate health data it was never granted.

**Recordings are local.** Sessions are plain JSONL files in the app container,
protected by the standard iOS file protection of that container. They contain
movement data and timestamps. Deleting a workout in the app deletes the file;
what was already written to Apple Health lives in the Health database and has to
be removed there.

## Out of scope

- Physical access to an unlocked device
- Anything requiring the user to install a modified build
- The imperial units switch. It is a joke, it quits the app on purpose, and it is
  documented as such.
