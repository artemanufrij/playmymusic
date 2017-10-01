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
    public class PlayMyMusicApp : Granite.Application {
        public string DB_PATH { get; private set; }
        public string COVER_FOLDER { get; private set; }
        //public string APP_NAME { get { return "com.github.artemanufrij.playmymusic"; } }

        PlayMyMusic.Settings settings;

        static PlayMyMusicApp _instance = null;
        public static PlayMyMusicApp instance {
            get {
                if (_instance == null) {
                    _instance = new PlayMyMusicApp ();
                    stdout.printf ("NEW INSTANCE\n");
                }
                return _instance;
            }
        }

        construct {
            application_id = "com.github.artemanufrij.playmymusic";
            settings = PlayMyMusic.Settings.get_default ();
            var library_path = File.new_for_path (settings.library_location);
            if (settings.library_location == "" || !library_path.query_exists ()) {
                settings.library_location = GLib.Environment.get_user_special_dir (GLib.UserDirectory.MUSIC);
            }
            var cache_folder = GLib.Path.build_filename (GLib.Environment.get_user_cache_dir (), application_id);
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

        private PlayMyMusicApp () {}

        public MainWindow mainwindow { get; private set; default = null; }

        protected override void activate () {
            if (mainwindow == null) {
                mainwindow = new MainWindow ();
                mainwindow.application = this;
                Services.MediaKeyListener.listen ();
                stdout.printf ("NEW WINDOW\n");
            }
            mainwindow.present ();
        }
    }
}

public static void main (string [] args) {
    Gst.init (ref args);
    var app = PlayMyMusic.PlayMyMusicApp.instance;
    app.run (args);
}
