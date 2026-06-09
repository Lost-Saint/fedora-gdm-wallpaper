Name:           gdm-wallpaper
Version:        1.0
Release:        %autorelease
Summary:        Set the GDM login screen wallpaper on GNOME 45+

# Source tarball / script — hosted on GitHub (replace with your actual URL)
URL:            https://github.com/lost-saint/gdm-wallpaper
Source0:        set-gdm-wallpaper

License:        GLWTS

# Shell script — no compiled artifacts, runs on any arch
BuildArch:      noarch

# Runtime: needs gresource + glib-compile-resources (both in glib2)
# glib2-devel is wrong here — that's the headers-only dev package.
# The binaries ship in glib2 itself on Fedora.
Requires:       glib2
Requires:       file

%description
Command-line tool to set the GDM (GNOME Display Manager) login and lock
screen wallpaper on Fedora systems running GNOME 45 or later.

Supports GNOME 45+ where gnome-shell.css was split into
gnome-shell-dark.css and gnome-shell-light.css, as well as older GNOME
releases using the legacy single gnome-shell.css.

Automatically backs up the original gnome-shell-theme.gresource before
applying changes and provides an --uninstall flag to restore it.

%prep
# Nothing to unpack — single script install

%build
# Nothing to compile

%install
install -D -m 0755 %{SOURCE0} %{buildroot}%{_bindir}/set-gdm-wallpaper

%files
%{_bindir}/set-gdm-wallpaper

%changelog
%autochangelog
