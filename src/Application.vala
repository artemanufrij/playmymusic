/*-
 * Copyright (c) 2017-2019 Artem Anufrij <artem.anufrij@live.de>
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
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
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
        public string CACHE_FOLDER { get; private set; }
        public string QUEUE_SYS_NAME { get; default = "__queue__";}

        PlayMyMusic.Settings settings;

        static PlayMyMusicApp _instance = null;
        public static PlayMyMusicApp instance {
            get {
                if (_instance == null) {
                    _instance = new PlayMyMusicApp ();
                }
                return _instance;
            }
        }

        [CCode (array_length = false, array_null_terminated = true)]
        string[] ? arg_files = null;

        construct {
            this.flags |= ApplicationFlags.HANDLES_OPEN;
            this.flags |= ApplicationFlags.HANDLES_COMMAND_LINE;
            this.application_id = "com.github.artemanufrij.playmymusic";
            settings = Settings.get_default ();

            var action_search_reset = action_generator ("Escape", "search-reset");
            action_search_reset.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.search_reset ();
                    }
                });

            var action_show_albums = action_generator ("<Alt>1", "show-albums");
            action_show_albums.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (0);
                    }
                });

            var action_show_artists = action_generator ("<Alt>2", "show-artists");
            action_show_artists.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (1);
                    }
                });

            var action_show_tracks = action_generator ("<Alt>3", "show-tracks");
            action_show_tracks.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (2);
                    }
                });

            var action_show_playlists = action_generator ("<Alt>4", "show-playlists");
            action_show_playlists.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (3);
                    }
                });

            var action_show_radiostations = action_generator ("<Alt>5", "show-radiostations");
            action_show_radiostations.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (4);
                    }
                });

            var action_show_audiocd = action_generator ("<Alt>6", "show-audiocd");
            action_show_audiocd.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (5);
                    }
                });

            var action_quit = action_generator ("<Control>q", "quit");
            action_quit.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.destroy ();
                    }
                });

            create_cache_folders ();
        }

        private SimpleAction action_generator (string command, string action) {
            var return_value = new SimpleAction (action, null);
            add_action (return_value);
            set_accels_for_action ("app.%s".printf (action), {command});
            return return_value;
        }

        public void create_cache_folders () {
            var library_path = File.new_for_uri (settings.library_location);
            if (settings.library_location == "" || !library_path.query_exists ()) {
                var music_folder = File.new_for_path (GLib.Environment.get_user_special_dir (GLib.UserDirectory.MUSIC));
                settings.library_location = music_folder.get_uri ();
            }
            CACHE_FOLDER = GLib.Path.build_filename (GLib.Environment.get_user_cache_dir (), application_id);
            try {
                File file = File.new_for_path (CACHE_FOLDER);
                if (!file.query_exists ()) {
                    file.make_directory ();
                }
            } catch (Error e) {
                warning (e.message);
            }
            DB_PATH = GLib.Path.build_filename (CACHE_FOLDER, "database.db");

            COVER_FOLDER = GLib.Path.build_filename (CACHE_FOLDER, "covers");
            try {
                File file = File.new_for_path (COVER_FOLDER);
                if (!file.query_exists ()) {
                    file.make_directory ();
                }
            } catch (Error e) {
                warning (e.message);
            }
        }

        private PlayMyMusicApp () {
        }

        public MainWindow mainwindow { get; private set; default = null; }

        protected override void activate () {
            if (mainwindow == null) {
                mainwindow = new MainWindow ();
                mainwindow.application = this;
                Interfaces.MediaKeyListener.listen ();
                Interfaces.SoundIndicator.listen ();
            }

            mainwindow.present ();
        }

        public override void open (File[] files, string hint) {
            activate ();
            if (files [0].query_exists ()) {
                mainwindow.open_file (files [0]);
            }
        }

        public override int command_line (ApplicationCommandLine cmd) {
            command_line_interpreter (cmd);
            return 0;
        }

        private void command_line_interpreter (ApplicationCommandLine cmd) {
            string[] args_cmd = cmd.get_arguments ();
            unowned string[] args = args_cmd;

            bool next = false;
            bool prev = false;
            bool play = false;

            GLib.OptionEntry [] options = new OptionEntry [5];
            options [0] = { "next", 0, 0, OptionArg.NONE, ref next, "Play next track", null };
            options [1] = { "prev", 0, 0, OptionArg.NONE, ref prev, "Play previous track", null };
            options [2] = { "play", 0, 0, OptionArg.NONE, ref play, "Toggle playing", null };
            options [3] = { "", 0, 0, OptionArg.STRING_ARRAY, ref arg_files, null, "[URI…]" };
            options [4] = { null };

            var opt_context = new OptionContext ("actions");
            opt_context.add_main_entries (options, null);
            try {
                opt_context.parse (ref args);
            } catch (Error err) {
                warning (err.message);
                return;
            }

            if (next || prev || play) {
                if (next && mainwindow != null) {
                    mainwindow.next ();
                } else if (prev && mainwindow != null) {
                    mainwindow.prev ();
                } else if (play) {
                    if (mainwindow == null) {
                        activate ();
                    }
                    mainwindow.toggle_playing ();
                }
                return;
            }

            File[] files = null;
            foreach (string arg_file in arg_files) {
                if (GLib.FileUtils.test (arg_file, GLib.FileTest.EXISTS)) {
                    files += (File.new_for_path (arg_file));
                }
            }

            if (files != null && files.length > 0) {
                open (files, "");
                return;
            }

            activate ();
        }

        public string get_os_info (string field) {
            string return_value = "";
            var file = File.new_for_path ("/etc/os-release");
            try {
                var osrel = new Gee.HashMap<string, string> ();
                var dis = new DataInputStream (file.read ());
                string line;
                // Read lines until end of file (null) is reached
                while ((line = dis.read_line (null)) != null) {
                    var osrel_component = line.split ("=", 2);
                    if (osrel_component.length == 2) {
                        osrel[osrel_component[0]] = osrel_component[1].replace ("\"", "");
                    }
                }

                return_value = osrel[field];
            } catch (Error e) {
                warning ("Couldn't read os-release file, assuming elementary OS");
            }
            return return_value;
        }
    }
}

public static int main (string [] args) {
    Gst.init (ref args);
    var app = PlayMyMusic.PlayMyMusicApp.instance;
    return app.run (args);
}
