# dmgbuild settings for the Iqama installer DMG.
#
# Invoked by Scripts/release.sh as:
#   dmgbuild -s Scripts/dmg-settings.py \
#            -D app=<path-to-.app> -D bg=<path-to-bg.png> \
#            "Iqama" <output.dmg>
#
# dmgbuild writes the .DS_Store directly (via the ds_store/mac_alias libs), so
# it sets the window background, size, and icon positions WITHOUT Finder
# AppleScript — which is unreliable on macOS 26.

import os.path

app_path = defines.get("app", "Dubai iqama.app")          # noqa: F821 (dmgbuild injects `defines`)
bg_path = defines.get("bg", "")                            # noqa: F821
app_name = os.path.basename(app_path)

# Contents of the volume.
files = [app_path]
symlinks = {"Applications": "/Applications"}

# Window / icon layout.
if bg_path:
    background = bg_path
icon_size = 128
text_size = 13
window_rect = ((360, 240), (660, 400))   # (x, y), (w, h)

icon_locations = {
    app_name: (170, 200),
    "Applications": (490, 200),
}

# Cosmetics.
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
arrange_by = None
label_pos = "bottom"

# Compression / format.
format = "UDZO"
