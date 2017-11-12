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

namespace PlayMyMusic.Widgets.Views {
    public class MobilePhone : Gtk.Grid {

        public PlayMyMusic.Objects.MobilePhone? current_mobile_phone { get; private set; default = null;}

        Gtk.Label title;
        Gtk.Image image;
        Gtk.ProgressBar storage;

        public MobilePhone () {
            build_ui ();
        }

        private void build_ui () {
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
         //   content.vexpand = true;
            content.margin = 12;
            content.spacing = 12;

            title = new Gtk.Label ("");

            image = new Gtk.Image ();

            storage = new Gtk.ProgressBar ();

            content.pack_start (title, false, false, 0);
            content.pack_start (image);
            content.pack_start (storage);

            var folders = new Gtk.ListBox ();
            folders.vexpand = true;

            this.attach (content, 0, 0);
            this.attach (folders, 0, 1);
            this.attach (new Gtk.Separator (Gtk.Orientation.VERTICAL), 1, 0, 1, 2);
            this.show_all ();
        }

        public void show_mobile_phone (PlayMyMusic.Objects.MobilePhone mobile_phone) {
            if (current_mobile_phone == mobile_phone) {
                return;
            }

            if (current_mobile_phone != null) {
                current_mobile_phone.storage_calculated.disconnect (storage_calculated);
            }
            current_mobile_phone = mobile_phone;

            title.label = current_mobile_phone.volume.get_name ();
            image.set_from_gicon (mobile_phone.volume.get_icon (), Gtk.IconSize.DIALOG);

            current_mobile_phone.storage_calculated.connect (storage_calculated);
        }

        public void storage_calculated () {
            storage.fraction = 1 - (double)1 / current_mobile_phone.size * current_mobile_phone.free;
        }
    }
}
