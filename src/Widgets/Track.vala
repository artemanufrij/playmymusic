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
    public class Track : Gtk.ListBoxRow {
        public PlayMyMusic.Objects.Track track { get; private set; }
        public string title { get { return track.title; } }
        public int track_number { get { return track.track; } }

        public Track (PlayMyMusic.Objects.Track track ) {
            this.track = track;

            build_ui ();
        }

        public void build_ui () {
            var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            content.spacing = 6;
            content.margin = 6;
            content.halign = Gtk.Align.FILL;

            var title = new Gtk.Label (this.track.title);
            title.xalign = 0;
            title.ellipsize = Pango.EllipsizeMode.END;
            content.pack_start (title, true, true, 0);

            var duration = new Gtk.Label (duration_format(this.track.duration));
            duration.halign = Gtk.Align.END;
            content.pack_end (duration, false, false, 0);
            this.add (content);
            this.halign = Gtk.Align.FILL;
        }

        private string duration_format (uint64 duration) {
            uint seconds = (uint)(duration / 1000 / 1000 / 1000);
            if (seconds < 3600) {
                uint minutes = seconds / 60;
                seconds -= minutes * 60;
                return "%u:%02u".printf (minutes, seconds);
            }

            uint hours = seconds / 3600;
            seconds -= hours * 3600;
            uint minutes = seconds / 60;
            seconds -= minutes * 60;
            return "%u:%02u:%02u".printf (hours, minutes, seconds);
        }
    }
}
