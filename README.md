# Linux Better Font

Configures Fedora to use the complete Google Noto collection as its base font
fallback and applies Ubuntu-style desktop rendering.

## Font Policy

- Uses Noto Sans, Noto Serif, and Noto Sans Mono for the generic font families.
- Installs `google-noto-fonts-all` and builds fallback lists from every installed
  Noto family so uncommon writing systems remain available to native and Flatpak
  applications.
- Enables antialiasing, slight hinting, RGB subpixel rendering, and the default
  LCD filter.
- Rejects non-scalable bitmap fonts while preserving scalable color emoji.

`google-noto-fonts-all` is a large metapackage. It installs hundreds of font
packages and can consume more than 1 GB depending on the Fedora release.

## Install

By default, the configuration is installed for the current user.

```bash
curl -fsSL https://raw.githubusercontent.com/faelayis/Linux-Better-Font/main/install.sh | bash
```

Use `--root` to install the configuration system-wide for all users:

```bash
curl -fsSL https://raw.githubusercontent.com/faelayis/Linux-Better-Font/main/install.sh | bash -s -- --root
```

Flatpak applications are configured automatically when Flatpak is installed.

Fully close and reopen native and Flatpak applications after installation.

## Status

```bash
curl -fsSL https://raw.githubusercontent.com/faelayis/Linux-Better-Font/main/status.sh | bash
```

Check the system-wide configuration with `--root`:

```bash
curl -fsSL https://raw.githubusercontent.com/faelayis/Linux-Better-Font/main/status.sh | bash -s -- --root
```

The status command verifies the font configuration and Flatpak integration.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/faelayis/Linux-Better-Font/main/uninstall.sh | bash
```

Remove the system-wide configuration with `--root`:

```bash
curl -fsSL https://raw.githubusercontent.com/faelayis/Linux-Better-Font/main/uninstall.sh | bash -s -- --root
```

Uninstall restores the previous font behavior but keeps the installed Noto
packages.
