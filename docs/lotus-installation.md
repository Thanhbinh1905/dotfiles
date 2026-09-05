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

Run once after `./bootstrap.sh`:

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
systemctl --user is-active fcitx5-daemon.service
systemctl is-active "fcitx5-lotus-server@$(whoami).service"
fcitx5-remote -n
fcitx5-diagnose
```

`fcitx5-remote -n` should print `lotus` after Lotus is selected. Press
`Ctrl+Space` to toggle between the US keyboard and Lotus.

The server enables Lotus's uinput modes. Lotus 3.5.x defaults to Telex and
Preedit, so typing still works before the server is installed, but without the
recommended direct-typing uinput mode.
