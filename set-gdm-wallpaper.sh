#!/bin/bash
# set-gdm-wallpaper — Set or restore the GDM login screen wallpaper
# Requires: glib2 (gresource, glib-compile-resources), bash, file(1)
# Must be run as root.

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
GDM_GRESOURCE="/usr/share/gnome-shell/gnome-shell-theme.gresource"
GDM_BACKUP="${GDM_GRESOURCE}.backup"
WALLPAPER_MARKER="wallpaper-gdm.png"           # sentinel present only in our modified builds
WALLPAPER_RES_PATH="/org/gnome/shell/theme/wallpaper-gdm.png"
WALLPAPER_REL_PATH="org/gnome/shell/theme/wallpaper-gdm.png"
CSS_RES_PATH="org/gnome/shell/theme/gnome-shell.css"

# ---------------------------------------------------------------------------
# Prerequisite: must run as root
# ---------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

# ---------------------------------------------------------------------------
# Prerequisite: gresource must be available
# ---------------------------------------------------------------------------
if ! hash gresource 2>/dev/null; then
  echo "Error: gresource binary not found."
  echo ""
  echo "Please install glib2 or glib2-devel:"
  echo "  Fedora:  dnf install glib2-devel"
  echo "  Debian:  apt install libglib2.0-bin"
  exit 1
fi

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage:
  set-gdm-wallpaper [FLAG] /path/to/image    Set login screen wallpaper
    Flags (mutually exclusive):
      --css 'css data'          Replace CSS params inside #lockDialogGroup block.
                                Example: background-size: 1920px 1080px;
      --resize 0..6 (default 2) Use a built-in CSS template for resize/alignment.
                                Useful for fixing multi-monitor issues.
        0 - background-repeat: repeat;
        1 - background-repeat: no-repeat;
        2 - background-repeat: no-repeat;background-size: cover;          [default]
        3 - background-size: 1920px 1080px;
        4 - background-size: 1920px 1080px;background-repeat: repeat;
        5 - background-position: 0 0;background-size: 1920px 1080px;background-repeat: repeat;
        6 - background-repeat: no-repeat;background-size: cover;background-position: center;

  set-gdm-wallpaper --uninstall
        Remove changes and restore the original gresource backup.
EOF
}

if [ "$#" -eq 0 ]; then
  usage
  exit 1
fi

# ---------------------------------------------------------------------------
# --uninstall
# ---------------------------------------------------------------------------
if [ "$1" = "--uninstall" ]; then
  if grep -q "$WALLPAPER_MARKER" "$GDM_GRESOURCE" 2>/dev/null; then
    if [ ! -s "$GDM_BACKUP" ]; then
      echo "Error: backup file '$GDM_BACKUP' is missing or empty — cannot restore."
      exit 1
    fi
    cp -f "$GDM_BACKUP" "$GDM_GRESOURCE"
    echo "gnome-shell-theme.gresource recovered from backup."
  else
    echo "Nothing to uninstall: gresource does not appear to be modified by this script."
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Parse optional flags --css / --resize
# ---------------------------------------------------------------------------
image_parameters="background-repeat: no-repeat;background-size: cover;"
css_set=""
resize_set=""

if [ "$1" = "--css" ]; then
  if [ $# -lt 2 ]; then
    echo "Error: --css requires a value."
    exit 1
  fi
  css_set=1
  # Strip any trailing semicolons supplied by the user, then add exactly one.
  css_input="${2%;}"
  image_parameters="${css_input};"
  shift 2
fi

if [ "$1" = "--resize" ] 2>/dev/null; then
  if [ $# -lt 2 ]; then
    echo "Error: --resize requires a numeric value (0-6)."
    exit 1
  fi
  if [ -n "$css_set" ]; then
    echo "Error: --css and --resize are mutually exclusive."
    exit 1
  fi
  resize_set=1
  case "$2" in
    0) image_parameters="background-repeat: repeat;";;
    1) image_parameters="background-repeat: no-repeat;";;
    2) image_parameters="background-repeat: no-repeat;background-size: cover;";;
    3) image_parameters="background-size: 1920px 1080px;";;
    4) image_parameters="background-size: 1920px 1080px;background-repeat: repeat;";;
    5) image_parameters="background-position: 0 0;background-size: 1920px 1080px;background-repeat: repeat;";;
    6) image_parameters="background-repeat: no-repeat;background-size: cover;background-position: center;";;
    *)
      echo "Error: unknown --resize value '$2'. Valid values are 0-6."
      exit 1;;
  esac
  shift 2
fi

