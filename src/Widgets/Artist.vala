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
    public class Artist : Gtk.FlowBoxChild {
        PlayMyMusic.Services.LibraryManager library_manager;

        public PlayMyMusic.Objects.Artist artist { get; private set; }
        public new string name { get { return artist.name; } }

        Gtk.Menu menu;
        Gtk.Image cover;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
        }

        public Artist (PlayMyMusic.Objects.Artist artist) {
            this.artist = artist;

            build_ui ();

            this.artist.cover_changed.connect (() => {
                Idle.add (() => {
                    cover.pixbuf = this.artist.cover.scale_simple (128, 128, Gdk.InterpType.BILINEAR);
                    return false;
                });
            });
        }

        private void build_ui () {
            this.tooltip_text = this.artist.name;

            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            var content = new Gtk.Grid ();
            content.margin = 12;
            content.row_spacing = 6;
            event_box.add (content);

            cover = new Gtk.Image ();
            cover.get_style_context ().add_class ("card");
            cover.halign = Gtk.Align.CENTER;
            if (this.artist.cover == null) {
                cover.set_from_icon_name ("avatar-default-symbolic", Gtk.IconSize.DIALOG);
                cover.height_request = 128;
                cover.width_request = 128;
            } else {
                cover.pixbuf = this.artist.cover.scale_simple (128, 128, Gdk.InterpType.BILINEAR);
            }

            var name = new Gtk.Label (("<span color='#666666'><b>%s</b></span>").printf(this.name.replace ("&", "&amp;")));
            name.ellipsize = Pango.EllipsizeMode.END;
            name.use_markup = true;

            menu = new Gtk.Menu ();
            var menu_new_cover = new Gtk.MenuItem.with_label (_("Set new Cover…"));
            menu_new_cover.activate.connect (() => {
                var new_cover = library_manager.choose_new_cover ();
                if (new_cover != null) {
                    try {
                        var pixbuf = new Gdk.Pixbuf.from_file (new_cover);
                        this.artist.set_new_cover (pixbuf, 128);
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
            });
            menu.append (menu_new_cover);
            menu.show_all ();

            content.attach (cover, 0, 0);
            content.attach (name, 0, 1);

            this.add (event_box);
            this.valign = Gtk.Align.START;

            this.show_all ();
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
