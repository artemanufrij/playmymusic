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
    public class AlbumView : Gtk.Grid {
        Services.LibraryManager library_manager;
        Services.Player player;
        Settings settings;

        Gtk.Menu menu;
        Gtk.Image cover;
        Gtk.ListBox tracks;

        bool only_mark = false;

        public Objects.Album current_album { get; private set; }

        construct {
            settings = Settings.get_default ();
            library_manager = Services.LibraryManager.instance;
            player = library_manager.player;
            player.state_changed.connect ((state) => {
                mark_playing_track (player.current_track);
            });
        }

        public AlbumView () {
            build_ui ();
        }

        private void build_ui () {
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.vexpand = true;
            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            cover = new Gtk.Image ();
            event_box.add (cover);

            menu = new Gtk.Menu ();
            var menu_new_cover = new Gtk.MenuItem.with_label (_("Set new Cover…"));
            menu_new_cover.activate.connect (() => {
                var new_cover = library_manager.choose_new_cover ();
                if (new_cover != null) {
                    try {
                        var pixbuf = new Gdk.Pixbuf.from_file (new_cover);
                        current_album.set_new_cover (pixbuf, 256);
                        if (settings.save_custom_covers) {
                            current_album.set_custom_cover_file (new_cover);
                        }
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
            });
            menu.append (menu_new_cover);
            menu.show_all ();

            var tracks_scroll = new Gtk.ScrolledWindow (null, null);

            tracks = new Gtk.ListBox ();
            tracks.set_sort_func (tracks_sort_func);
            tracks.selected_rows_changed.connect (play_track);
            tracks_scroll.add (tracks);

            content.pack_start (event_box, false, false, 0);
            content.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false, 0);
            content.pack_start (tracks_scroll, true, true, 0);

            var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);
            this.attach (separator, 0, 0);
            this.attach (content, 1, 0);
        }

        public void mark_playing_track (Objects.Track? track) {
            tracks.unselect_all ();
            if (track == null) {
                return;
            }
            foreach (var child in tracks.get_children ()) {
                if ((child as Widgets.Track).track.ID == track.ID) {
                    only_mark = true;
                    child.activate ();
                    only_mark = false;
                    return;
                }
            }
        }

        public void play_album () {
            Objects.Track? track;
            if (settings.shuffle_mode) {
                track = current_album.get_shuffle_track (null);
            } else {
                track = current_album.get_first_track ();
            }
            library_manager.play_track (track, Services.PlayMode.ALBUM);
        }

        private void play_track () {
            var selected_row = tracks.get_selected_row ();
            if (selected_row != null && !only_mark) {
                library_manager.play_track ((selected_row as Widgets.Track).track, Services.PlayMode.ALBUM);
            }
        }

        public void show_album (Objects.Album album) {
            if (current_album == album) {
                return;
            }

            if (current_album != null) {
                current_album.track_added.disconnect (add_track);
                current_album.cover_changed.disconnect (change_cover);
            }
            current_album = album;

            reset ();
            if (current_album.cover == null) {
                cover.set_from_icon_name ("audio-x-generic-symbolic", Gtk.IconSize.DIALOG);
                cover.height_request = 256;
                cover.width_request = 256;
            } else {
                cover.pixbuf = current_album.cover;
            }

            foreach (var track in current_album.tracks) {
                add_track (track);
            }
            current_album.track_added.connect (add_track);
            current_album.cover_changed.connect (change_cover);
        }

        private void reset () {
            foreach (var child in tracks.get_children ()) {
                child.destroy ();
            }
        }

        private void change_cover () {
            cover.pixbuf = current_album.cover;
        }

        private void add_track (Objects.Track track) {
            if (track.file_exists ()) {
                Idle.add (() => {
                    var item = new Widgets.Track (track);
                    tracks.add (item);
                    if (player.current_track != null && player.current_track.ID == track.ID) {
                        item.activate ();
                    }
                    return false;
                });
            }
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }

        private int tracks_sort_func (Gtk.ListBoxRow child1, Gtk.ListBoxRow child2) {
            var item1 = (Widgets.Track)child1;
            var item2 = (Widgets.Track)child2;
            if (item1 != null && item2 != null) {
                if (item1.disc_number != item2.disc_number){
                    return item1.disc_number - item2.disc_number;
                }
                if (item1.track_number != item2.track_number){
                    return item1.track_number - item2.track_number;
                }
                return item1.title.collate (item2.title);
            }
            return 0;
        }
    }
}
