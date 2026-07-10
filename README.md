# novamind

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Linux desktop (Fedora / Nobara)

If `flutter run -d linux` fails with CMake errors about **non-existent**
`/usr/lib/dbus-1.0/include` or `/usr/lib/glib-2.0/include` while the files
exist under `/usr/lib64/...`, create compatibility symlinks once:

```bash
sudo mkdir -p /usr/lib/dbus-1.0 /usr/lib/glib-2.0
sudo ln -sfn /usr/lib64/dbus-1.0/include  /usr/lib/dbus-1.0/include
sudo ln -sfn /usr/lib64/glib-2.0/include /usr/lib/glib-2.0/include
```

Then `flutter clean` and run again.
