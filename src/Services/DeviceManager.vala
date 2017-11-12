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
    public class DeviceManager : GLib.Object {
        static DeviceManager _instance = null;

        public static DeviceManager instance {
            get {
                if (_instance == null)
                    _instance = new DeviceManager ();
                return _instance;
            }
        }

        private DeviceManager () {}

        public signal void audio_cd_added (Volume volume);
        public signal void mtp_added (Volume volume);
        public signal void audio_cd_removed (Volume volume);
        public signal void mtp_removed (Volume volume);

        private GLib.VolumeMonitor monitor;

        construct {
            monitor = GLib.VolumeMonitor.get ();

            monitor.volume_added.connect ((volume) => {
                if (check_for_audio_cd_volume (volume)) {
                    audio_cd_added (volume);
                } else if (check_for_mtp_volume (volume)) {
                    mtp_added (volume);
                }
            });

            monitor.volume_removed.connect ((volume) => {
                if (check_for_audio_cd_volume (volume)) {
                    audio_cd_removed (volume);
                } else if (check_for_mtp_volume (volume)) {
                    mtp_removed (volume);
                }
            });
        }

        public void init () {
            var volumes = monitor.get_volumes ();
            foreach (var volume in volumes) {
                if (check_for_audio_cd_volume (volume)) {
                    audio_cd_added (volume);
                } else if (check_for_mtp_volume (volume)) {
                    mtp_added (volume);
                }
            }
        }

        private bool check_for_audio_cd_volume (Volume volume) {
            File file = volume.get_activation_root ();
            return (file != null && file.get_uri ().has_prefix ("cdda://"));
        }

         private bool check_for_mtp_volume (Volume volume) {
            File file = volume.get_activation_root ();
            return (file != null && file.get_uri ().has_prefix ("mtp://"));
        }
    }
}
