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
    public class DataBaseManager : GLib.Object {
        static DataBaseManager _instance = null;
        public static DataBaseManager instance {
            get {
                if (_instance == null) {
                    _instance = new DataBaseManager ();
                }
                return _instance;
            }
        }

        public signal void added_new_album (PlayMyMusic.Objects.Album album);

        GLib.List<PlayMyMusic.Objects.Artist> _artists = null;
        public GLib.List<PlayMyMusic.Objects.Artist> artists {
            get {
                if (_artists == null) {
                    _artists = get_artist_collection ();
                }
                return _artists;
            }
        }

        Sqlite.Database db;
        string errormsg;

        construct {
            _artists = new GLib.List<PlayMyMusic.Objects.Artist> ();
        }

        private DataBaseManager () {
            open_database ();
        }

        private void open_database () {
            File cache = File.new_for_path (PlayMyMusic.PlayMyMusicApp.instance.DB_PATH);
            bool database_exists = cache.query_exists ();

            Sqlite.Database.open (PlayMyMusic.PlayMyMusicApp.instance.DB_PATH, out db);

            if (!database_exists) {
                string q = """CREATE TABLE artists (
                    ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                    name        TEXT    NOT NULL,
                    CONSTRAINT unique_artist UNIQUE (name)
                    );""";

                if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                    warning (errormsg);
                }

                q = """CREATE TABLE albums (
                    ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                    artist_id   INT         NOT NULL,
                    title       TEXT        NOT NULL,
                    year        INT         NULL,
                    CONSTRAINT unique_album UNIQUE (artist_id, title)
                    );""";

                if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                    warning (errormsg);
                }

                q = """CREATE TABLE tracks (
                    ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                    album_id    INT         NOT NULL,
                    path        TEXT        NOT NULL,
                    title       TEXT        NOT NULL,
                    genre       TEXT        NULL,
                    track       INT         NOT NULL,
                    disc        INT         NOT NULL,
                    duration    INT         NOT NULL,
                    CONSTRAINT unique_track UNIQUE (path)
                    );""";

                if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                    warning (errormsg);
                }
            }
        }

        public async void reset_database () {
            SourceFunc callback = reset_database.callback;
            _artists = new GLib.List<PlayMyMusic.Objects.Artist> ();
            File cache = File.new_for_path (PlayMyMusic.PlayMyMusicApp.instance.DB_PATH);
            cache.delete_async.begin (Priority.DEFAULT, null, (obj, res) => {
                open_database ();
                Idle.add((owned) callback);
            });
            yield;
        }

