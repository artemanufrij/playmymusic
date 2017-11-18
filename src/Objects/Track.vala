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
        PlayMyMusic.Services.LibraryManager library_manager;

        public signal void removed ();

        Album? _album = null;
        public Album album {
            get {
                if (_album == null) {
                    _album = library_manager.db_manager.get_album_by_track_id (this.ID);
                }
                return _album;
            }
        }

        Playlist? _playlist = null;
        public Playlist? playlist {
            get {
                return _playlist;
            }
        }

        public AudioCD _audio_cd = null;
        public AudioCD audio_cd {
            get {
                return _audio_cd;
            }
        }

        public int ID { get; set; default = 0; }
        public string title { get; set; default = ""; }
        public string genre { get; set; default = ""; }
        public int track { get; set; default = 0; }
        public int disc { get; set; default = 0; }
        public uint64 duration { get; set; default = 0; }

        //LOCATION
        string _uri = "";
        public string uri {
            get {
                return _uri;
            } set {
                _uri = value;
            }
        }

        public File? original_file { get; set; }

        public signal void path_not_found ();

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
        }

        public Track (TracksContainer? container = null) {
            if (container != null && container is Album) {
                this.set_album (container as Album);
            } else if (container != null && container is Playlist) {
                this.set_playlist (container as Playlist);
            } else if (container != null && container is AudioCD) {
                this.set_audio_cd (container as AudioCD);
            }
        }

        public void set_album (Album album) {
            this._album = album;
        }

        public void set_playlist (Playlist playlist) {
            this._playlist = playlist;
        }

        private void set_audio_cd (AudioCD audio_cd) {
            this._audio_cd = audio_cd;
        }

        public bool file_exists () {
            bool return_value = true;
            var file = File.new_for_uri (this.uri);
            if (!file.query_exists ()) {
                path_not_found ();
                return_value = false;
            }
            file.dispose ();
            return return_value;
        }
    }
}
