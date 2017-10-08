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

        public SoundIndicatorControls controls = null;

        private unowned DBusConnection conn;
        private uint owner_id;

        private void initialize () {
            owner_id = Bus.own_name(BusType.SESSION, "org.mpris.MediaPlayer2.PlayMyMusic", GLib.BusNameOwnerFlags.NONE, on_bus_acquired, on_name_acquired, on_name_lost);
            if(owner_id == 0) {
                warning("Could not initialize MPRIS session.\n");
            }
            else {

            }
        }

        private void on_bus_acquired (DBusConnection connection, string name) {
            this.conn = connection;
            debug ("bus acquired");
            try {
                controls = new SoundIndicatorControls (connection);
                connection.register_object ("/org/mpris/MediaPlayer2", controls);
            }
            catch(IOError e) {
                warning("could not create MPRIS player: %s\n", e.message);
            }
        }

        private void on_name_acquired(DBusConnection connection, string name) {
            debug ("name acquired");
        }

        private void on_name_lost(DBusConnection connection, string name) {
            debug ("name_lost");
        }
    }


    [DBus(name = "org.mpris.MediaPlayer2.Player")]
    public class SoundIndicatorControls : GLib.Object {
        PlayMyMusic.Services.Player player;
        DBusConnection conn;

        HashTable<string,Variant> changed_properties = null;
        HashTable<string,Variant> metadata;

        public SoundIndicatorControls (DBusConnection conn) {
            this.conn = conn;
            player = PlayMyMusic.Services.Player.instance;
            player.state_changed.connect_after ((state) => {
                switch (state) {
                    case Gst.State.PLAYING:
                        break;
                    case Gst.State.PAUSED:
                        break;
                    default:
                        break;
                }
            });
        }

        public bool CanGoNext { get { return true; } }

        public bool CanGoPrevious { get { return true; } }

        public bool CanPlay { get { return true; } }

        public bool CanPause { get { return true; } }

        public void PlayPause() {

            player.play ();
        }

        public void Play () {
            player.play ();
        }

        public void Pause () {
            player.pause ();
        }

        public void Next () {
            player.next ();
        }

    }
}
