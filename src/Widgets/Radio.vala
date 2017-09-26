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
    public class Radio : Gtk.ListBoxRow {
        public PlayMyMusic.Objects.Radio radio { get; private set; }

        public Radio (PlayMyMusic.Objects.Radio radio) {
            this.radio = radio;
            
            build_ui ();
        }
        
        private void build_ui () {
            var content = new Gtk.Grid ();
            content.margin = 12;
            content.column_spacing = 12;
            
            var cover = new Gtk.Image ();
            if (this.radio.cover == null) {
                cover.set_from_icon_name ("network-cellular-connected-symbolic", Gtk.IconSize.DIALOG);
                cover.height_request = 48;
                cover.width_request = 48;
            }
            content.attach (cover, 0, 0, 1, 2);
            
            var title = new Gtk.Label (("<b>%s</b>").printf(radio.title));
            title.use_markup = true;
            title.halign = Gtk.Align.START;
            content.attach (title, 1, 0);
            
            var url = new Gtk.Label (("<small>%s</small>").printf(radio.url));
            url.use_markup = true;
            url.halign = Gtk.Align.START;
            content.attach (url, 1, 1);
            
            this.add (content);
        }
    }
}
