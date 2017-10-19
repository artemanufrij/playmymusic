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

namespace PlayMyMusic.Objects {
    public class AudioCD : TracksContainer {
        public Volume volume { get; private set; }

        public new GLib.List<Track> tracks {
            get {
                return _tracks;
            }
        }

        public AudioCD (Volume volume) {
            this.volume = volume;
            this.title = "Audio CD";
            volume.mount.begin (MountMountFlags.NONE, null, null, (obj, res)=>{
                create_track_list ();
            });

            get_volume_info ();
        }

        public void create_track_list () {
            var file = this.volume.get_activation_root ();
            var children = file.enumerate_children (FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NONE);
            FileInfo file_info;

            int counter = 1;
            while ((file_info = children.next_file ()) != null) {
                var track = new Track (this);
                track.track = counter;
                track.title = _("Track %d").printf (counter);
                track.uri = "cdda://%d".printf (counter);
                add_track (track);
                counter++;
            }
        }

        public void get_volume_info () {
        }
    }
}
