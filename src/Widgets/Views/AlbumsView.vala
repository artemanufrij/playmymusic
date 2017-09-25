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

        Gtk.FlowBox albums;
        Widgets.AlbumView album_view;

        string query = "";
        int lock_dummy;

        public signal void album_selected ();

        construct {
            settings = PlayMyMusic.Settings.get_default ();
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.added_new_album.connect((album) => {
                var a = new Widgets.Album (album);
                a.show_all ();
                lock (lock_dummy) {
                    albums.add (a);
                }
            });
            library_manager.player_state_changed.connect ((state) => {
                if (state == Gst.State.PLAYING) {
                    album_view.mark_playing_track (library_manager.player.current_track);
                } else if (state == Gst.State.NULL) {
                    album_view.mark_playing_track (null);
                }
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
            albums.selection_mode = Gtk.SelectionMode.NONE;
            albums.max_children_per_line = 24;
            albums.valign = Gtk.Align.START;
            albums.set_sort_func (albums_sort_func);
            albums.set_filter_func (albums_filter_func);
            albums.child_activated.connect (show_album_viewer);
            var albums_scroll = new Gtk.ScrolledWindow (null, null);

            albums_scroll.add (albums);

            album_view = new PlayMyMusic.Widgets.AlbumView ();

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.expand = true;
            box.pack_start (albums_scroll, true, true, 0);
            box.pack_start (album_view, false, false, 0);

            this.add (box);
            this.show_all ();
        }

        public void hide_album_details () {
            album_view.hide ();
        }

        public void reset () {
            album_view.hide ();
            foreach (var item in albums.get_children ()) {
                albums.remove (item);
            }
        }

        private void show_album_viewer (Gtk.FlowBoxChild item) {
            var album = (item as PlayMyMusic.Widgets.Album);
            album_view.show_album_viewer (album.album);
            if (library_manager.player.current_track != null) {
                album_view.mark_playing_track (library_manager.player.current_track);
            }
            album_selected ();
        }

        public void play_selected_album () {
            if (album_view.visible) {
                album_view.play_album ();
            }
        }

        public void load_albums_from_database () {
            show_albums_from_database.begin ((obj, res) => {
                library_manager.scan_local_library (settings.library_location);
            });
        }

        private async void show_albums_from_database () {
            foreach (var artist in library_manager.artists) {
                foreach (var album in artist.albums) {
                    var a = new Widgets.Album (album);
                    a.show_all ();
                    albums.add (a);
                }
            }
        }

        public void filter (string query) {
            this.query = query.strip ().down ();
        }

        private bool albums_filter_func (Gtk.FlowBoxChild child) {
            if (query.length == 0) {
                return true;
            }

            string[] filter_elements = query.split (" ");
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
                    if (item1.year > 0 && item2.year > 0) {
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
