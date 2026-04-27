---
name: gitgauntlet
description: Set the global git user.name and user.email to [redacted]'s Gauntlet identity.
---

Set the global git identity for this user by running:

```
git config --global user.name "[redacted]"
git config --global user.email "[redacted]"
```

Then confirm by running:

```
git config --global --get user.name
git config --global --get user.email
```

Report the resulting values back to the user.
