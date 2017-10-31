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
    public class TrackTimeLine : Gtk.Grid {
        PlayMyMusic.Services.Player player;
        public signal void goto_current_track (PlayMyMusic.Objects.Track current_track);

        Gtk.Label playing_track;
        Granite.SeekBar timeline;

        PlayMyMusic.Objects.Track current_track;

        construct {
            player = PlayMyMusic.Services.Player.instance;
            player.current_progress_changed.connect ((progress) => {
                timeline.playback_progress = progress;
                if (timeline.playback_duration == 0) {
                    timeline.playback_duration = player.duration / Gst.SECOND;
                }
            });
            player.current_duration_changed.connect ((duration) => {
                timeline.playback_duration = duration / Gst.SECOND;
            });
        }

        public TrackTimeLine () {
            build_ui ();
        }

        private void build_ui () {
            this.margin_left = 32;
            this.margin_right = 32;

            var content = new Gtk.Grid ();

            playing_track = new Gtk.Label ("");
            playing_track.use_markup = true;
            playing_track.ellipsize = Pango.EllipsizeMode.END;
            playing_track.set_has_window (true);
            playing_track.events |= Gdk.EventMask.BUTTON_RELEASE_MASK;
            playing_track.button_release_event.connect (() => {
                goto_current_track (current_track);
                return false;
            });
            content.attach (playing_track, 0, 0);

            timeline = new Granite.SeekBar (0);
            timeline.scale.change_value.connect ((scroll, new_value) => {
                if (scroll == Gtk.ScrollType.JUMP) {
                    PlayMyMusic.Services.Player.instance.seek_to_progress (new_value);
                }
                return false;
            });
            content.attach (timeline, 0, 1);

            this.add (content);
            this.show_all ();
        }

        public void set_playing_file (File file) {
            current_track = null;
            playing_track.label = file.get_basename ().replace ("&", "&amp;");
        }

        public void set_playing_track (PlayMyMusic.Objects.Track track) {
            current_track = track;
            if (track.album != null) {
                playing_track.label = _("<b>%s</b> from <b>%s</b> by <b>%s</b>").printf (track.title.replace ("&", "&amp;"),
                    track.album.title.replace ("&", "&amp;"),
                    track.album.artist.name.replace ("&", "&amp;"));
            } else if (track.audio_cd != null) {
                playing_track.label = _("<b>%s</b> from <b>%s</b> by <b>%s</b>").printf (track.title, track.audio_cd.title, track.audio_cd.artist);
            }
        }
    }
}
