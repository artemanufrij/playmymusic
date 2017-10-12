/*-
 * Copyright (c) 2017-2017 Artem Anufrij <artem.anufrij@live.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * The Noise authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Noise. This permission is above and beyond the permissions granted
 * by the GPL license by which Noise is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 *
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 */

namespace PlayMyMusic.Widgets.Views {
    public class PlaylistsView : Gtk.Grid {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Settings settings;

        private string _filter = "";
        public string filter {
            get {
                return _filter;
            } set {
                if (_filter != value) {
                    _filter = value;
                    playlists.invalidate_filter ();
                }
            }
        }

        Gtk.FlowBox playlists;

        Gtk.Image icon_repeat_on;
        Gtk.Image icon_repeat_off;
        Gtk.Image icon_shuffle_on;
        Gtk.Image icon_shuffle_off;
        Gtk.Button repeat_button;
        Gtk.Button shuffle_button;

        construct {
            settings = PlayMyMusic.Settings.get_default ();
            library_manager = PlayMyMusic.Services.LibraryManager.instance;

            settings.notify["repeat-mode"].connect (() => {
                if (settings.repeat_mode) {
                    repeat_button.set_image (icon_repeat_on);
                } else {
                    repeat_button.set_image (icon_repeat_off);
                }
                repeat_button.show_all ();
            });

            settings.notify["shuffle-mode"].connect (() => {
                if (settings.shuffle_mode) {
                    shuffle_button.set_image (icon_shuffle_on);
                } else {
                    shuffle_button.set_image (icon_shuffle_off);
                }
                repeat_button.show_all ();
            });
        }

        public PlaylistsView () {
            build_ui ();
        }

        private void build_ui () {
            playlists = new Gtk.FlowBox ();
            playlists.margin = 24;
            playlists.selection_mode = Gtk.SelectionMode.NONE;
            playlists.column_spacing = 24;
            playlists.homogeneous = true;

            var playlists_scroll = new Gtk.ScrolledWindow (null, null);
            playlists_scroll.add (playlists);

            var action_toolbar = new Gtk.ActionBar ();
            action_toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_INLINE_TOOLBAR);

            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.tooltip_text = _("Add a playlist");
            action_toolbar.pack_start (add_button);

            icon_shuffle_on = new Gtk.Image.from_icon_name ("media-playlist-shuffle-symbolic", Gtk.IconSize.BUTTON);
            icon_shuffle_off = new Gtk.Image.from_icon_name ("media-playlist-no-shuffle-symbolic", Gtk.IconSize.BUTTON);

            shuffle_button = new Gtk.Button ();
            if (settings.shuffle_mode) {
                shuffle_button.set_image (icon_shuffle_on);
            } else {
                shuffle_button.set_image (icon_shuffle_off);
            }
            shuffle_button.tooltip_text = _("Shuffle");
            shuffle_button.can_focus = false;
            shuffle_button.clicked.connect (() => {
                settings.shuffle_mode = !settings.shuffle_mode;
            });

            icon_repeat_on = new Gtk.Image.from_icon_name ("media-playlist-repeat-symbolic", Gtk.IconSize.BUTTON);
            icon_repeat_off = new Gtk.Image.from_icon_name ("media-playlist-no-repeat-symbolic", Gtk.IconSize.BUTTON);

            repeat_button = new Gtk.Button ();
            if (settings.repeat_mode) {
                repeat_button.set_image (icon_repeat_on);
            } else {
                repeat_button.set_image (icon_repeat_off);
            }
            repeat_button.tooltip_text = _("Repeat");
            repeat_button.can_focus = false;
            repeat_button.clicked.connect (() => {
                settings.repeat_mode = !settings.repeat_mode;
            });

            action_toolbar.pack_end (repeat_button);
            action_toolbar.pack_end (shuffle_button);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.expand = true;
            content.pack_start (playlists_scroll, true, true, 0);
            content.pack_end (action_toolbar, false, false, 0);

            var stack = new Gtk.Stack ();
            //stack.add_named (welcome, "welcome");
            stack.add_named (content, "content");

            this.add (stack);
            this.show_all ();

            show_playlists_from_database.begin ();
        }

        private void add_playlist (PlayMyMusic.Objects.Playlist playlist) {
            var p = new Widgets.Playlist (playlist);
            p.track_selected.connect (() => {
                foreach (var child in playlists.get_children ()) {
                    if (child != p) {
                        (child as Widgets.Playlist).unselect_all ();
                    }
                }
            });
            p.show_all ();
            playlists.min_children_per_line = library_manager.playlists.length ();
            playlists.add (p);
        }

        private async void show_playlists_from_database () {
            foreach (var playlist in library_manager.playlists) {
                add_playlist (playlist);
            }
        }
    }
}
