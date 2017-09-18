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
    public class LibraryManager : GLib.Object {
        static LibraryManager _instance = null;
        public static LibraryManager instance {
            get {
                if (_instance == null) {
                    _instance = new LibraryManager ();
                }
                return _instance;
            }
        }

        public signal void local_scan_started ();
        public signal void local_scan_finished ();
        public signal void tag_discover_started ();
        public signal void tag_discover_finished ();

        public PlayMyMusic.Services.TagManager tg_manager { get; construct set; }
        public PlayMyMusic.Services.DataBaseManager db_manager { get; construct set; }
        public PlayMyMusic.Services.LocalFilesManager lf_manager { get; construct set; }

        public GLib.List<PlayMyMusic.Objects.Artist> artists {
            get {
                return db_manager.artists;
            }
         }

        construct {
            tg_manager = PlayMyMusic.Services.TagManager.instance;
            tg_manager.discovered_new_item.connect (discovered_new_local_item);
            tg_manager.discover_started.connect ( () => { tag_discover_started (); });
            tg_manager.discover_finished.connect ( () => { tag_discover_finished (); });

            db_manager = PlayMyMusic.Services.DataBaseManager.instance;

            lf_manager = PlayMyMusic.Services.LocalFilesManager.instance;
            lf_manager.found_music_file.connect (found_local_music_file);
            lf_manager.scan_started.connect ( () => { local_scan_started (); });
            lf_manager.scan_finished.connect ( () => { local_scan_finished (); });
        }

        private LibraryManager () { }

        // LOCAL FILES REGION
        public void scan_local_library (string path) {
            lf_manager.scan (path);
        }

        private void found_local_music_file (string path) {
            if (!db_manager.music_file_exists (path)) {
                tg_manager.add_discover_path (path);
            }
        }

        // DATABASE REGION
        public void discovered_new_local_item (PlayMyMusic.Objects.Artist artist) {
            var album = artist.albums.first ().data;
            var track = album.tracks.first ().data;

            // CHECK IF ARTIST ALREADY EXISTS
            var db_artist = db_manager.get_artist_by_name (artist.name);
            if (db_artist == null) {
                db_manager.set_artist (artist);
                db_manager.set_album (album);
                db_manager.set_track (track);
            } else {
                var album_db = db_artist.get_album_by_title (album.title);
                if (album_db == null) {
                    db_artist.add_album (album);
                    db_manager.set_album (album);
                    db_manager.set_track (track);
                } else {
                    var track_db = album_db.get_track_by_path (track.path);
                    if (track_db == null) {
                        album_db.add_track (track);
                        db_manager.set_track (track);
                    }
                }
            }
        }
    }
}
