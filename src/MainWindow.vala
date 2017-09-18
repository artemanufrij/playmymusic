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

namespace PlayMyMusic {

    public class MainWindow : Gtk.Window {

        PlayMyMusic.Services.LibraryManager library_manager;
        
        //CONTROLS
        Gtk.Spinner spinner;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.tag_discover_started.connect (() => {
                spinner.active = true;
                stdout.printf ("tag_discover_started\n");
            });
            library_manager.tag_discover_finished.connect (() => {
                spinner.active = false;
                stdout.printf ("tag_discover_finished\n");
            });
        }

        public MainWindow () {
            this.width_request = 800;
            this.height_request = 600;

            build_ui ();

            library_manager.scan_local_library ("/home/artem/Musik/Interpreter/");
        }
        
        public void build_ui () {
            var headerbar = new Gtk.HeaderBar ();
            headerbar.show_close_button = true;

            spinner = new Gtk.Spinner ();
            headerbar.pack_end (spinner);

            this.set_titlebar (headerbar);
            this.show_all ();
        }
    }
}
