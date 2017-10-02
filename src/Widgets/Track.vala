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
        public int disc_number { get { return track.disc; } }

        Gtk.Box content;
        Gtk.Image cover;

        public Track (PlayMyMusic.Objects.Track track ) {
            this.track = track;
            this.track.path_not_found.connect (() => {
                var warning = new Gtk.Image.from_icon_name ("process-error-symbolic", Gtk.IconSize.MENU);
                warning.tooltip_text = _("File couldn't be found\n%s").printf (track.path);
                warning.halign = Gtk.Align.END;
                content.pack_end (warning);
                warning.show_all ();
            });

            build_ui ();
        }

        public void build_ui () {
            content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            content.spacing = 6;
            content.margin = 6;
            content.halign = Gtk.Align.FILL;

            cover = new Gtk.Image ();
            cover.get_style_context ().add_class ("card");
            cover.halign = Gtk.Align.CENTER;
            cover.tooltip_text = this.track.album.title;
            if (this.track.album.cover == null) {
                cover.set_from_icon_name ("audio-x-generic-symbolic", Gtk.IconSize.DND);
            } else {
                cover.pixbuf = this.track.album.cover.scale_simple (32, 32, Gdk.InterpType.BILINEAR);
            }
            content.pack_start (cover, false, false, 0);

            var title = new Gtk.Label (this.track.title);
            title.xalign = 0;
            title.ellipsize = Pango.EllipsizeMode.END;
            content.pack_start (title, true, true, 0);

            var duration = new Gtk.Label (PlayMyMusic.Utils.get_formated_duration(this.track.duration));
            duration.halign = Gtk.Align.END;
            content.pack_end (duration, false, false, 0);
            this.add (content);
            this.halign = Gtk.Align.FILL;
        }

        public void hide_album_cover () {
            cover.hide ();
        }
    }
}
