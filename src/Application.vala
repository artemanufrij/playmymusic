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
        public string CACHE_FOLDER { get; private set; }



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

        construct {
            this.flags |= ApplicationFlags.HANDLES_OPEN;
            this.application_id = "com.github.artemanufrij.playmymusic";
            settings = Settings.get_default ();

            var action_search_reset = new SimpleAction ("search-reset", null);
            add_action (action_search_reset);
            add_accelerator ("Escape", "app.search-reset", null);
            action_search_reset.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.search_reset ();
                    }
                });

            var action_show_albums = new SimpleAction ("show-albums", null);
            add_action (action_show_albums);
            add_accelerator ("<Alt>1", "app.show-albums", null);
            action_show_albums.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (0);
                    }
                });

            var action_show_artists = new SimpleAction ("show-artists", null);
            add_action (action_show_artists);
            add_accelerator ("<Alt>2", "app.show-artists", null);
            action_show_artists.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (1);
                    }
                });

            var action_show_tracks = new SimpleAction ("show-tracks", null);
            add_action (action_show_tracks);
            add_accelerator ("<Alt>3", "app.show-tracks", null);
            action_show_tracks.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (2);
                    }
                });

            var action_show_playlists = new SimpleAction ("show-playlists", null);
            add_action (action_show_playlists);
            add_accelerator ("<Alt>4", "app.show-playlists", null);
            action_show_playlists.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (3);
                    }
                });

            var action_show_radiostations = new SimpleAction ("show-radiostations", null);
            add_action (action_show_radiostations);
            add_accelerator ("<Alt>5", "app.show-radiostations", null);
            action_show_radiostations.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (4);
                    }
                });

            var action_show_audiocd = new SimpleAction ("show-audiocd", null);
            add_action (action_show_audiocd);
            add_accelerator ("<Alt>6", "app.show-audiocd", null);
            action_show_audiocd.activate.connect (
                () => {
                    if (mainwindow != null) {
                        mainwindow.show_view_index (5);
                    }
                });

            create_cache_folders ();
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

                var entry = Unity.LauncherEntry.get_for_desktop_id (this.application_id + ".desktop");

                var entry_play = new Dbusmenu.Menuitem ();
                entry_play.property_set (Dbusmenu.MENUITEM_PROP_LABEL, "Play");
                entry_play.property_set (Dbusmenu.MENUITEM_PROP_ICON_NAME, "media-playback-start-symbolic");
                entry_play.item_activated.connect (() => {
                    mainwindow.play ();
                });

                var entry_next = new Dbusmenu.Menuitem ();
                entry_next.property_set (Dbusmenu.MENUITEM_PROP_LABEL, "Next");
                entry_next.property_set (Dbusmenu.MENUITEM_PROP_ICON_NAME, "media-skip-forward-symbolic");
                entry_next.item_activated.connect (() => {
                    mainwindow.next ();
                });

                var entry_prev = new Dbusmenu.Menuitem ();
                entry_prev.property_set (Dbusmenu.MENUITEM_PROP_LABEL, "Previous");
                entry_prev.property_set (Dbusmenu.MENUITEM_PROP_ICON_NAME, "media-skip-backward-symbolic");
                entry_prev.item_activated.connect (() => {
                    mainwindow.prev ();
                });

                var quicklist = new Dbusmenu.Menuitem ();

                quicklist.child_append (entry_play);
                quicklist.child_append (entry_next);
                quicklist.child_append (entry_prev);

                Services.Player.instance.state_changed.connect (
                (state) => {
                    if (state == Gst.State.PLAYING) {
                        entry_play.property_set (Dbusmenu.MENUITEM_PROP_ICON_NAME, "media-playback-pause-symbolic");
                        entry_play.property_set (Dbusmenu.MENUITEM_PROP_LABEL, "Pause");
                    } else {
                        entry_play.property_set (Dbusmenu.MENUITEM_PROP_ICON_NAME, "media-playback-start-symbolic");
                        entry_play.property_set (Dbusmenu.MENUITEM_PROP_LABEL, "Play");
                    }
                });

                entry.quicklist = quicklist;
            }

            mainwindow.present ();
        }

        public override void open (File[] files, string hint) {
            activate ();
            if (files [0].query_exists ()) {
                mainwindow.open_file (files [0]);
            }
        }
    }
}

public static int main (string [] args) {
    Gst.init (ref args);
    var app = PlayMyMusic.PlayMyMusicApp.instance;
    return app.run (args);
}