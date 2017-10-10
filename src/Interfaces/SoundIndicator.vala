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

namespace PlayMyMusic.Interfaces {
    public class SoundIndicator {
        public static SoundIndicator instance { get; private set; }
        public static void listen () {
            instance = new SoundIndicator ();
            instance.initialize ();
        }

        SoundIndicatorPlayer player;
        SoundIndicatorRoot root;

        unowned DBusConnection conn;
        uint owner_id;
        uint root_id;
        uint player_id;

        private void initialize () {
            owner_id = Bus.own_name (BusType.SESSION, "org.mpris.MediaPlayer2.PlayMyMusic", GLib.BusNameOwnerFlags.NONE, on_bus_acquired, on_name_acquired, on_name_lost);
            if (owner_id == 0) {
                warning ("Could not initialize MPRIS session.\n");
            }
            PlayMyMusic.PlayMyMusicApp.instance.mainwindow.destroy.connect (() => {
                this.conn.unregister_object (root_id);
                this.conn.unregister_object (player_id);
                Bus.unown_name (owner_id);
            });
        }

        private void on_bus_acquired (DBusConnection connection, string name) {
            this.conn = connection;
            try {
                root = new SoundIndicatorRoot ();
                root_id = connection.register_object ("/org/mpris/MediaPlayer2", root);
                player = new SoundIndicatorPlayer (connection);
                player_id = connection.register_object ("/org/mpris/MediaPlayer2", player);
            }
            catch(IOError e) {
                warning ("could not create MPRIS player: %s\n", e.message);
            }
        }

        private void on_name_acquired (DBusConnection connection, string name) {
        }

        private void on_name_lost (DBusConnection connection, string name) {
        }
    }

    [DBus(name = "org.mpris.MediaPlayer2")]
    public class SoundIndicatorRoot : GLib.Object {
        PlayMyMusic.PlayMyMusicApp app;

        construct {
            this.app = PlayMyMusic.PlayMyMusicApp.instance;
        }

        public string DesktopEntry {
            owned get {
                return app.application_id;
            }
        }
    }

    [DBus(name = "org.mpris.MediaPlayer2.Player")]
    public class SoundIndicatorPlayer : GLib.Object {
        PlayMyMusic.Services.Player player;
        DBusConnection connection;
        PlayMyMusic.PlayMyMusicApp app;

        public SoundIndicatorPlayer (DBusConnection connection) {
            this.app = PlayMyMusic.PlayMyMusicApp.instance;
            this.connection = connection;
            player = PlayMyMusic.Services.Player.instance;
            player.state_changed.connect_after ((state) => {
                Variant property;
                switch (state) {
                    case Gst.State.PLAYING:
                        property = "Playing";
                        var metadata = new HashTable<string, Variant> (null, null);
                        var file = File.new_for_path (player.current_track.album.cover_path);
                        metadata.insert("mpris:artUrl", file.get_uri ());
                        metadata.insert("xesam:title", player.current_track.title);
                        metadata.insert("xesam:artist", get_simple_string_array (player.current_track.album.artist.name));
                        send_properties ("Metadata", metadata);
                        break;
                    case Gst.State.PAUSED:
                        property = "Paused";
                        break;
                    default:
                        property = "Stopped";
                        var metadata = new HashTable<string, Variant> (null, null);
                        metadata.insert("mpris:artUrl", "");
                        metadata.insert("xesam:title", "");
                        metadata.insert("xesam:artist", new string [0]);
                        send_properties ("Metadata", metadata);
                        break;
                }
                send_properties ("PlaybackStatus", property);
            });
        }

        private static string[] get_simple_string_array (string text) {
            string[] array = new string[0];
            array += text;
            return array;
        }

        private void send_properties (string property, Variant val) {
            var property_list = new HashTable<string,Variant> (str_hash, str_equal);
            property_list.insert (property, val);

            var builder = new VariantBuilder (VariantType.ARRAY);
            var invalidated_builder = new VariantBuilder (new VariantType("as"));

            foreach(string name in property_list.get_keys ()) {
                Variant variant = property_list.lookup (name);
                builder.add ("{sv}", name, variant);
            }

            try {
                connection.emit_signal (null,
                                  "/org/mpris/MediaPlayer2",
                                  "org.freedesktop.DBus.Properties",
                                  "PropertiesChanged",
                                  new Variant("(sa{sv}as)", "org.mpris.MediaPlayer2.Player", builder, invalidated_builder));
            }
            catch(Error e) {
                print("Could not send MPRIS property change: %s\n", e.message);
            }
        }

        public bool CanGoNext { get { return true; } }

        public bool CanGoPrevious { get { return true; } }

        public bool CanPlay { get { return true; } }

        public bool CanPause { get { return true; } }

        public void PlayPause () {
            app.mainwindow.play ();
        }

        public void Next () {
            app.mainwindow.next ();
        }

        public void Previous() {
            app.mainwindow.prev ();
        }

    }
}
