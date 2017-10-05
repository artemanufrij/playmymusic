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
    public class Radio : Gtk.FlowBoxChild {
        PlayMyMusic.Services.LibraryManager library_manager;

        public signal void edit_request ();

        public PlayMyMusic.Objects.Radio radio { get; private set; }
        public string title { get { return radio.title; } }

        Gtk.Image cover;
        Gtk.Menu menu;
        Gtk.Label station_title;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
        }

        public Radio (PlayMyMusic.Objects.Radio radio) {
            this.radio = radio;
            this.radio.cover_changed.connect (() => {
                if (this.radio.cover != null) {
                    cover.pixbuf = this.radio.cover;
                }
            });
            this.radio.removed.connect (() => {
                this.destroy ();
            });

            this.radio.notify["title"].connect (() => {
                station_title.label = ("<b>%s</b>").printf(this.radio.title);
            });

            this.radio.notify["url"].connect (() => {
                this.tooltip_text = this.radio.url;
            });

            build_ui ();
        }

        private void build_ui () {
            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            var content = new Gtk.Grid ();
            content.halign = Gtk.Align.CENTER;
            content.row_spacing = 6;
            content.margin = 12;
            event_box.add (content);

            cover = new Gtk.Image ();
            cover.get_style_context ().add_class ("card");
            cover.halign = Gtk.Align.CENTER;
            if (this.radio.cover == null) {
                cover.set_from_icon_name ("network-cellular-connected-symbolic", Gtk.IconSize.DIALOG);
                cover.height_request = 64;
                cover.width_request = 64;
            } else {
                cover.pixbuf = this.radio.cover;
            }
            content.attach (cover, 0, 0);

            station_title = new Gtk.Label (("<b>%s</b>").printf(radio.title));
            station_title.use_markup = true;
            station_title.halign = Gtk.Align.CENTER;
            content.attach (station_title, 0, 1);

            menu = new Gtk.Menu ();
            var menu_new_cover = new Gtk.MenuItem.with_label (_("Edit Radio Station…"));
            menu_new_cover.activate.connect (() => {
                edit_request ();
            });
            menu.append (menu_new_cover);

            menu.append (new Gtk.SeparatorMenuItem ());

            var menu_remove = new Gtk.MenuItem.with_label (_("Remove Radio Station"));
            menu_remove.activate.connect (() => {
                library_manager.remove_radio_station (this.radio);
            });
            menu.append (menu_remove);

            menu.show_all ();

            this.tooltip_text = radio.url;
            this.add (event_box);
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }
    }
}
