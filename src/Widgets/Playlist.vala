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

namespace PlayMyMusic.Widgets {
    public class Playlist : Gtk.FlowBoxChild {
        PlayMyMusic.Services.LibraryManager library_manager;

        public PlayMyMusic.Objects.Playlist playlist { get; private set; }
        public string title { get { return playlist.title; } }

        Gtk.ListBox tracks;
        Gtk.Menu menu;

        public signal void track_selected ();

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;

            Granite.Widgets.Utils.set_theming_for_screen (
                this.get_screen (),
                """
                    .track-list {
                        background: transparent;
                    }
                    .header {
                        padding: 6px;
                    }
                """,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }

        public Playlist (PlayMyMusic.Objects.Playlist playlist) {
            this.playlist = playlist;

            this.playlist.track_added.connect ((track) => {
                add_track (track);
            });

            build_ui ();

            show_tracks ();
        }

        private void build_ui () {
            this.can_focus = false;
            this.width_request = 256;

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.spacing = 12;

            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            var title = new Gtk.Label (this.playlist.title);
            title.margin = 4;
            title.get_style_context ().add_class ("h2");
            title.get_style_context ().add_class ("header");
            title.get_style_context ().add_class ("card");
            event_box.add (title);

            menu = new Gtk.Menu ();
            var menu_remove_playlist = new Gtk.MenuItem.with_label (_("Remove Playlist"));
            menu_remove_playlist.activate.connect (() => {
                library_manager.remove_playlist (playlist);
            });
            menu.add (menu_remove_playlist);
            var menu_rename_playlist = new Gtk.MenuItem.with_label (_("Rename Playlist"));
            menu.add (menu_rename_playlist);

            menu.show_all ();

            tracks = new Gtk.ListBox ();
            tracks.get_style_context ().add_class ("track-list");
            tracks.selected_rows_changed.connect (play_track);

            var tracks_scroll = new Gtk.ScrolledWindow (null, null);
            tracks_scroll.expand = true;

            tracks_scroll.add (tracks);

            content.pack_start (event_box, false, false, 0);
            content.pack_start (tracks_scroll, true, true, 0);

            this.add (content);
        }

        private void show_tracks () {
            tracks.unselect_all ();
            foreach (var track in this.playlist.tracks) {
                add_track (track);
            }
        }

        private void add_track (PlayMyMusic.Objects.Track track) {
            var item = new PlayMyMusic.Widgets.Track (track);
            this.tracks.add (item);
            item.show_all ();
        }

        private void play_track () {
            var selected_row = tracks.get_selected_row ();
            if (selected_row != null) {
                library_manager.play_track ((selected_row as Widgets.Track).track, Services.PlayMode.PLAYLIST);
                track_selected ();
            }
        }

        public void unselect_all () {
            tracks.unselect_all ();
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }
    }
}
