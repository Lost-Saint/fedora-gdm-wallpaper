# GDM Wallpaper

Set or restore the GNOME Display Manager (GDM) login screen wallpaper by
rebuilding `/usr/share/gnome-shell/gnome-shell-theme.gresource`.

The script supports current GNOME Shell themes where GNOME 45+ split
`gnome-shell.css` into `gnome-shell-dark.css` and `gnome-shell-light.css`.
It also still handles older themes that use the legacy single
`gnome-shell.css` file.

## What it does

- Extracts the current GNOME Shell theme gresource.
- Adds your selected image as `wallpaper-gdm.png`.
- Patches the GDM lock/login CSS to use that image.
- Adds a transparent `.login-dialog` rule for newer GDM versions.
- Backs up the original gresource to
  `/usr/share/gnome-shell/gnome-shell-theme.gresource.backup`.
- Restores from that backup with `--uninstall`.

## Requirements

- Fedora or another GNOME system that uses
  `/usr/share/gnome-shell/gnome-shell-theme.gresource`
- `bash`
- `glib2` for `gresource` and `glib-compile-resources`
- `file`
- root privileges

On Fedora:

```sh
sudo dnf install glib2 file
```

Supported image types:

- PNG
- JPEG
- WebP
- GIF

## Install the Script

For local use without building an RPM:

```sh
sudo install -Dm755 set-gdm-wallpaper.sh /usr/local/bin/set-gdm-wallpaper
```

Then run:

```sh
sudo set-gdm-wallpaper /path/to/image.png
```

You can also run the script directly from the repository:

```sh
sudo ./set-gdm-wallpaper.sh /path/to/image.png
```

After changing the wallpaper, restart GDM or reboot:

```sh
sudo systemctl restart gdm
```

Restarting GDM ends the current graphical session.

## Usage

```sh
sudo set-gdm-wallpaper [FLAG] /path/to/image
sudo set-gdm-wallpaper --uninstall
```

By default, the image is applied with:

```css
background-repeat: no-repeat;
background-size: cover;
```

### Resize Presets

Use `--resize` to select one of the built-in CSS presets:

```sh
sudo set-gdm-wallpaper --resize 6 /path/to/image.png
```

Available values:

| Value | CSS |
| --- | --- |
| `0` | `background-repeat: repeat;` |
| `1` | `background-repeat: no-repeat;` |
| `2` | `background-repeat: no-repeat;background-size: cover;` |
| `3` | `background-size: 1920px 1080px;` |
| `4` | `background-size: 1920px 1080px;background-repeat: repeat;` |
| `5` | `background-position: 0 0;background-size: 1920px 1080px;background-repeat: repeat;` |
| `6` | `background-repeat: no-repeat;background-size: cover;background-position: center;` |

`2` is the default.

### Custom CSS

Use `--css` to provide custom background CSS for the `#lockDialogGroup`
rule:

```sh
sudo set-gdm-wallpaper --css 'background-size: 2560px 1440px;background-position: center' /path/to/image.png
```

`--css` and `--resize` are mutually exclusive.

## Restore the Original Theme

If the wallpaper was applied by this script:

```sh
sudo set-gdm-wallpaper --uninstall
```

If you ran the script directly from the repository:

```sh
sudo ./set-gdm-wallpaper.sh --uninstall
```

The script restores:

```text
/usr/share/gnome-shell/gnome-shell-theme.gresource.backup
```

to:

```text
/usr/share/gnome-shell/gnome-shell-theme.gresource
```

If GDM fails to load, switch to a TTY with `Ctrl` + `Alt` + `F3`, log in,
and run the uninstall command from there.

## RPM Packaging

This repository includes two RPM spec files.

### `gdm-wallpaper.spec`

Builds a `gdm-wallpaper` package that installs the command:

```text
/usr/bin/set-gdm-wallpaper
```

The user chooses the wallpaper at runtime:

```sh
sudo set-gdm-wallpaper /path/to/image.png
```

### `silverblue.gdm-wallpaper.spec`

Builds a `gdm-wallpaper-silver` package that installs the command and bundles
`wallpaper-gnome.png`.

The package `%post` script runs:

```sh
set-gdm-wallpaper --resize 2 /usr/share/gnome-shell/wallpaper/wallpaper-gnome.png
```

On Fedora Silverblue, install it with `rpm-ostree`; the wallpaper is applied
during deployment compose and takes effect after reboot.

On Fedora Workstation, install it with `dnf`; the wallpaper is applied during
package installation.

Removing `gdm-wallpaper-silver` restores the original gresource during full
package removal.

## Build RPMs Locally

Install packaging tools:

```sh
sudo dnf install fedora-packager rpmdevtools
```

Create the RPM build tree and copy sources:

```sh
rpmdev-setuptree
cp set-gdm-wallpaper.sh ~/rpmbuild/SOURCES/set-gdm-wallpaper
cp wallpaper-gnome.png ~/rpmbuild/SOURCES/wallpaper-gnome.png
```

Build the regular package:

```sh
rpmbuild -ba gdm-wallpaper.spec
```

Build the bundled Silverblue package:

```sh
rpmbuild -ba silverblue.gdm-wallpaper.spec
```

The built RPMs are written under `~/rpmbuild/RPMS/noarch/`.

## Notes

- The script must run as root because it writes under `/usr/share/gnome-shell`.
- The backup is created before replacing the original gresource.
- Re-running the script restores the original backup first, then applies the
  new image, so repeated wallpaper changes do not stack patches.
- `--uninstall` only restores when the current gresource appears to have been
  modified by this script.

## License

See [LICENSE.md](LICENSE.md).

## Wallpaper Credit

`wallpaper-gnome.png`: https://www.opendesktop.org/s/Gnome/p/1071929/
