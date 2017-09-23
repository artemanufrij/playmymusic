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
    public class Album : Gtk.FlowBoxChild {
        public PlayMyMusic.Objects.Album album { get; private set; }
        public string title { get { return album.title; } }
        public int year { get { return album.year; } }

        Gtk.Image cover;

        public Album (PlayMyMusic.Objects.Album album) {
            this.album = album;

            build_ui ();

            this.album.cover_changed.connect (() => {
                cover.pixbuf = this.album.cover.scale_simple (128, 128, Gdk.InterpType.BILINEAR);
            });
        }

        private void build_ui () {
            var content = new Gtk.Grid ();

            content.margin = 12;
            content.halign = Gtk.Align.CENTER;
            content.row_spacing = 6;
            cover = new Gtk.Image ();
            cover.get_style_context ().add_class ("card");
            cover.halign = Gtk.Align.CENTER;
            if (this.album.cover == null) {
                cover.set_from_icon_name ("audio-x-generic-symbolic", Gtk.IconSize.DIALOG);
                cover.height_request = 128;
                cover.width_request = 128;
            } else {
                cover.pixbuf = this.album.cover.scale_simple (128, 128, Gdk.InterpType.BILINEAR);
            }

            var title = new Gtk.Label (("<span color='#666666'><b>%s</b></span>").printf(this.title.replace ("&", "&amp;")));
            title.use_markup = true;
            title.halign = Gtk.Align.FILL;
            title.ellipsize = Pango.EllipsizeMode.END;
            title.max_width_chars = 0;

            var artist = new Gtk.Label (this.album.artist.name.replace ("&", "&amp;"));
            artist.halign = Gtk.Align.FILL;
            artist.ellipsize = Pango.EllipsizeMode.END;
            artist.max_width_chars = 0;

            content.attach (cover, 0, 0);
            content.attach (title, 0, 1);
            content.attach (artist, 0, 2);

            this.add (content);
            this.valign = Gtk.Align.START;
        }
    }
}
