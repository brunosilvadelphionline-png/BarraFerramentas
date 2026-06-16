"""Tray launcher: builds a Windows tray-icon menu from a folder of scripts.

Folders become submenus, files with configured extensions become menu items.
Config lives in config.ini next to this script.
"""
from __future__ import annotations

import configparser
import os
import re
import subprocess
import sys
import traceback
from pathlib import Path

import pystray
from pystray import Menu, MenuItem
from PIL import Image, ImageDraw, ImageFont


def _patch_left_click_opens_menu() -> None:
    """Make left-click open the popup menu on Windows (default is right-click).

    pystray's Win32 backend treats WM_LBUTTONUP as "invoke default action" and
    only opens the menu on WM_RBUTTONUP. We swap so left-click runs the same
    code path the right-click handler does, while keeping right-click working.
    """
    try:
        import ctypes
        from ctypes import wintypes
        from pystray import _win32 as _w
    except Exception:
        return

    win32 = _w.win32
    original = _w.Icon._on_notify

    def _on_notify(self, wparam, lparam):
        if lparam in (win32.WM_LBUTTONUP, win32.WM_RBUTTONUP) and self._menu_handle:
            win32.SetForegroundWindow(self._hwnd)
            point = wintypes.POINT()
            win32.GetCursorPos(ctypes.byref(point))
            hmenu, descriptors = self._menu_handle
            index = win32.TrackPopupMenuEx(
                hmenu,
                win32.TPM_RIGHTALIGN | win32.TPM_BOTTOMALIGN | win32.TPM_RETURNCMD,
                point.x,
                point.y,
                self._menu_hwnd,
                None,
            )
            if index > 0:
                descriptors[index - 1](self)
            return
        return original(self, wparam, lparam)

    _w.Icon._on_notify = _on_notify


_patch_left_click_opens_menu()

APP_DIR = Path(__file__).resolve().parent
CONFIG_PATH = APP_DIR / "config.ini"
DEFAULT_ALLOWED_EXTS = frozenset({".bat", ".cmd", ".exe", ".lnk", ".ps1", ".rdp"})
EXT_SPLIT_RE = re.compile(r"[,;\s]+")
ORDER_PREFIX_RE = re.compile(r"^(\d+)[_\-. ]")
SEPARATOR_STEM_RE = re.compile(r"^-{2,}$")


def parse_extensions(raw_extensions: str | None) -> set[str]:
    if raw_extensions is None:
        return set(DEFAULT_ALLOWED_EXTS)

    extensions: set[str] = set()
    for token in EXT_SPLIT_RE.split(raw_extensions):
        ext = token.strip().lower()
        if not ext:
            continue
        if not ext.startswith("."):
            ext = f".{ext}"
        if ext != ".":
            extensions.add(ext)
    return extensions


def load_config() -> tuple[Path, str, bool, set[str]]:
    cfg = configparser.ConfigParser()
    if CONFIG_PATH.exists():
        cfg.read(CONFIG_PATH, encoding="utf-8")

    raw_path = cfg.get("menu", "path", fallback=".\\Menu")
    menu_path = Path(raw_path)
    if not menu_path.is_absolute():
        menu_path = (APP_DIR / menu_path).resolve()

    title = cfg.get("menu", "title", fallback="Utilitarios")
    show_ext = cfg.getboolean("menu", "show_extensions", fallback=False)
    allowed_exts = parse_extensions(cfg.get("menu", "extensions", fallback=None))
    return menu_path, title, show_ext, allowed_exts


def strip_order_prefix(name: str) -> str:
    return ORDER_PREFIX_RE.sub("", name, count=1)


def order_value(name: str) -> int:
    m = ORDER_PREFIX_RE.match(name)
    return int(m.group(1)) if m else 10**9


def display_name(p: Path, show_ext: bool) -> str:
    base = strip_order_prefix(p.name)
    if p.is_dir() or show_ext:
        return base
    return Path(base).stem


