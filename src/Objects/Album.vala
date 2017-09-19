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
    public class Album : GLib.Object {
        Artist _artist;
        public Artist artist {
            get {
                return _artist;
            }
        }

        public int ID { get; set; }
        public string title { get; set; }
        public int year { get; set; }
        public Gdk.Pixbuf? cover { get; private set; default = null; }

        GLib.List<Track> _tracks;
        public GLib.List<Track> tracks { get { return _tracks; } }

        construct {
            _tracks = new GLib.List<Track> ();
            year = -1;
        }

        public Album (Artist artist) {
            this.set_artist (artist);
        }

        public void set_artist (Artist artist) {
            this._artist = artist;
        }

        public void add_track (Track track) {
            track.set_album (this);
            this._tracks.append (track);
        }

        public Track? get_track_by_path (string path) {
            Track? return_value = null;
            lock (_tracks) {
                foreach (var track in tracks) {
                    if (track.path == path) {
                        return_value = track;
                        break;
                    }
                }
            }
            return return_value;
        }
    }
}
