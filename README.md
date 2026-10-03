# dms-lact-profiles

DankMaterialShell bar widget to switch [LACT](https://github.com/ilya-zlobintsev/LACT) GPU profiles.
The bar pill shows the active profile; the popout is a button group (same control as the DMS
power-profile selector) with Default plus every profile in `/etc/lact/config.yaml`.

## How it works

- `lactProfiles/` is the DMS plugin. It runs `lact-apply --list` to read profiles and
  `sudo -n lact-apply <name>` to switch.
- `system/lact-apply` (installed at `/usr/local/bin/lact-apply`) sets `current_profile`, starts
  `lact daemon` once to apply the caps, then SIGKILLs it so the caps stay and CoolerControl keeps
  the fans (`lactd.service` is masked on this machine). `lact-apply edit` runs the daemon until
  Enter so the LACT GUI can edit settings. Profile names must match exactly; `base` = default.
- `system/sudoers-lact-apply` goes to `/etc/sudoers.d/lact-apply` (mode 440) so the widget can
  switch without a password.

## Install

```bash
sudo install -m 755 system/lact-apply /usr/local/bin/lact-apply
sudo install -m 440 system/sudoers-lact-apply /etc/sudoers.d/lact-apply && sudo visudo -c
ln -s "$PWD/lactProfiles" ~/.config/DankMaterialShell/plugins/lactProfiles
dms ipc call plugins enable lactProfiles
```
