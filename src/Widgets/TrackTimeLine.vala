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
        public signal void goto_current_track (PlayMyMusic.Objects.Track current_track);
        Gtk.Label playing_track;
        Gtk.Grid content;

        Granite.SeekBar timeline;

        uint timer = 0;
        int64 duration = 0;

        PlayMyMusic.Objects.Track current_track;

        public TrackTimeLine () {
            build_ui ();
        }

        private void build_ui () {
            this.margin_left = 32;
            this.margin_right = 32;

            content = new Gtk.Grid ();
            content.row_spacing = 0;

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
                    var seek_position = (int64)(new_value * duration * 1000000000);
                    PlayMyMusic.Services.Player.instance.seek_to_position (seek_position);
                }
                return false;
            });
            content.attach (timeline, 0, 1);

            this.add (content);
            this.show_all ();
        }

        public void stop_playing () {
            if (timer != 0) {
                Source.remove (timer);
                timer = 0;
            }
            timeline.playback_progress = 0;
        }

        public void pause_playing () {
            if (timer != 0) {
                Source.remove (timer);
                timer = 0;
            }
        }

        public void set_playing_file (File file) {
            current_track = null;
            playing_track.label = file.get_basename ().replace ("&", "&amp;");

            timer = GLib.Timeout.add (250, () => {
                var pos_rel = PlayMyMusic.Services.Player.instance.get_position_progress ();
                if (pos_rel < 0) {
                    return true;
                }
                duration = PlayMyMusic.Services.Player.instance.duration / 1000000000;
                if (timeline.playback_duration != duration) {
                    timeline.playback_duration = duration;
                }
                timeline.playback_progress = pos_rel;
                return true;
            });
        }

        public void set_playing_track (PlayMyMusic.Objects.Track track) {
            current_track = track;

            playing_track.label = _("<b>%s</b> from <b>%s</b> by <b>%s</b>").printf (track.title.replace ("&", "&amp;"),
                track.album.title.replace ("&", "&amp;"),
                track.album.artist.name.replace ("&", "&amp;"));

            duration = (int64)track.duration / 1000000000;
            timeline.playback_duration = duration;

            timer = GLib.Timeout.add (250, () => {
                var pos_rel = PlayMyMusic.Services.Player.instance.get_position_progress ();
                if (pos_rel < 0) {
                    return true;
                }
                timeline.playback_progress = pos_rel;
                return true;
            });
        }
    }
}