// ARTIST REGION
        public GLib.List<PlayMyMusic.Objects.Artist> get_artist_collection () {
            GLib.List<PlayMyMusic.Objects.Artist> return_value = new GLib.List<PlayMyMusic.Objects.Artist> ();

            Sqlite.Statement stmt;
            string sql = """
                SELECT id, name FROM artists ORDER BY name;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                var item = new PlayMyMusic.Objects.Artist ();
                item.ID = stmt.column_int (0);
                item.name = stmt.column_text (1);
                return_value.append (item);
            }
            stmt.reset ();
            return return_value;
        }

        public void insert_artist (PlayMyMusic.Objects.Artist artist) {
            lock (_artists) {
                Sqlite.Statement stmt;
                string sql = """
                    INSERT OR IGNORE INTO artists (name) VALUES ($NAME);
                """;

                db.prepare_v2 (sql, sql.length, out stmt);
                set_parameter_str (stmt, sql, "$NAME", artist.name);

                if (stmt.step () != Sqlite.DONE) {
                    warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                }
                stmt.reset ();

                sql = """
                    SELECT id FROM artists WHERE name=$NAME;
                """;

                db.prepare_v2 (sql, sql.length, out stmt);
                set_parameter_str (stmt, sql, "$NAME", artist.name);

                if (stmt.step () == Sqlite.ROW) {
                    artist.ID = stmt.column_int (0);
                    stdout.printf ("Artist ID: %d\n", artist.ID);
                    lock (_artists) {
                        _artists.append (artist);
                    }
                } else {
                    warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                }
                stmt.reset ();
            }
        }

        public PlayMyMusic.Objects.Artist? get_artist_by_name (string name) {
            PlayMyMusic.Objects.Artist? return_value = null;
            lock (_artists) {
                foreach (var artist in artists) {
                    if (artist.name == name) {
                        return_value = artist;
                        break;
                    }
                }
                 return return_value;
            }
        }

// ALBUM REGION
        public GLib.List<PlayMyMusic.Objects.Album> get_album_collection (PlayMyMusic.Objects.Artist artist) {
            GLib.List<PlayMyMusic.Objects.Album> return_value = new GLib.List<PlayMyMusic.Objects.Album> ();
            Sqlite.Statement stmt;

            string sql = """
                SELECT id, title, year FROM albums WHERE artist_id=$ARTIST_ID ORDER BY year;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ARTIST_ID", artist.ID);

            while (stmt.step () == Sqlite.ROW) {
                var item = new PlayMyMusic.Objects.Album (artist);
                item.ID = stmt.column_int (0);
                item.title = stmt.column_text (1);
                item.year = stmt.column_int (2);
                return_value.append (item);
            }
            stmt.reset ();
            return return_value;
        }

        public void insert_album (PlayMyMusic.Objects.Album album) {
            Sqlite.Statement stmt;

            string sql = """
                INSERT OR IGNORE INTO albums (artist_id, title, year) VALUES ($ARTIST_ID, $TITLE, $YEAR);
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ARTIST_ID", album.artist.ID);
            set_parameter_str (stmt, sql, "$TITLE", album.title);
            set_parameter_int (stmt, sql, "$YEAR", album.year);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM albums WHERE artist_id=$ARTIST_ID AND title=$TITLE;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ARTIST_ID", album.artist.ID);
            set_parameter_str (stmt, sql, "$TITLE", album.title);

            if (stmt.step () == Sqlite.ROW) {
                album.ID = stmt.column_int (0);
                this.added_new_album (album);
                stdout.printf ("Album ID: %d\n", album.ID);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

// TRACK REGION
        public GLib.List<PlayMyMusic.Objects.Track> get_track_collection (PlayMyMusic.Objects.Album album) {
            GLib.List<PlayMyMusic.Objects.Track> return_value = new GLib.List<PlayMyMusic.Objects.Track> ();
            Sqlite.Statement stmt;

            string sql = """
                SELECT id, title, genre, track, disc, duration, path FROM tracks WHERE album_id=$ALBUM_ID ORDER BY disc, track;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ALBUM_ID", album.ID);

            while (stmt.step () == Sqlite.ROW) {
                var item = new PlayMyMusic.Objects.Track (album);
                item.ID = stmt.column_int (0);
                item.title = stmt.column_text (1);
                item.genre = stmt.column_text (2);
                item.track = stmt.column_int (3);
                item.disc = stmt.column_int (4);
                item.duration = (uint64)stmt.column_int64 (5);
                item.path = stmt.column_text (6);
                return_value.append (item);
            }
            stmt.reset ();
            return return_value;
        }

        public void insert_track (PlayMyMusic.Objects.Track track) {
            Sqlite.Statement stmt;

            string sql = """
                INSERT OR IGNORE INTO tracks (album_id, title, genre, track, disc, duration, path) VALUES ($ALBUM_ID, $TITLE, $GENRE, $TRACK, $DISC, $DURATION, $PATH);
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ALBUM_ID", track.album.ID);
            set_parameter_str (stmt, sql, "$TITLE", track.title);
            set_parameter_str (stmt, sql, "$GENRE", track.genre);
            set_parameter_int (stmt, sql, "$TRACK", track.track);
            set_parameter_int (stmt, sql, "$DISC", track.disc);
            set_parameter_int64 (stmt, sql, "$DURATION", (int64)track.duration);
            set_parameter_str (stmt, sql, "$PATH", track.path);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM tracks WHERE path=$PATH;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$PATH", track.path);

            if (stmt.step () == Sqlite.ROW) {
                track.ID = stmt.column_int (0);
                stdout.printf ("Track ID: %d\n", track.ID);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

// UTILITIES REGION
        public bool music_file_exists (string path) {
            bool file_exists = false;
            Sqlite.Statement stmt;

            string sql = """
                SELECT COUNT (*) FROM tracks WHERE path=$PATH;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$PATH", path);

            if (stmt.step () == Sqlite.ROW) {
                file_exists = stmt.column_int (0) > 0;
            }
            stmt.reset ();
            return file_exists;
        }

// PARAMENTER REGION
        private void set_parameter_int (Sqlite.Statement? stmt, string sql, string par, int val) {
            int par_position = stmt.bind_parameter_index (par);
            stmt.bind_int (par_position, val);
        }

        private void set_parameter_int64 (Sqlite.Statement? stmt, string sql, string par, int64 val) {
            int par_position = stmt.bind_parameter_index (par);
            stmt.bind_int64 (par_position, val);
        }

        private void set_parameter_str (Sqlite.Statement? stmt, string sql, string par, string val) {
            int par_position = stmt.bind_parameter_index (par);
            stmt.bind_text (par_position, val);
        }
    }
}
