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
        Gtk.Scale timeline;

        PlayMyMusic.Objects.Track current_track;

        public TrackTimeLine () {
            build_ui ();
        }

        private void build_ui () {
            this.margin_left = 32;
            this.margin_right = 32;
            this.width_request = 380;
            this.transition_type = Gtk.StackTransitionType.CROSSFADE;

            var content = new Gtk.Grid ();
            content.column_spacing = 6;
            content.row_spacing = 0;
            var current_time = new Gtk.Label ("0:00");
            content.attach (current_time, 0, 1);

            end_time = new Gtk.Label ("0:00");
            content.attach (end_time, 2, 1);

            playing_track = new Gtk.Label ("");
            playing_track.use_markup = true;
            playing_track.ellipsize = Pango.EllipsizeMode.END;
            content.attach (playing_track, 1, 0);

            timeline = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1000, 1);
            timeline.hexpand = true;
            timeline.draw_value = false;
            timeline.can_focus = false;
            content.attach (timeline, 1, 1);

            var empty = new Gtk.Grid ();

            this.add_named (content, "timeline");
            this.add_named (empty, "empty");

            set_visible_child (empty);
        }

        public void set_playing_track (PlayMyMusic.Objects.Track track) {
            current_track = track;
            playing_track.label = _("<b>%s</b> from <b>%s</b> by <b>%s</b>").printf (track.title, track.album.title.replace ("&", "&amp;"), track.album.artist.name.replace ("&", "&amp;"));
            end_time.label = track.formated_duration ();
        }

        public void set_position (double position) {
            stdout.printf("%f \n", position);
            //timeline.change_value (Gtk.ScrollType.NONE, position);
        }
    }
}
