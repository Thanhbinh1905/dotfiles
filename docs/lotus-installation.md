# Lotus host installation

This repository follows the official Lotus installer for Ubuntu, GNOME, X11,
Zsh and systemd: <https://lotusinputmethod.github.io/#installation>.

Home Manager handles these steps:

- installs Fcitx5 with `pkgs.fcitx5-lotus`;
- starts Fcitx5 with a systemd user service;
- adds Lotus to the active Fcitx5 group;
- disables Ubuntu `im-config` autostart with `run_im none` so IBus does not run;
- sets `GTK_IM_MODULE=fcitx`, `QT_IM_MODULE=fcitx`,
  `XMODIFIERS=@im=fcitx`, `SDL_IM_MODULE=fcitx`, and
  `GLFW_IM_MODULE=ibus`.

Ubuntu must provide toolkit modules compatible with its GTK and Qt libraries.
The Lotus uinput server also needs system users, udev rules, and a system
service, which Home Manager cannot install into `/etc`.

This repository ships Lotus with `Mode=Smooth`, an uinput mode that needs the
server setup below. Run the root block before or together with the Home Manager
switch that applies this configuration. If the configuration is applied without
the helper, Vietnamese typing is non-functional while Smooth is selected until
the mode is switched back to Preedit.

Run once before or together with the Home Manager switch (the `lotus_package`
path below must resolve to the installed Lotus package):

```bash
sudo apt install \
  fcitx5-frontend-gtk2 \
  fcitx5-frontend-gtk3 \
  fcitx5-frontend-gtk4 \
  fcitx5-frontend-qt5 \
  fcitx5-frontend-qt6

lotus_package="$(readlink -f ~/.nix-profile/lib/sysusers.d/lotus.conf)"
lotus_package="${lotus_package%/lib/sysusers.d/lotus.conf}"

sudo systemd-sysusers "$lotus_package/lib/sysusers.d/lotus.conf"
sudo install -Dm644 \
  "$lotus_package/lib/udev/rules.d/99-lotus.rules" \
  /etc/udev/rules.d/99-lotus.rules
sudo install -Dm644 \
  "$lotus_package/lib/systemd/system/fcitx5-lotus-server@.service" \
  /etc/systemd/system/fcitx5-lotus-server@.service

sudo modprobe uinput
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo systemctl daemon-reload
sudo systemctl enable --now "fcitx5-lotus-server@$(whoami).service"
```

Log out and log back in. Then verify:

```bash
id uinput_proxy
systemctl --user is-active fcitx5-daemon.service
systemctl is-active "fcitx5-lotus-server@$(whoami).service"
getfacl -p /dev/uinput | grep -F 'user:uinput_proxy:rw-'
fcitx5-remote -n
fcitx5-diagnose
```

The helper-specific checks above should report the `uinput_proxy` user, an
`active` Lotus server, and a `user:uinput_proxy:rw-` ACL on `/dev/uinput`.
`fcitx5-remote -n` should print `lotus` after Lotus is selected. Press
`Ctrl+Space` to toggle between the US keyboard and Lotus.

Press the grave/backtick mode-menu key (`ModeMenuKey=grave`) and choose
`Preedit` if the uinput helper is unavailable. This runtime fallback restores
Vietnamese typing with its underline without editing the repository or rerunning
Home Manager. For a permanent fallback, set `Mode=Preedit` in
`home/.config/fcitx5/conf/lotus.conf`.

Preedit composes text in a temporary buffer, so its standard rendering shows an
underline until the text is committed. The uinput modes synthesize real key
events (backspace plus the accented character), committing text directly
without a composing buffer or underline.

The server enables Lotus's uinput modes. Lotus still uses Telex and keeps the
other input, macro, spell-check, free-marking, and dictionary settings from the
managed configuration.