# ---------------------------------------------------------------------------
# Exactly one positional argument (the image path) must remain
# ---------------------------------------------------------------------------
if [ "$#" -ne 1 ]; then
  echo "Error: expected exactly one image path argument, got $#."
  usage
  exit 1
fi

image="$(realpath "$1")"

if [ ! -f "$image" ]; then
  echo "Error: file not found: \"$image\""
  exit 1
fi

# Validate that the file is actually a supported image
mime_type=$(file --mime-type -b "$image")
case "$mime_type" in
  image/png|image/jpeg|image/webp|image/gif) ;;
  *)
    echo "Error: '$image' does not appear to be a supported image type."
    echo "  Detected MIME type: $mime_type"
    echo "  Supported types: image/png, image/jpeg, image/webp, image/gif"
    exit 1;;
esac

# ---------------------------------------------------------------------------
# Temp directory — always cleaned up on exit, interrupt, or error
# ---------------------------------------------------------------------------
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT INT TERM

echo "Updating wallpaper..."

# ---------------------------------------------------------------------------
# If the current gresource is already our modified version, restore the
# backup first so we always compile on top of the original theme files.
# ---------------------------------------------------------------------------
if grep -q "$WALLPAPER_MARKER" "$GDM_GRESOURCE" 2>/dev/null; then
  if [ ! -s "$GDM_BACKUP" ]; then
    echo "Error: gresource appears modified but backup '$GDM_BACKUP' is missing or empty."
    exit 1
  fi
  cp -f "$GDM_BACKUP" "$GDM_GRESOURCE"
fi

# ---------------------------------------------------------------------------
# Extract all existing theme resources into $workdir
# ---------------------------------------------------------------------------
GRESOURCE_XML="$workdir/gnome-shell-theme.gresource.xml"

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<gresources><gresource>'
} >"$GRESOURCE_XML"

# Use `while read` instead of `for $(...)` to handle paths with spaces safely.
while IFS= read -r res_file; do
  mkdir -p "$(dirname "$workdir$res_file")"

  # Skip any stale wallpaper-gdm.png from a previous modified build.
  if [ "$res_file" = "$WALLPAPER_RES_PATH" ]; then
    continue
  fi

  gresource extract "$GDM_GRESOURCE" "$res_file" >"$workdir$res_file"
  echo "<file>${res_file#/}</file>" >>"$GRESOURCE_XML"

done < <(gresource list "$GDM_GRESOURCE")

# ---------------------------------------------------------------------------
# Add our wallpaper image to the theme
# ---------------------------------------------------------------------------
echo "<file>$WALLPAPER_REL_PATH</file>" >>"$GRESOURCE_XML"
cp -f "$image" "$workdir/$WALLPAPER_REL_PATH"

echo '</gresource></gresources>' >>"$GRESOURCE_XML"

# ---------------------------------------------------------------------------
# Patch gnome-shell.css: replace #lockDialogGroup block with our wallpaper
# ---------------------------------------------------------------------------
new_theme_params="background: #2e3436 url(resource:\/\/\/org\/gnome\/shell\/theme\/wallpaper-gdm.png);"

# Escape any sed metacharacters in image_parameters (/, &, \) before injection.
safe_params=$(printf '%s' "$image_parameters" | sed 's/[\/&]/\\&/g')

sed -i -z -E \
  "s/#lockDialogGroup \{[^}]+/#lockDialogGroup \{${new_theme_params}${safe_params}/g" \
  "$workdir/$CSS_RES_PATH"

# GDM 44+ moved the login dialog background to .login-dialog; set it
# transparent so the #lockDialogGroup wallpaper shows through.
cat >>"$workdir/$CSS_RES_PATH" <<'EOF'

/* set-gdm-wallpaper: GDM 44+ transparency fix */
.login-dialog {
  background-color: transparent;
}
EOF

# ---------------------------------------------------------------------------
# Compile the patched resources into a new gresource file
# ---------------------------------------------------------------------------
glib-compile-resources "$GRESOURCE_XML"

# ---------------------------------------------------------------------------
# Back up the original (unmodified) gresource before overwriting it
# ---------------------------------------------------------------------------
if ! grep -q "$WALLPAPER_MARKER" "$GDM_GRESOURCE" 2>/dev/null; then
  cp -f "$GDM_GRESOURCE" "$GDM_BACKUP"
  echo "Backup created: $GDM_BACKUP"
fi

# ---------------------------------------------------------------------------
# Install the new gresource
# ---------------------------------------------------------------------------
cp -f "$workdir/gnome-shell-theme.gresource" /usr/share/gnome-shell/

# trap will handle workdir cleanup on EXIT
echo "Done! You may need to restart GDM: sudo systemctl restart gdm"
