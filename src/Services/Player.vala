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

namespace PlayMyMusic.Services {

    public enum PlayMode { NONE, TRACKS, ALBUM, ARTIST, PLAYLIST, FILE, RADIO, AUDIO_CD }

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

        public signal void state_changed (Gst.State state);
        public signal void current_progress_changed (double percent);
        public signal void current_duration_changed (int64 duration);
        public signal Objects.Track? next_track_request ();
        public signal Objects.Track? prev_track_request ();
        uint progress_timer = 0;

        Settings settings;

        Gst.Format fmt = Gst.Format.TIME;
        dynamic Gst.Element playbin;
        Gst.Bus bus;

        public Objects.Track? current_track { get; set; }
        public Objects.Radio? current_radio { get; private set; }
        public File? current_file { get; private set; }

        PlayMode _play_mode = PlayMode.NONE;
        public PlayMode play_mode {
            get {
                return _play_mode;
            }
            private set {
                current_radio = null;
                current_track = null;
                current_file = null;
                _play_mode = value;
            }
        }

        public unowned int64 duration {
            get {
                int64 d = 0;
                this.playbin.query_duration (fmt, out d);
                return d;
            }
        }

        public unowned int64 position {
            get {
                int64 d = 0;
                this.playbin.query_position (fmt, out d);
                return d;
            }
        }

        public double target_progress { get; set; default = 0; }

        private Player () {
            settings = Settings.get_default ();
            playbin = Gst.ElementFactory.make ("playbin", "play");

            bus = playbin.get_bus ();
            bus.add_watch (0, bus_callback);
            bus.enable_sync_message_emission();

            state_changed.connect ((state) => {
                stop_progress_signal ();
                if (state != Gst.State.NULL) {
                    playbin.set_state (state);
                } else {
                    Interfaces.Inhibitor.instance.uninhibit ();
                }
                switch (state) {
                    case Gst.State.PLAYING:
                        start_progress_signal ();
                        Interfaces.Inhibitor.instance.inhibit ();
                        break;
                    case Gst.State.READY:
                        stop_progress_signal (true);
                        Interfaces.Inhibitor.instance.uninhibit ();
                        break;
                    case Gst.State.PAUSED:
                        pause_progress_signal ();
                        Interfaces.Inhibitor.instance.uninhibit ();
                        break;
                }
            });
        }

        public void pause_progress_signal () {
            if (progress_timer != 0) {
                Source.remove (progress_timer);
                progress_timer = 0;
            }
        }

        public void stop_progress_signal (bool reset_timer = false) {
            pause_progress_signal ();
            if (reset_timer) {
                current_progress_changed (0);
            }
        }

        public void start_progress_signal () {
            pause_progress_signal ();
            progress_timer = GLib.Timeout.add (250, () => {
                current_progress_changed (get_position_progress ());
                return true;
            });
        }

        public void set_radio (Objects.Radio? radio) {
            if (radio == current_radio || radio == null || radio.file == null) {
                return;
            }
            play_mode = PlayMode.RADIO;
            current_radio = radio;
            stop ();
            playbin.uri = radio.file;
            play ();
        }

        public bool load_track (Objects.Track? track, PlayMode play_mode, double progress = 0) {
            if (track == current_track || track == null) {
                return false;
            }
            this.play_mode = play_mode;
            current_track = track;

            if (play_mode != PlayMode.AUDIO_CD && !track.file_exists ()) {
                next ();
                return false;
            }

            var last_state = get_state ();

            stop ();
            if (current_track.uri.has_prefix ("cdda://")) {
                playbin.uri = "cdda://%d".printf (current_track.track);
            } else {
                playbin.uri = current_track.uri;
            }

            playbin.set_state (Gst.State.PLAYING);
            while (duration == 0) {};
            if (last_state != Gst.State.PLAYING) {
                pause ();
            }
            current_duration_changed (duration);

            if (progress > 0) {
                seek_to_progress (progress);
                current_progress_changed (progress);
            }

            return true;
        }

        public void set_track (Objects.Track? track, PlayMode play_mode) {
            if (track == null) {
                current_duration_changed (0);
            }
            if (load_track (track, play_mode)) {
                play ();
            }
        }

        public void set_file (File file) {
            current_duration_changed (0);
            play_mode = PlayMode.FILE;
            current_file = file;

            stop ();
            playbin.uri = file.get_uri ();
            play ();
            current_duration_changed (duration);
        }

