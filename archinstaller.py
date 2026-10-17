#!/usr/bin/env python3
"""amos-r: patch archinstall GlobalMenu by ukrywania wybranych zakładek."""
import sys
from archinstall.lib.global_menu import GlobalMenu
from archinstall.tui.components import tui
from archinstall.lib.args import ArchConfigHandler
from archinstall.lib.mirror.mirror_handler import MirrorListHandler

HIDDEN_KEYS = {
    "archinstall_language",
    "locale_config",
    "firmware_optdeps",
    "applications",
    "network_config",
    "pacman_config",
    "timezone",
    "ntp",
}

class FilteredGlobalMenu(GlobalMenu):
    def _get_menu_options(self):
        options = super()._get_menu_options()
        return [opt for opt in options if opt.key is None or opt.key not in HIDDEN_KEYS]

# Patch przed użyciem
orig_init = GlobalMenu.__init__
def new_init(self, *args, **kwargs):
    orig_init(self, *args, **kwargs)
    # Po stworzeniu menu, usuń ukryte pozycje z item_group
    original_items = list(self._item_group.items)
    self._item_group._items = [
        item for item in original_items
        if item.key is None or item.key not in HIDDEN_KEYS
    ]

GlobalMenu.__init__ = new_init

# Reszta guided.py
if __name__ == '__main__':
    arch_config_handler = ArchConfigHandler()
    mirror_list_handler = MirrorListHandler(offline=False, verbose=False)
    
    from archinstall.scripts.guided import show_menu
    show_menu(arch_config_handler, mirror_list_handler)
    # ... reszta perform_installation