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
    public class AlbumsView : Gtk.Grid {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Settings settings;

        private string _filter = "";
        public string filter {
            get {
                return _filter;
            } set {
                if (_filter != value) {
                    _filter = value;
                    albums.invalidate_filter ();
                }
            }
        }

        Gtk.FlowBox albums;
        Gtk.Stack stack;
        Gtk.Box content;
        Gtk.Revealer action_revealer;
        Widgets.Views.AlbumView album_view;

        public bool is_album_view_visible {
            get {
                return album_view.visible;
            }
        }

        public signal void album_selected ();

        construct {
            settings = PlayMyMusic.Settings.get_default ();
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.added_new_album.connect ((album) => {
                Idle.add (() => {
                    add_album (album);
                });
            });
        }

        public AlbumsView () {
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
            albums.set_sort_func (albums_sort_func);
            albums.set_filter_func (albums_filter_func);
            albums.child_activated.connect (show_album_viewer);
            albums.add.connect (() => {
                if (stack.get_visible_child () != content) {
                    stack.set_visible_child (content);
                }
            });
            var albums_scroll = new Gtk.ScrolledWindow (null, null);

            albums_scroll.add (albums);

            album_view = new PlayMyMusic.Widgets.Views.AlbumView ();

            action_revealer = new Gtk.Revealer ();
            action_revealer.add (album_view);
            action_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;

            content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            content.expand = true;
            content.pack_start (albums_scroll, true, true, 0);
            content.pack_start (action_revealer, false, false, 0);

            var welcome = new Granite.Widgets.Welcome ("Get Some Tunes", "Add music to your library.");
            welcome.append ("folder-music", _("Change Music Folder"), _("Load music from a folder, a network or an external disk."));
            welcome.append ("document-import", _("Import Music"), _("Import music from a source into your library."));
            welcome.activated.connect ((index) => {
                switch (index) {
                    case 0:
                        var folder = library_manager.choose_folder ();
                        if(folder != null) {
                            settings.library_location = folder;
                            library_manager.scan_local_library (folder);
                        }
                        break;
                    case 1:
                        var folder = library_manager.choose_folder ();
                        if(folder != null) {
                            library_manager.scan_local_library (folder);
                        }
                        break;
                }
            });

            stack = new Gtk.Stack ();
            stack.add_named (welcome, "welcome");
            stack.add_named (content, "content");

            this.add (stack);
            this.show_all ();

            action_revealer.set_reveal_child (false);
        }

        public void add_album (Objects.Album album) {
            lock (albums) {
                var a = new Widgets.Album (album);
                albums.add (a);
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
            action_revealer.set_reveal_child (false);
            foreach (var child in albums.get_children ()) {
                child.destroy ();
            }
            stack.set_visible_child_name ("welcome");
        }

        private void show_album_viewer (Gtk.FlowBoxChild item) {
            action_revealer.set_reveal_child (true);
            var album = (item as PlayMyMusic.Widgets.Album).album;
            settings.last_album_id = album.ID;
            album_view.show_album (album);
            album_selected ();
        }

        public void play_selected_album () {
            if (album_view.current_album != null) {
                album_view.play_album ();
            }
        }

        public bool open_file (string path) {
            foreach (var child in albums.get_children ()) {
                var album = child as PlayMyMusic.Widgets.Album;
                foreach (var track in album.album.tracks) {
                    if (track.path == path) {
                        album.activate ();
                        library_manager.play_track (track , Services.PlayMode.ALBUM);
                        return true;
                    }
                }
            }
            return false;
        }

        public void unselect_all () {
            albums.unselect_all ();
            action_revealer.set_reveal_child (false);
        }


        private bool albums_filter_func (Gtk.FlowBoxChild child) {
            if (filter.strip ().length == 0) {
                return true;
            }
            string[] filter_elements = filter.strip ().down ().split (" ");
            var album = (child as PlayMyMusic.Widgets.Album).album;
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
            return true;
        }

        private int albums_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = (PlayMyMusic.Widgets.Album)child1;
            var item2 = (PlayMyMusic.Widgets.Album)child2;
            if (item1 != null && item2 != null) {
                if (item1.album.artist.name == item2.album.artist.name) {
                    if (item1.year != item2.year) {
                        return item1.year - item2.year;
                    }
                    return item1.title.collate (item2.title);
                }
                return item1.album.artist.name.collate (item2.album.artist.name);
            }
            return 0;
        }
    }
}
