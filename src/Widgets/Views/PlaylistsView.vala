/*-
 * Copyright (c) 2017-2018 Artem Anufrij <artem.anufrij@live.de>
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
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
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
        Services.LibraryManager library_manager;
        Services.Player player;
        Settings settings;

        private string _filter = "";
        public string filter {
            get {
                return _filter;
            } set {
                if (_filter != value) {
                    _filter = value;
                    do_filter ();
                }
            }
        }

        Gtk.Box playlists;
        Gtk.Stack stack;
        Gtk.Popover new_playlist_popover;
        Gtk.Entry new_playlist_entry;
        Gtk.Button new_playlist_save;

        uint timer_sort = 0;
        uint items_found = 0;

        construct {
            settings = Settings.get_default ();
            library_manager = Services.LibraryManager.instance;
            player = library_manager.player;

            library_manager.added_new_playlist.connect ((playlist) => {
                add_playlist (playlist);
                stack.set_visible_child_name ("content");
            });
            library_manager.removed_playlist.connect ((playlist) => {
                remove_playlist (playlist);
            });
            player.state_changed.connect ((state) => {
                if (state == Gst.State.PLAYING
                    && player.play_mode == Services.PlayMode.PLAYLIST
                    && player.current_track.playlist.ID != library_manager.db_manager.get_queue ().ID) {
                    activate_by_track (player.current_track);
                }
            });
        }

        public PlaylistsView () {
            build_ui ();
        }

        private void build_ui () {
            playlists = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24);
            playlists.margin = 24;
            playlists.margin_bottom = 0;
            playlists.halign = Gtk.Align.START;
            playlists.homogeneous = true;

            var playlists_scroll = new Gtk.ScrolledWindow (null, null);
            playlists_scroll.add (playlists);

            var action_toolbar = new Gtk.ActionBar ();
            action_toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.tooltip_text = _ ("Add a playlist");
            add_button.clicked.connect (() => {
                new_playlist_popover.set_relative_to (add_button);
                new_playlist_entry.text = "";
                new_playlist_save.sensitive = false;
                new_playlist_popover.show_all ();
            });
            action_toolbar.pack_start (add_button);

            var import_button = new Gtk.Button.from_icon_name ("document-import-symbolic");
            import_button.tooltip_text = _("Import Playlist");
            import_button.clicked.connect (() => {
                library_manager.import_playlist ();
            });
            action_toolbar.pack_start (import_button);

            new_playlist_popover = new Gtk.Popover (null);

            var new_playlist = new Gtk.Grid ();
            new_playlist.row_spacing = 6;
            new_playlist.column_spacing = 12;
            new_playlist.margin = 12;
            new_playlist_popover.add (new_playlist);

            new_playlist_entry = new Gtk.Entry ();
            new_playlist_save = new Gtk.Button.with_label (_ ("Add"));
            new_playlist_save.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            new_playlist_save.sensitive = false;

            new_playlist_entry.changed.connect (() => {
                new_playlist_save.sensitive = valid_new_playlist ();
            });
            new_playlist_entry.key_press_event.connect ((key) => {
                if ((key.keyval == Gdk.Key.Return || key.keyval == Gdk.Key.KP_Enter) && Gdk.ModifierType.CONTROL_MASK in key.state && valid_new_playlist ()) {
                    save_new_playlist ();
                }
                return false;
            });
            new_playlist.attach (new_playlist_entry, 0, 0);

            new_playlist_save.clicked.connect (() => {
                save_new_playlist ();
            });
            new_playlist.attach (new_playlist_save, 0, 1);

            var welcome = new Granite.Widgets.Welcome (_ ("No Playlists"), _ ("Add playlist to your library."));
            welcome.append ("document-new", _ ("Create Playlist"), _ ("Create a playlist for manage your favorite songs."));
            welcome.append ("document-import", _("Import Playlist"), _("Import .m3u formated Playlist."));
            welcome.activated.connect ((index) => {
                switch (index) {
                    case 0:
                        new_playlist_popover.set_relative_to (welcome.get_button_from_index (index));
                        new_playlist_popover.show_all ();
                        break;
                    case 1:
                        library_manager.import_playlist ();
                        break;
                }
            });

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.expand = true;
            content.pack_start (playlists_scroll, true, true, 0);
            content.pack_end (action_toolbar, false, false, 0);

            var alert_view = new Granite.Widgets.AlertView (_ ("No results"), _ ("Try another search"), "edit-find-symbolic");

            stack = new Gtk.Stack ();
            stack.add_named (welcome, "welcome");
            stack.add_named (content, "content");
            stack.add_named (alert_view, "alert");

            this.add (stack);
            this.show_all ();

            show_playlists_from_database.begin ();
        }

        private void save_new_playlist () {
            var playlist = new Objects.Playlist ();
            playlist.title = new_playlist_entry.text.strip ();
            library_manager.db_manager.insert_playlist (playlist);
            new_playlist_popover.hide ();
        }

        private bool valid_new_playlist () {
            string new_title = new_playlist_entry.text.strip ();
            return new_title != "" && library_manager.db_manager.get_playlist_by_title (new_title) == null;
        }

        private void add_playlist (Objects.Playlist playlist) {
            var p = new Widgets.Playlist (playlist);
            playlist.updated.connect (() => {
                playlists_sort_func ();
            });
            p.show_all ();
            playlists.add (p);
            do_sort ();
        }

        private void remove_playlist (Objects.Playlist playlist) {
            foreach (var child in playlists.get_children ()) {
                if ((child as Widgets.Playlist).playlist.ID == playlist.ID) {
                    playlists.remove (child);
                    child.destroy ();
                }
            }

            if (playlists.get_children ().length () == 0) {
                stack.set_visible_child_name ("welcome");
            }
        }

        public void activate_by_track (Objects.Track track) {
            activate_by_id (track.playlist.ID);
        }

        public Objects.Playlist ? activate_by_id (int id) {
            foreach (var child in playlists.get_children ()) {
                if ((child as Widgets.Playlist).playlist.ID == id) {
                    (child as Widgets.Playlist).mark_playing_track (library_manager.player.current_track);
                    return (child as Widgets.Playlist).playlist;
                }
            }
            return null;
        }

        private async void show_playlists_from_database () {
            foreach (var playlist in library_manager.playlists) {
                if (playlist.title != PlayMyMusicApp.instance.QUEUE_SYS_NAME) {
                    add_playlist (playlist);
                }
            }

            if (playlists.get_children ().length () > 0) {
                stack.set_visible_child_name ("content");
            }
        }

        private void do_filter () {
            if (stack.visible_child_name == "welcome") {
                return;
            }

            items_found = 0;
            playlists_filter_func ();
            if (items_found == 0) {
                stack.visible_child_name = "alert";
            } else {
                stack.visible_child_name = "content";
            }
        }

        private void do_sort () {
            if (timer_sort != 0) {
                Source.remove (timer_sort);
                timer_sort = 0;
            }

            timer_sort = Timeout.add (250, () => {
                playlists_sort_func ();
                Source.remove (timer_sort);
                timer_sort = 0;
                return false;
            });
        }

        private void playlists_sort_func () {
            for (int i = 0; i < playlists.get_children ().length (); i ++) {
                for (int j = i + 1; j < playlists.get_children ().length (); j++) {
                    var item1 = (Widgets.Playlist) playlists.get_children ().nth_data(i);
                    var item2 = (Widgets.Playlist) playlists.get_children ().nth_data(j);

                    if (item1.title.down ().collate (item2.title.down ()) > 0) {
                        playlists.reorder_child (item2, i);
                    }
                }
            }
        }

        private void playlists_filter_func () {
            if (filter.strip ().length == 0) {
                items_found++;
                foreach (var child in playlists.get_children ()) {
                    child.show ();
                }
                return;
            }

            string[] filter_elements = filter.strip ().down ().split (" ");
            foreach (var child in playlists.get_children ()) {
                child.show ();
                var playlist = (child as Widgets.Playlist).playlist;

                bool findings = true;

                foreach (string filter_element in filter_elements) {
                    if (!playlist.title.down ().contains (filter_element)) {
                        bool track_title = false;
                        foreach (var track in playlist.tracks) {
                            if (track.title.down ().contains (filter_element) || track.album.title.down ().contains (filter_element) || track.album.artist.name.down ().contains (filter_element)) {
                                track_title = true;
                            }
                        }
                        if (track_title) {
                            continue;
                        }
                        findings = false;
                        child.hide ();
                    }
                }
                if (findings) {
                    child.show ();
                    items_found++;
                }
            }
        }
    }
}