        public void play () {
            if (current_track != null || current_radio != null || current_file != null) {
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
            if (current_track == null) {
                return;
            }

            Objects.Track? next_track = null;

            if (settings.repeat_mode == RepeatMode.ONE) {
                next_track = current_track;
                current_track = null;
            } else {
                if (play_mode == PlayMode.ALBUM) {
                    if (settings.shuffle_mode) {
                        next_track = current_track.album.get_shuffle_track (current_track);
                    } else {
                        next_track = current_track.album.get_next_track (current_track);
                    }

                    if (next_track == null && settings.repeat_mode != RepeatMode.OFF && current_track.album.has_available_tracks ()) {
                        if (settings.shuffle_mode) {
                            next_track = current_track.album.get_shuffle_track (null);
                        } else {
                            next_track = current_track.album.get_first_track ();
                        }
                    }
                } else if (play_mode == PlayMode.ARTIST) {
                    if (settings.shuffle_mode) {
                        next_track = current_track.album.artist.get_shuffle_track (current_track);
                    } else {
                        next_track = current_track.album.artist.get_next_track (current_track);
                    }

                    if (next_track == null && settings.repeat_mode != RepeatMode.OFF && current_track.album.artist.has_available_tracks ()) {
                        if (settings.shuffle_mode) {
                            next_track = current_track.album.artist.get_shuffle_track (null);
                        } else {
                            next_track = current_track.album.artist.get_first_track ();
                        }
                    }
                } else if (play_mode == PlayMode.PLAYLIST) {
                    if (settings.shuffle_mode && current_track.playlist.title != PlayMyMusicApp.instance.QUEUE_SYS_NAME) {
                        next_track = current_track.playlist.get_shuffle_track (current_track);
                    } else {
                        next_track = current_track.playlist.get_next_track (current_track);
                    }

                    if (next_track == null && settings.repeat_mode != RepeatMode.OFF && current_track.playlist.has_available_tracks ()) {
                        if (settings.shuffle_mode && current_track.playlist.title != PlayMyMusicApp.instance.QUEUE_SYS_NAME) {
                            next_track = current_track.playlist.get_shuffle_track (null);
                        } else {
                            next_track = current_track.playlist.get_first_track ();
                        }
                    }
                } else if (play_mode == PlayMode.AUDIO_CD) {
                    if (settings.shuffle_mode) {
                        next_track = current_track.audio_cd.get_shuffle_track (current_track);
                    } else {
                        next_track = current_track.audio_cd.get_next_track (current_track);
                    }

                    if (next_track == null && settings.repeat_mode != RepeatMode.OFF) {
                        if (settings.shuffle_mode) {
                            next_track = current_track.audio_cd.get_shuffle_track (null);
                        } else {
                            next_track = current_track.audio_cd.get_first_track ();
                        }
                    }
                } else if (play_mode == PlayMode.TRACKS) {
                    next_track = next_track_request ();
                }
            }

            if (next_track != null) {
                set_track (next_track, play_mode);
            } else {
                state_changed (Gst.State.NULL);
            }
        }

        public void prev () {
            if (current_track == null) {
                return;
            }

            if (get_position_sec () < 1) {
                Objects.Track? prev_track = null;
                if (play_mode == PlayMode.ALBUM) {
                    prev_track = current_track.album.get_prev_track (current_track);
                } else if (play_mode == PlayMode.ARTIST) {
                    prev_track = current_track.album.artist.get_prev_track (current_track);
                } else if (play_mode == PlayMode.PLAYLIST) {
                    prev_track = current_track.playlist.get_prev_track (current_track);
                } else if (play_mode == PlayMode.TRACKS) {
                    prev_track = prev_track_request ();
                }
                if (prev_track != null) {
                    set_track (prev_track, play_mode);
                }
            } else {
                stop ();
                play ();
            }
        }

        public void reset_playing () {
            if (current_track != null || current_radio != null || current_file != null) {
                state_changed (Gst.State.READY);
                state_changed (Gst.State.NULL);
            }
            play_mode = PlayMode.NONE;
        }

        public void toggle_playing () {
            var state = get_state ();
            if (state == Gst.State.PLAYING) {
                pause ();
            } else if (state == Gst.State.PAUSED || state == Gst.State.READY) {
                play ();
            }
        }

        public Gst.State get_state () {
            Gst.State state = Gst.State.NULL;
            Gst.State pending;
            playbin.get_state (out state, out pending, (Gst.ClockTime) (Gst.SECOND));
            return state;
        }

        public void set_playmode (PlayMode play_mode) {
            _play_mode = play_mode;
        }

        private bool bus_callback (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
            case Gst.MessageType.ERROR:
                GLib.Error err;
                string debug;
                message.parse_error (out err, out debug);
                warning ("Error: %s\n%s\n", err.message, debug);
                break;
            case Gst.MessageType.EOS:
                next ();
                break;
            default:
                break;
            }
            return true;
        }

        public void seek_to_position (int64 position) {
            playbin.seek_simple (fmt, Gst.SeekFlags.FLUSH, position);
        }

        public void seek_to_progress (double percent) {
            seek_to_position ((int64)(percent * duration));
        }

        private unowned int64 get_position_sec () {
            int64 current = position;
            return current > 0 ? current / Gst.SECOND : -1;
        }

        public unowned double get_position_progress () {
            return (double) 1 / duration * position;
        }
    }
}
