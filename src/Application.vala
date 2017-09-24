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

    public class PlayMyMusicApp : Gtk.Application {

        public string DB_PATH { get; private set; }
        public string COVER_FOLDER { get; private set; }

        static PlayMyMusicApp _instance = null;

        public static PlayMyMusicApp instance {
            get {
                if (_instance == null) {
                    _instance = new PlayMyMusicApp ();
                }
                return _instance;
            }
        }

        construct {
            var cache_folder = GLib.Path.build_filename (GLib.Environment.get_user_cache_dir (), "com.github.artemanufrij.playmymusic");
            try {
                File file = File.new_for_path (cache_folder);
                if (!file.query_exists ()) {
                    file.make_directory ();
                }
            } catch (Error e) {
                warning (e.message);
            }
            DB_PATH = GLib.Path.build_filename (cache_folder, "database.db");

            var cover_folder = GLib.Path.build_filename (cache_folder, "covers");
            try {
                File file = File.new_for_path (cover_folder);
                if (!file.query_exists ()) {
                    file.make_directory ();
                }
            } catch (Error e) {
                warning (e.message);
            }
            COVER_FOLDER = cover_folder;
        }

        MainWindow mainwindow;

        protected override void activate () {
            if (mainwindow != null) {
                mainwindow.present ();
                return;
            }

            mainwindow = new MainWindow ();
            mainwindow.set_application(this);
        }
    }
}

public static int main (string [] args) {
    Gtk.init (ref args);
    Gst.init (ref args);
    var app = PlayMyMusic.PlayMyMusicApp.instance;
    return app.run (args);
}
