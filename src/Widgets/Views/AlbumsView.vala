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
    public class AlbumsView : Gtk.Grid {
        Services.LibraryManager library_manager;
        Settings settings;
        MainWindow mainwindow;

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

        Gtk.FlowBox albums;
        Gtk.Stack stack;
        Gtk.Box content;
        Gtk.Revealer album_revealer;

        Widgets.Views.AlbumView album_view;

        public bool is_album_view_visible {
            get {
                return album_view.visible;
            }
        }

        public signal void album_selected ();

        uint timer_sort = 0;
        uint items_found = 0;

        construct {
            settings = Settings.get_default ();
            settings.notify["sort-mode-album-view"].connect (() => {
                do_sort ();
            });
            library_manager = Services.LibraryManager.instance;
            library_manager.added_new_album.connect ((album) => {
                Idle.add (() => {
                    add_album (album);
                    return false;
                });
            });
        }

        public AlbumsView (MainWindow mainwindow) {
            this.mainwindow = mainwindow;
            this.mainwindow.ctrl_press.connect (() => {
                foreach (var child in albums.get_selected_children ()) {
                    var album = child as PlayMyMusic.Widgets.Album;
                    if (!album.multi_selection) {
                        album.toggle_multi_selection (false);
                    }
                }
            });
            build_ui ();
        }

        private void build_ui () {
            albums = new Gtk.FlowBox ();
            albums.margin = 24;
            albums.homogeneous = true;
            albums.row_spacing = 12;
            albums.column_spacing = 24;
            albums.max_children_per_line = 24;
            albums.valign = Gtk.Align.START;
            albums.selection_mode = Gtk.SelectionMode.MULTIPLE;
            albums.set_filter_func (albums_filter_func);
            albums.child_activated.connect (show_album_viewer);
            albums.add.connect (() => {
                if (stack.get_visible_child () != content) {
                    stack.set_visible_child (content);
                }
            });
            var albums_scroll = new Gtk.ScrolledWindow (null, null);

            albums_scroll.add (albums);

            album_view = new Widgets.Views.AlbumView ();

            album_revealer = new Gtk.Revealer ();
            album_revealer.add (album_view);
            album_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;

            content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            content.expand = true;
            content.pack_start (albums_scroll, true, true, 0);
            content.pack_start (album_revealer, false, false, 0);

            var welcome = new Granite.Widgets.Welcome (_("Get Some Tunes"), _("Add music to your library."));
            welcome.append ("folder-music", _("Change Music Folder"), _("Load music from a folder, a network or an external disk."));
            welcome.append ("document-import", _("Import Music"), _("Import music from a source into your library."));
            welcome.activated.connect ((index) => {
                switch (index) {
                    case 0:
                        var folder = library_manager.choose_folder ();
                        if(folder != null) {
                            settings.library_location = folder;
                            library_manager.scan_local_library_for_new_files (folder);
                        }
                        break;
                    case 1:
                        var folder = library_manager.choose_folder ();
                        if(folder != null) {
                            library_manager.scan_local_library_for_new_files (folder);
                        }
                        break;
                }
            });

            var alert_view = new Granite.Widgets.AlertView (_("No results"), _("Try another search"), "edit-find-symbolic");

            stack = new Gtk.Stack ();
            stack.add_named (welcome, "welcome");
            stack.add_named (content, "content");
            stack.add_named (alert_view, "alert");

            this.add (stack);
            this.show_all ();

            album_revealer.reveal_child = false;
        }

        public void add_album (Objects.Album album) {
            var a = new Widgets.Album (album);
            lock (albums) {
                albums.add (a);
            }
            a.merge.connect (() => {
                GLib.List<Objects.Album> selected = new GLib.List<Objects.Album> ();
                foreach (var child in albums.get_selected_children ()){
                    selected.append ((child as Widgets.Album).album);
                }
                album.merge (selected);
            });
            do_sort ();
        }

        public void do_sort (bool instand = false) {
            if (instand) {
                albums.set_sort_func (albums_sort_func);
                albums.set_sort_func (null);
            } else {
                lock (timer_sort) {
                    if (timer_sort != 0) {
                        Source.remove (timer_sort);
                        timer_sort = 0;
                    }

                    timer_sort = Timeout.add (500, () => {
                        albums.set_sort_func (albums_sort_func);
                        albums.set_sort_func (null);
                        Source.remove (timer_sort);
                        timer_sort = 0;
                        return false;
                    });
                }
            }
        }

        private void do_filter () {
            if (stack.visible_child_name == "welcome") {
                return;
            }

            items_found = 0;
            albums.invalidate_filter ();
            if (items_found == 0) {
                stack.visible_child_name = "alert";
            } else {
                stack.visible_child_name = "content";
            }
        }

        public void activate_by_track (Objects.Track track) {
            activate_by_id (track.album.ID);
        }

        public Objects.Album? activate_by_id (int id) {
            foreach (var child in albums.get_children ()) {
                if ((child as Widgets.Album).album.ID == id) {
                    child.activate ();
                    return (child as Widgets.Album).album;
                }
            }
            return null;
        }

        public void reset () {
            filter = "";
            album_revealer.set_reveal_child (false);
            foreach (var child in albums.get_children ()) {
                child.destroy ();
            }
            stack.visible_child_name = "welcome";
        }

        private void show_album_viewer (Gtk.FlowBoxChild item) {
            if (mainwindow.ctrl_pressed) {
                if ((item as Widgets.Album).multi_selection) {
                    albums.unselect_child (item);
                    (item as Widgets.Album).reset ();
                    return;
                } else {
                    (item as Widgets.Album).toggle_multi_selection (false);
                }
            }
            if (!(item as Widgets.Album).multi_selection) {
                foreach (var child in albums.get_selected_children ()) {
                    (child as Widgets.Album).reset ();
                }
                albums.unselect_all ();
                albums.select_child (item);
            }

            album_revealer.set_reveal_child (true);
            var album = (item as Widgets.Album).album;
            settings.last_album_id = album.ID;
            album_view.show_album (album);
            album_selected ();
        }

        public void play_selected_album () {
            if (album_view.current_album != null) {
                album_view.play_album ();
            }
        }

        public bool open_file (string uri) {
            foreach (var child in albums.get_children ()) {
                var album = child as Widgets.Album;
                foreach (var track in album.album.tracks) {
                    if (track.uri == uri) {
                        album.activate ();
                        library_manager.play_track (track, Services.PlayMode.ALBUM);
                        return true;
                    }
                }
            }
            return false;
        }

        public void unselect_all () {
            album_revealer.set_reveal_child (false);
            foreach (var child in albums.get_selected_children ()) {
                (child as Widgets.Album).reset ();
            }
            albums.unselect_all ();
        }

        private bool albums_filter_func (Gtk.FlowBoxChild child) {
            if (filter.strip ().length == 0) {
                items_found ++;
                return true;
            }
            string[] filter_elements = filter.strip ().down ().split (" ");
            var album = (child as Widgets.Album).album;
            foreach (string filter_element in filter_elements) {
                if (!album.title.down ().contains (filter_element) && !album.artist.name.down ().contains (filter_element)) {
                    bool track_title = false;
                    foreach (var track in album.tracks) {
                        if (track.title.down ().contains (filter_element) || track.genre.down ().contains (filter_element)) {
                            track_title = true;
                        }
                    }
                    if (track_title) {
                        continue;
                    }
                    return false;
                }
            }
            items_found ++;
            return true;
        }

        private int albums_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = (Widgets.Album)child1;
            var item2 = (Widgets.Album)child2;

            if (item1 == null || item2 == null) {
                return 0;
            }

            switch (settings.sort_mode_album_view) {
                case 2:
                    // Album - Artist
                    if (item1.title == item2.title) {
                        return item1.album.artist.name.collate (item2.album.artist.name);
                    }
                    return item1.title.collate (item2.title);
                case 3:
                    // Artist - Album
                    if (item1.album.artist.name == item2.album.artist.name) {
                        return item1.title.collate (item2.title);
                    }
                    return item1.album.artist.name.collate (item2.album.artist.name);
                default:
                    // Artist - Year - Album
                    if (item1.album.artist.name == item2.album.artist.name) {
                        if (item1.year != item2.year) {
                            return item1.year - item2.year;
                        }
                        return item1.title.collate (item2.title);
                    }
                    return item1.album.artist.name.collate (item2.album.artist.name);
            }
        }
    }
}
