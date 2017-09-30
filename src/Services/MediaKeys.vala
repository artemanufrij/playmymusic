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

namespace PlayMyMusic.Services {
    [DBus (name = "org.gnome.SettingsDaemon.MediaKeys")]
    public interface GnomeMediaKeys : GLib.Object {
        public abstract void GrabMediaPlayerKeys (string application, uint32 time) throws IOError;
        public abstract void ReleaseMediaPlayerKeys (string application) throws IOError;
        public signal void MediaPlayerKeyPressed (string application, string key);
    }

    public class MediaKeyListener : GLib.Object {
        public static MediaKeyListener instance { get; private set; }

        PlayMyMusic.Services.LibraryManager library_manager;

        private GnomeMediaKeys? media_keys;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            assert (media_keys == null);

            try {
                media_keys = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.SettingsDaemon", "/org/gnome/SettingsDaemon/MediaKeys");
            } catch (IOError e) {
                warning ("Mediakeys error: %s", e.message);
            }

            if(media_keys != null) {
                media_keys.MediaPlayerKeyPressed.connect (pressed_key);
                try {
                    media_keys.GrabMediaPlayerKeys (PlayMyMusic.PlayMyMusicApp.instance.APP_NAME, (uint32)0);
                }
                catch(IOError err) {
                    warning ("Could not grab media player keys: %s", err.message);
                }
            }
        }

        private MediaKeyListener (){}

        public static void listen () {
            instance = new MediaKeyListener ();
        }

        public void release_keys() {
            try {
                media_keys.ReleaseMediaPlayerKeys (PlayMyMusic.PlayMyMusicApp.instance.APP_NAME);
            }
            catch(IOError err) {
                warning ("Could not release media player keys: %s", err.message);
            }
        }

        private void pressed_key (dynamic Object bus, string application, string key) {
            if (application == (PlayMyMusic.PlayMyMusicApp.instance.APP_NAME)) {
                if(key == "Previous") {
                    library_manager.player.prev ();
                }
                else if(key == "Play") {
                    PlayMyMusic.PlayMyMusicApp.instance.mainwindow.play ();
                }
                else if(key == "Next") {
                    library_manager.player.next ();
                }
                else if(key == "Pause") {
                    library_manager.player.pause ();
                }
            }
        }
    }
}