def is_separator(p: Path) -> bool:
    if not p.is_file():
        return False
    stem = Path(strip_order_prefix(p.name)).stem
    return bool(SEPARATOR_STEM_RE.match(stem))


def launch_item(path: Path) -> None:
    try:
        # os.startfile uses the shell verb and runs detached.
        os.startfile(str(path))  # type: ignore[attr-defined]
    except OSError:
        # Fallback for unusual file types.
        subprocess.Popen(["cmd", "/c", "start", "", str(path)], shell=False)


def make_action(path: Path):
    def _action(icon, item):  # noqa: ARG001
        launch_item(path)
    return _action


def build_items(folder: Path, show_ext: bool, allowed_exts: set[str]) -> list:
    items: list = []
    if not folder.exists():
        items.append(MenuItem("(pasta nao encontrada)", None, enabled=False))
        return items
    try:
        entries = sorted(
            folder.iterdir(),
            key=lambda x: (order_value(x.name), not x.is_dir(), x.name.lower()),
        )
    except OSError as exc:
        items.append(MenuItem(f"(erro: {exc})", None, enabled=False))
        return items

    for entry in entries:
        if entry.is_dir():
            sub = build_items(entry, show_ext, allowed_exts)
            if not sub:
                sub = [MenuItem("(vazio)", None, enabled=False)]
            items.append(MenuItem(display_name(entry, show_ext), Menu(*sub)))
        elif is_separator(entry):
            items.append(Menu.SEPARATOR)
        elif entry.suffix.lower() in allowed_exts:
            items.append(MenuItem(display_name(entry, show_ext), make_action(entry)))
    return items


def make_icon_image() -> Image.Image:
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 2, size - 2, size - 2), fill=(30, 90, 160, 255))
    font = None
    for candidate in ("seguibl.ttf", "segoeuib.ttf", "arialbd.ttf"):
        try:
            font = ImageFont.truetype(candidate, 40)
            break
        except OSError:
            continue
    if font is None:
        font = ImageFont.load_default()
    text = "U"
    bbox = d.textbbox((0, 0), text, font=font)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    d.text(
        ((size - w) / 2 - bbox[0], (size - h) / 2 - bbox[1]),
        text,
        fill="white",
        font=font,
    )
    return img


def build_menu(folder: Path, show_ext: bool, allowed_exts: set[str], on_reload, on_quit) -> Menu:
    items = build_items(folder, show_ext, allowed_exts)

    def open_folder(icon, item):  # noqa: ARG001
        if folder.exists():
            os.startfile(str(folder))  # type: ignore[attr-defined]

    def edit_config(icon, item):  # noqa: ARG001
        os.startfile(str(CONFIG_PATH))  # type: ignore[attr-defined]

    items.extend([
        Menu.SEPARATOR,
        MenuItem("Abrir pasta", open_folder),
        MenuItem("Editar config.ini", edit_config),
        MenuItem("Recarregar", on_reload),
        MenuItem("Sair", on_quit),
    ])
    return Menu(*items)


def main() -> None:
    folder, title, show_ext, allowed_exts = load_config()
    folder.mkdir(parents=True, exist_ok=True)

    icon: pystray.Icon | None = None

    def on_reload(ic, item):  # noqa: ARG001
        new_folder, new_title, new_show, new_allowed_exts = load_config()
        new_folder.mkdir(parents=True, exist_ok=True)
        ic.title = new_title
        ic.menu = build_menu(new_folder, new_show, new_allowed_exts, on_reload, on_quit)
        ic.update_menu()

    def on_quit(ic, item):  # noqa: ARG001
        ic.stop()

    menu = build_menu(folder, show_ext, allowed_exts, on_reload, on_quit)
    icon = pystray.Icon("utilitarios", make_icon_image(), title, menu)
    icon.run()


if __name__ == "__main__":
    try:
        main()
    except Exception:  # surface fatal errors when launched via pythonw
        log = APP_DIR / "tray_menu.error.log"
        log.write_text(traceback.format_exc(), encoding="utf-8")
        raise
