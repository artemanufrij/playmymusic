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
    public class TrackTimeLine : Gtk.Stack {
        Gtk.Label playing_track;
        Gtk.Label end_time;
        Gtk.Label current_time;
        Gtk.Scale timeline;
        Gtk.Grid content;

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
            content.column_spacing = 6;
            content.row_spacing = 0;

            current_time = new Gtk.Label ("0:00");
            content.attach (current_time, 0, 1);

            end_time = new Gtk.Label ("0:00");
            content.attach (end_time, 2, 1);

            playing_track = new Gtk.Label ("");
            playing_track.use_markup = true;
            playing_track.ellipsize = Pango.EllipsizeMode.END;
            content.attach (playing_track, 1, 0);

            timeline = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1000, 1);
            timeline.draw_value = false;
            timeline.can_focus = false;
            timeline.change_value.connect ((scroll, new_value) => {
                if (scroll == Gtk.ScrollType.JUMP) {
                    var seek_position = (int64)(duration / 1000 * new_value);
                    PlayMyMusic.Services.Player.instance.seek_to_position (seek_position);
                }
                return false;
            });
            content.attach (timeline, 1, 1);

            this.add_named (content, "timeline");
            this.show_all ();
        }

        public void stop_playing () {
            if (timer != 0) {
                Source.remove (timer);
                timer = 0;
            }
            timeline.change_value (Gtk.ScrollType.NONE, 0);
            current_time.label = "0:00";
        }

        public void pause_playing () {
            if (timer != 0) {
                Source.remove (timer);
                timer = 0;
            }
        }

        public void set_playing_file (File file) {
            current_track = null;
            playing_track.label = file.get_basename ();

            end_time.label = PlayMyMusic.Utils.get_formated_duration (duration);
            timer = GLib.Timeout.add (250, () => {
                var pos_rel = PlayMyMusic.Services.Player.instance.get_position_progress ();
                if (pos_rel < 0) {
                    return true;
                }
                timeline.change_value (Gtk.ScrollType.NONE, pos_rel);
                duration = PlayMyMusic.Services.Player.instance.duration;
                end_time.label = PlayMyMusic.Utils.get_formated_duration (duration);

                var pos_abs = (uint64)(duration * (pos_rel / 1000));
                current_time.label = PlayMyMusic.Utils.get_formated_duration (pos_abs);
                return true;
            });
        }

        public void set_playing_track (PlayMyMusic.Objects.Track track) {
            current_track = track;

            playing_track.label = _("<b>%s</b> from <b>%s</b> by <b>%s</b>").printf (track.title.replace ("&", "&amp;"),
                track.album.title.replace ("&", "&amp;"),
                track.album.artist.name.replace ("&", "&amp;"));

            duration = (int64)track.duration;
            end_time.label = PlayMyMusic.Utils.get_formated_duration (track.duration);

            timer = GLib.Timeout.add (250, () => {
                var pos_rel = PlayMyMusic.Services.Player.instance.get_position_progress ();
                if (pos_rel < 0) {
                    return true;
                }
                timeline.change_value (Gtk.ScrollType.NONE, pos_rel);

                var pos_abs = (uint64)(track.duration * (pos_rel / 1000));
                current_time.label = PlayMyMusic.Utils.get_formated_duration (pos_abs);
                return true;
            });
        }
    }
}
