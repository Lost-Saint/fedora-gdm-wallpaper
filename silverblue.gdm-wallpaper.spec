Name:           gdm-wallpaper-silver
Version:        1.0
Release:        %autorelease
Summary:        GDM login screen wallpaper with bundled default image

URL:            https://github.com/youruser/gdm-wallpaper
Source0:        wallpaper-gnome.png
Source1:        set-gdm-wallpaper

License:        GLWTS

BuildArch:      noarch

Requires:       glib2
Requires:       file

%description
Extends gdm-wallpaper with a bundled default wallpaper image.

On Fedora Silverblue, install via rpm-ostree. The %post scriptlet runs
during deployment compose when /usr is writable, patching the gresource
before the new deployment is committed. The wallpaper takes effect on
next reboot.

On Fedora Workstation, install via dnf. The wallpaper is applied
immediately by the %post scriptlet.

Removing this package restores the original gresource via --uninstall.

%prep
# Nothing to unpack

%build
# Nothing to compile

%install
install -D -m 0644 %{SOURCE0} \
    %{buildroot}%{_datadir}/gnome-shell/wallpaper/wallpaper-gnome.png

install -D -m 0755 %{SOURCE1} \
    %{buildroot}%{_bindir}/set-gdm-wallpaper

%post
# Runs during rpm-ostree deployment compose (Silverblue) or dnf install
# (Workstation) — /usr is writable in both contexts at this point.
%{_bindir}/set-gdm-wallpaper --resize 2 \
    %{_datadir}/gnome-shell/wallpaper/wallpaper-gnome.png || true

%preun
# Only restore on full removal, not on upgrade.
# Without this guard, every rpm-ostree operation would wipe the wallpaper.
if [ "$1" -eq 0 ]; then
    %{_bindir}/set-gdm-wallpaper --uninstall || true
fi

%files
%{_bindir}/set-gdm-wallpaper
%{_datadir}/gnome-shell/wallpaper/wallpaper-gnome.png

%changelog
%autochangelog
