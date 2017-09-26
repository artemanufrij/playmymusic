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
    public class RadiosView : Gtk.Grid {
        PlayMyMusic.Services.LibraryManager library_manager;

        Gtk.ListBox radios;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.player_state_changed.connect ((state) => {
                if (state == Gst.State.PLAYING && library_manager.player.current_radio == null) {
                    radios.unselect_all ();
                }
            });
        }

        public RadiosView () {
            this.map.connect (() => {
                grab_playing_radio ();
            });

            build_ui ();
        }

        private void build_ui () {
            radios = new Gtk.ListBox ();
            radios.selection_mode = Gtk.SelectionMode.SINGLE;
            //radios.valign = Gtk.Align.START;
            radios.row_activated.connect (play_station);
            var radios_scroll = new Gtk.ScrolledWindow (null, null);

            radios_scroll.add (radios);

            var radio_toolbar = new Gtk.ActionBar ();
            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.tooltip_text = _("Add a radio station");
            radio_toolbar.pack_start (add_button);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.expand = true;
            content.pack_start (radios_scroll, true, true, 0);
            content.pack_end (radio_toolbar, false, false, 0);

            this.add (content);

            show_albums_from_database.begin ();
        }

        public void unselect_all () {
            radios.unselect_all ();
        }

        private void grab_playing_radio () {
            if (radios.get_selected_row () != null) {
                radios.get_selected_row ().activate ();
            }
        }

        public void play_station (Gtk.ListBoxRow item) {
            var radio = (item as PlayMyMusic.Widgets.Radio);
            library_manager.play_radio (radio.radio);
        }

        private async void show_albums_from_database () {
            foreach (var radio in library_manager.radios) {
                var r = new Widgets.Radio (radio);
                r.show_all ();
                radios.add (r);
            }
        }
    }
}
