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

namespace PlayMyMusic.Services {
    public class Player : GLib.Object {
        static Player _instance = null;
        public static Player instance {
            get {
                if (_instance == null) {
                    _instance = new Player ();
                }
                return _instance;
            }
        }

        dynamic Gst.Element playbin;
        Gst.Bus bus;

        public PlayMyMusic.Objects.Track current_track { get; private set; }
        public bool play_mode_repeat { get; set; default = false; }
        public bool play_mode_shuffle { get; set; default = false; }

        public signal void state_changed (Gst.State state);

        private Player () {
            playbin = Gst.ElementFactory.make ("playbin", "play");

            bus = playbin.get_bus ();
            bus.add_watch (0, bus_callback);
            bus.enable_sync_message_emission();

            state_changed.connect ((state) => {
                if (state != Gst.State.NULL) {
                    playbin.set_state (state);
                }
            });
        }

        public void set_track (PlayMyMusic.Objects.Track? track) {
            if (track == current_track || track == null) {
                return;
            }

            current_track = track;

            var file = File.new_for_path (track.path);
            if (!file.query_exists ()) {
                track.path_not_found ();
                next ();
                return;
            }            
            stop ();
            playbin.uri = current_track.uri;
            play ();
        }

        public void play () {
            if (current_track != null) {
                state_changed (Gst.State.PLAYING);
            }
        }

        public void pause () {
            state_changed (Gst.State.PAUSED);
        }

        public void stop () {
            state_changed (Gst.State.READY);
        }

        public void next () {
            var next_track = current_track.album.get_next_track (current_track);
            if (next_track != null) {
                set_track (next_track);
            } else {
                if (play_mode_repeat) {
                    next_track = current_track.album.get_first_track ();
                    if (next_track != null) {
                        set_track (next_track);
                    } else {
                        current_track = null;
                    }
                } else {
                    current_track = null;
                }
            }
        }

        public void prev () {
            var prev_track = current_track.album.get_prev_track (current_track);
            if (prev_track != null) {
                set_track (prev_track);
            } else {
                current_track = null;
            }
        }

        public void toggle_playing () {
            Gst.State state = Gst.State.NULL;
            Gst.State pending;
            playbin.get_state (out state, out pending, (Gst.ClockTime) (Gst.SECOND));
            if (state == Gst.State.PLAYING) {
                pause ();
            } else if (state == Gst.State.PAUSED || state == Gst.State.READY) {
                play ();
            }
        }

        private bool bus_callback (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
            case Gst.MessageType.ERROR:
                GLib.Error err;
                string debug;
                message.parse_error (out err, out debug);
                stdout.printf ("Error: %s\n", err.message);
                break;
            case Gst.MessageType.EOS:
                state_changed (Gst.State.NULL);
                next ();
                break;
            default:
                break;
            }
            return true;
        }

        public void seek_to_position (int64 position) {
            Gst.Format fmt = Gst.Format.TIME;
            playbin.seek_simple (fmt, Gst.SeekFlags.FLUSH, position);
        }

        public unowned double get_position_progress () {
            Gst.Format fmt = Gst.Format.TIME;
            int64 current = 0;
            double duration = (double)1000 / current_track.duration;
            if (this.playbin.query_position (fmt, out current)) {
                int p = (int)(duration * current);
                return (double)p;
            }
            return -1;
        }
    }
}
