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
    public class Track : GLib.Object {
        Album _album;
        public Album album {
            get {
                return _album;
            }
        }

        public int ID { get; set; }
        public string title { get; set; default = ""; }
        public string genre { get; set; default = ""; }
        public int track { get; set; default = 0; }
        public int disc { get; set; default = 0; }
        public uint64 duration { get; set; default = 0; }

        //LOCATION
        string _path = "";
        public string path {
            get {
                return _path;
            } set {
                _path = value;
                var f = File.new_for_path (_path);
                _uri = f.get_uri ();
            }
        }
        string _uri = "";
        public string uri {
            get {
                return _uri;
            }
        }

        public Track (Album album) {
            this.set_album (album);
        }

        public void set_album (Album album) {
            this._album = album;
        }
    }
}
