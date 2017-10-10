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

namespace PlayMyMusic.Dialogs {
    public class Preferences : Gtk.Dialog {
        PlayMyMusic.Settings settings;

        construct {
            settings = PlayMyMusic.Settings.get_default ();
        }

        public Preferences (Gtk.Window parent) {
            Object (
                transient_for: parent
            );
            build_ui ();

            this.response.connect ((source, response_id) => {
                switch (response_id) {
                    case Gtk.ResponseType.CLOSE:
                        destroy ();
                    break;
                }
            });
        }

        private void build_ui () {
            this.resizable = false;
            var content = get_content_area () as Gtk.Box;

            var play_in_background_label = new Gtk.Label (_("Play in background if closed"));
            var play_in_background = new Gtk.Switch ();
            play_in_background.active = settings.play_in_background;
            play_in_background.notify["active"].connect (() => {
                settings.play_in_background = play_in_background.active;
            });
            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.margin = 12;

            grid.attach (play_in_background_label, 0, 0);
            grid.attach (play_in_background, 1, 0);

            content.pack_start (grid, false, false, 0);

            this.add_button ("_Close", Gtk.ResponseType.CLOSE);
            this.show_all ();
        }
    }
}
