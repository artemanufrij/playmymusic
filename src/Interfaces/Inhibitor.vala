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
    [DBus (name = "org.freedesktop.ScreenSaver")]
    public interface ScreenSaverIface : Object {
        public abstract uint32 Inhibit (string app_name, string reason) throws Error;
        public abstract void UnInhibit (uint32 cookie) throws Error;
        public abstract void SimulateUserActivity () throws Error;
    }

    public class Inhibitor : GLib.Object {
        const string IFACE = "org.freedesktop.ScreenSaver";
        const string IFACE_PATH = "/ScreenSaver";

        static Inhibitor? _instance = null;
        public static Inhibitor instance {
            get {
                if (_instance == null) {
                    _instance = new Inhibitor ();
                }
                return _instance;
            }
        }

        uint32? inhibit_cookie = null;

        ScreenSaverIface? screensaver_iface = null;

        uint timer = 0;

        private Inhibitor () {
            try {
                screensaver_iface = Bus.get_proxy_sync (BusType.SESSION, IFACE, IFACE_PATH, DBusProxyFlags.NONE);
            } catch (Error e) {
                warning ("Could not start screensaver interface: %s", e.message);
            }
        }

        public void inhibit () {
            if (screensaver_iface != null && timer == 0) {
                try {
                    inhibit_cookie = screensaver_iface.Inhibit ("com.github.artemanufrij.playmyvideos", "Playing movie");
                } catch (Error e) {
                    warning ("Could not inhibit screen: %s", e.message);
                    return;
                }

                timer = Timeout.add (120000, ()=> {
                    try {
                        screensaver_iface.SimulateUserActivity ();
                    } catch (Error e) {
                        warning ("Could not simulate user activity: %s", e.message);
                    }
                    return true;
                });
            }
        }

        public void uninhibit () {
            if (timer > 0 ) {
                Source.remove (timer);
                timer = 0;
            }

            if (inhibit_cookie != null) {
                try {
                    screensaver_iface.UnInhibit (inhibit_cookie);
                    inhibit_cookie = null;
                } catch (Error e) {
                    warning ("Could not uninhibit screen: %s", e.message);
                }
            }
        }
    }
}
