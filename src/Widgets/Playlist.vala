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

        PlayMyMusic.Objects.Playlist playlist { get; private set; }

        Gtk.ListBox tracks;

        public signal void track_selected ();

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
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

            var title = new Gtk.Label (this.playlist.title);
            title.get_style_context ().add_class ("h2");

            tracks = new Gtk.ListBox ();
            tracks.selected_rows_changed.connect (play_track);

            var tracks_scroll = new Gtk.ScrolledWindow (null, null);
            tracks_scroll.expand = true;

            tracks_scroll.add (tracks);

            content.pack_start (title, false, false, 0);
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
    }
}
