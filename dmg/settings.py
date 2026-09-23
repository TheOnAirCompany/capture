# dmgbuild settings for the Capture disk image.
# Icon centers must match the drawing in scripts/make-dmg-background.swift.
# Usage: dmgbuild -s dmg/settings.py -D app=path/to/Capture.app "Capture" Capture.dmg
import os

app = defines.get("app", "build/export/Capture.app")
app_name = os.path.basename(app)

format = "UDZO"
filesystem = "APFS"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(app, "Contents/Resources/AppIcon.icns")

background = "dmg/background.tiff"
window_rect = ((200, 160), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False

icon_size = 128
text_size = 13
icon_locations = {
    app_name: (180, 190),
    "Applications": (480, 190),
}
