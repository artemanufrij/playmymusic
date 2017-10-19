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
    public class AudioCDView : Gtk.Grid {
        PlayMyMusic.Services.LibraryManager library_manager;
        public PlayMyMusic.Objects.AudioCD? current_audio_cd { get; private set; }

        Gtk.ListBox tracks;

        bool only_mark = false;

         construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            var player = library_manager.player;
            player.state_changed.connect ((state) => {
                mark_playing_track (player.current_track);
            });
        }

        public AudioCDView () {
            build_ui ();
        }

        private void build_ui () {
            tracks = new Gtk.ListBox ();
            tracks.expand = true;
            tracks.selected_rows_changed.connect (play_track);

            this.add (tracks);
            this.show_all ();
        }

        public void show_audio_cd (PlayMyMusic.Objects.AudioCD audio_cd) {
            if (current_audio_cd == audio_cd) {
                return;
            }
            if (current_audio_cd != null) {
                current_audio_cd.track_added.disconnect (add_track);
            }
            current_audio_cd = audio_cd;

            foreach (var track in current_audio_cd.tracks) {
                add_track (track);
            }
            current_audio_cd.track_added.connect (add_track);
        }

        public void mark_playing_track (Objects.Track? track) {
            tracks.unselect_all ();
            if (track == null) {
                return;
            }
            foreach (var child in tracks.get_children ()) {
                if ((child as Widgets.Track).track.uri == track.uri) {
                    only_mark = true;
                    (child as Widgets.Track).activate ();
                    only_mark = false;
                }
            }
        }

        private void add_track (PlayMyMusic.Objects.Track track) {
            var item = new PlayMyMusic.Widgets.Track (track, false);
            this.tracks.add (item);
            item.show_all ();
        }

        public void reset () {
            foreach (var child in tracks.get_children ()) {
                child.destroy ();
            }
            current_audio_cd = null;
        }

        private void play_track () {
            var selected_row = tracks.get_selected_row ();
            if (selected_row != null && !only_mark) {
                library_manager.play_track ((selected_row as Widgets.Track).track, Services.PlayMode.AUDIO_CD);
            }
        }
    }
}
