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
    public class Playlist : TracksContainer {
        public signal void tracks_resorted ();
        public new GLib.List<Track> tracks {
            get {
                if (_tracks == null) {
                    _tracks = library_manager.db_manager.get_track_collection (this);
                    foreach (var track in _tracks) {
                        track.removed.connect (() => {
                            _tracks.remove (track);
                        });
                    }
                }
                return _tracks;
            }
        }

        construct {
            track_removed.connect ((track) => {
                this._tracks.remove (track);
                if (this.tracks.length () == 0) {
                    db_manager.remove_playlist (this);
                }
            });
        }

        public new void add_track (Track track) {
            base.add_track (track);
            track.removed.connect (() => {
                _tracks.remove (track);
            });
        }

        public new bool has_track (int track_id) {
            foreach (var track in tracks) {
                if (track.ID == track_id) {
                    return true;
                }
            }
            return false;
        }

        public void resort_track (Track track, int new_sort_value) {
            if (track.track > new_sort_value) {
                foreach (var t in tracks) {
                    if (t.track < track.track && t.track >= new_sort_value) {
                        t.track ++;
                    }
                }
                track.track = new_sort_value;
            } else {
                foreach (var t in tracks) {
                    if (t.track > track.track && t.track < new_sort_value) {
                        t.track --;
                    }
                }
                track.track = new_sort_value - 1;
            }
            _tracks.sort ((a, b) => {
                return a.track - b.track;
            });
            tracks_resorted ();
        }

        public int get_next_sort_item () {
            int return_value = 0;
            foreach (var track in tracks) {
                if (return_value < track.track) {
                    return_value = track.track;
                }
            }
            return return_value + 1;
        }
    }
}
