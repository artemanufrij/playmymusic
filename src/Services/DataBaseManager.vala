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
        public signal void added_new_artist (PlayMyMusic.Objects.Artist artist);
        public signal void added_new_album (PlayMyMusic.Objects.Album album);
        public signal void added_new_playlist (PlayMyMusic.Objects.Playlist playlist);
        public signal void removed_playlist (PlayMyMusic.Objects.Playlist playlist);
        public signal void added_new_radio (PlayMyMusic.Objects.Radio radio);
        public signal void removed_radio (PlayMyMusic.Objects.Radio radio);

        GLib.List<PlayMyMusic.Objects.Artist> _artists = null;
        public GLib.List<PlayMyMusic.Objects.Artist> artists {
            get {
                if (_artists == null) {
                    _artists = get_artist_collection ();
                }
                return _artists;
            }
        }

        GLib.List<PlayMyMusic.Objects.Radio> _radios = null;
        public  GLib.List<PlayMyMusic.Objects.Radio> radios {
            get {
                if (_radios == null) {
                    _radios = get_radio_collection ();
                }
                return _radios;
            }
        }

        GLib.List<PlayMyMusic.Objects.Playlist> _playlists = null;
        public GLib.List<PlayMyMusic.Objects.Playlist> playlists {
            get {
                if (_playlists == null) {
                    _playlists = get_playlist_collection ();
                }
                return _playlists;
            }
        }

        Sqlite.Database db;
        string errormsg;

        construct {
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
                    CONSTRAINT unique_album UNIQUE (artist_id, title),
                    FOREIGN KEY (artist_id) REFERENCES artists (ID)
                        ON DELETE CASCADE
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
                    CONSTRAINT unique_track UNIQUE (path),
                    FOREIGN KEY (album_id) REFERENCES albums (ID)
                        ON DELETE CASCADE
                    );""";

                if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                    warning (errormsg);
                }

                q = """CREATE TABLE blacklist (
                    ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                    path        TEXT        NOT NULL
                    )""";
                if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                    warning (errormsg);
                }

                q = """CREATE TABLE radios (
                    ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                    title       TEXT        NOT NULL,
                    url         TEXT        NOT NULL,
                    CONSTRAINT unique_track UNIQUE (url)
                    );""";
                if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                    warning (errormsg);
                }

                q = """CREATE TABLE playlists (
                    ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                    title       TEXT        NOT NULL,
                    CONSTRAINT unique_track UNIQUE (title)
                    );""";
                if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                    warning (errormsg);
                }

                q = """CREATE TABLE playlist_tracks (
                    ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                    playlist_id INT         NOT NULL,
                    track_id    INT         NOT NULL,
                    sort        INT         NOT NULL,
                    CONSTRAINT unique_track UNIQUE (playlist_id, track_id),
                    FOREIGN KEY (track_id) REFERENCES tracks (ID)
                        ON DELETE CASCADE,
                    FOREIGN KEY (playlist_id) REFERENCES playlists (ID)
                        ON DELETE CASCADE
                    );""";
                if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                    warning (errormsg);
                }

                q = """PRAGMA foreign_keys = ON;""";
                if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                    warning (errormsg);
                }
            }
        }

        public void reset_database () {
            File db_path = File.new_for_path (PlayMyMusic.PlayMyMusicApp.instance.DB_PATH);
            try {
                db_path.delete ();
            } catch (Error err) {
                warning (err.message);
            }
            _artists = new GLib.List<PlayMyMusic.Objects.Artist> ();
            open_database ();
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
                return_value.append (_fill_artist (stmt));
            }
            stmt.reset ();
            return return_value;
        }

        public PlayMyMusic.Objects.Artist? get_artist_by_album_id (int id) {
            PlayMyMusic.Objects.Artist? return_value = null;
            Sqlite.Statement stmt;
            string sql = """
                SELECT artist_id
                FROM albums
                WHERE id=$ALBUMS_ID
                ;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ALBUMS_ID", id);

            if (stmt.step () == Sqlite.ROW) {
                var artist_id = stmt.column_int (0);
                foreach (var artist in artists) {
                    if (artist.ID == artist_id) {
                        return artist;
                    }
                }
            }
            stmt.reset ();
            return return_value;
        }

        public PlayMyMusic.Objects.Artist _fill_artist (Sqlite.Statement stmt) {
            PlayMyMusic.Objects.Artist return_value = new PlayMyMusic.Objects.Artist ();
            return_value.ID = stmt.column_int (0);
            return_value.name = stmt.column_text (1);
            return return_value;
        }

        public void insert_artist (PlayMyMusic.Objects.Artist artist) {
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
                stdout.printf ("Artist ID: %d - %s\n", artist.ID, artist.name);
                _artists.append (artist);
                added_new_artist (artist);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

        public PlayMyMusic.Objects.Artist insert_artist_if_not_exists (PlayMyMusic.Objects.Artist new_artist) {
            PlayMyMusic.Objects.Artist? return_value = null;
            lock (_artists) {
                foreach (var artist in artists) {
                    if (artist.name == new_artist.name) {
                        return_value = artist;
                        break;
                    }
                }
                if (return_value == null) {
                    insert_artist (new_artist);
                    return_value = new_artist;
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
                return_value.append (_fill_album (stmt, artist));
            }
            stmt.reset ();
            return return_value;
        }

        public PlayMyMusic.Objects.Album? get_album_by_track_id (int id) {
            PlayMyMusic.Objects.Album? return_value = null;
            Sqlite.Statement stmt;

            string sql = """
                SELECT albums.id, albums.title, year
                FROM tracks LEFT JOIN albums
                ON tracks.album_id=albums.id
                WHERE tracks.id=$TRACK_ID;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$TRACK_ID", id);

            if (stmt.step () == Sqlite.ROW) {
                return_value = _fill_album (stmt, null);
            }
            stmt.reset ();
            return return_value;
        }

        private PlayMyMusic.Objects.Album _fill_album (Sqlite.Statement stmt, PlayMyMusic.Objects.Artist? artist) {
            PlayMyMusic.Objects.Album return_value = new PlayMyMusic.Objects.Album (artist);
            return_value.ID = stmt.column_int (0);
            return_value.title = stmt.column_text (1);
            return_value.year = stmt.column_int (2);
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
                added_new_album (album);
                stdout.printf ("Album ID: %d\n", album.ID);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

// PLAYLIST REGION
        public GLib.List<PlayMyMusic.Objects.Playlist> get_playlist_collection () {
            GLib.List<PlayMyMusic.Objects.Playlist> return_value = new GLib.List<PlayMyMusic.Objects.Playlist> ();
            Sqlite.Statement stmt;

            string sql = """
                SELECT id, title FROM playlists ORDER BY title;
            """;
            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                var item = new PlayMyMusic.Objects.Playlist ();
                item.ID = stmt.column_int (0);
                item.title = stmt.column_text (1);
                return_value.append (item);
            }
            stmt.reset ();
            return return_value;
        }

        public PlayMyMusic.Objects.Playlist? get_playlist_by_title (string title) {
            foreach (var playlist in playlists) {
                if (playlist.title == title) {
                    return playlist;
                }
            }
            return null;
        }

        public void update_playlist (PlayMyMusic.Objects.Playlist playlist) {
            Sqlite.Statement stmt;
            string sql = """
                UPDATE playlists SET title=$TITLE WHERE id=$ID;
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$TITLE", playlist.title);
            set_parameter_int (stmt, sql, "$ID", playlist.ID);
            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                playlist.property_changed ("title");
            }
            stmt.reset ();
        }

        public void insert_playlist (PlayMyMusic.Objects.Playlist playlist) {
            Sqlite.Statement stmt;
            string sql = """
                INSERT INTO playlists (title) VALUES ($TITLE);
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$TITLE", playlist.title);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM playlists WHERE title=$TITLE;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$TITLE", playlist.title);

            if (stmt.step () == Sqlite.ROW) {
                playlist.ID = stmt.column_int (0);
                _playlists.insert_sorted_with_data (playlist, (a, b) => {
                    return a.title.collate (b.title);
                });
                added_new_playlist (playlist);
                stdout.printf ("Playlist ID: %d\n", playlist.ID);

            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

        public void insert_track_into_playlist (PlayMyMusic.Objects.Playlist playlist, int track_id) {
            Sqlite.Statement stmt;
            string sql = """
                INSERT INTO playlist_tracks (playlist_id, track_id, sort) VALUES ($PLAYLIST_ID, $TRACK_ID, $SORT);
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$PLAYLIST_ID", playlist.ID);
            set_parameter_int (stmt, sql, "$TRACK_ID", track_id);
            set_parameter_int (stmt, sql, "$SORT", (int)playlist.tracks.length ());

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                var track = get_track_by_id (track_id);
                track.track = (int)playlist.tracks.length ();
                track.set_playlist (playlist);
                playlist.add_track (track);
            }
            stmt.reset ();
        }

        public void remove_playlist (PlayMyMusic.Objects.Playlist playlist) {
            this.pragma_foreign_keys ();
            Sqlite.Statement stmt;

            string sql = """
                DELETE FROM playlists WHERE id=$PLAYLIST_ID;
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$PLAYLIST_ID", playlist.ID);
            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                _playlists.remove (playlist);
                removed_playlist (playlist);
            }
            stmt.reset ();
        }

// TRACK REGION
        public GLib.List<PlayMyMusic.Objects.Track> get_track_collection (PlayMyMusic.Objects.TracksContainer container) {
            GLib.List<PlayMyMusic.Objects.Track> return_value = new GLib.List<PlayMyMusic.Objects.Track> ();
            Sqlite.Statement stmt;

            string sql;

            if (container is PlayMyMusic.Objects.Album) {
                sql = """
                    SELECT id, title, genre, track, disc, duration, path
                    FROM tracks
                    WHERE album_id=$CONTAINER_ID
                    ORDER BY disc, track;
                """;
            } else {
                sql = """
                    SELECT tracks.id, title, genre, sort, disc, duration, path
                    FROM playlist_tracks LEFT JOIN tracks
                    ON playlist_tracks.track_id = tracks.id
                    WHERE playlist_id=$CONTAINER_ID
                    ORDER BY sort;
                """;
            }

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$CONTAINER_ID", container.ID);

            while (stmt.step () == Sqlite.ROW) {
                return_value.append (_fill_track (stmt, container));
            }
            stmt.reset ();
            return return_value;
        }

        public PlayMyMusic.Objects.Track? get_track_by_id (int id) {
            PlayMyMusic.Objects.Track? return_value = null;
            Sqlite.Statement stmt;

            string sql = """
                SELECT id, title, genre, track, disc, duration, path
                FROM tracks
                WHERE id=$ID;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", id);

            if (stmt.step () == Sqlite.ROW) {
                return_value = _fill_track (stmt, null);
            }
            stmt.reset ();
            return return_value;
        }

        private PlayMyMusic.Objects.Track _fill_track (Sqlite.Statement stmt, PlayMyMusic.Objects.TracksContainer? container) {
            PlayMyMusic.Objects.Track return_value = new PlayMyMusic.Objects.Track (container);
            return_value.ID = stmt.column_int (0);
            return_value.title = stmt.column_text (1);
            return_value.genre = stmt.column_text (2);
            return_value.track = stmt.column_int (3);
            return_value.disc = stmt.column_int (4);
            return_value.duration = (uint64)stmt.column_int64 (5);
            return_value.path = stmt.column_text (6);
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

// RADIO REGION
        public GLib.List<PlayMyMusic.Objects.Radio> get_radio_collection () {
            GLib.List<PlayMyMusic.Objects.Radio> return_value = new GLib.List<PlayMyMusic.Objects.Radio> ();

            Sqlite.Statement stmt;
            string sql = """
                SELECT id, title, url FROM radios ORDER BY title;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                var item = new PlayMyMusic.Objects.Radio ();
                item.ID = stmt.column_int (0);
                item.title = stmt.column_text (1);
                item.url = stmt.column_text (2);
                return_value.append (item);
            }
            stmt.reset ();
            return return_value;
        }

        public PlayMyMusic.Objects.Radio? get_radio_by_id (int id) {
            lock (_radios) {
                foreach (var radio in radios) {
                    if (radio.ID == id) {
                        return radio;
                    }
                }
            }
            return null;
        }

        public PlayMyMusic.Objects.Radio? get_radio_by_url (string url) {
            lock (_radios) {
                foreach (var radio in radios) {
                    if (radio.url == url) {
                        return radio;
                    }
                }
            }
            return null;
        }

        public void update_radio (PlayMyMusic.Objects.Radio radio) {
            Sqlite.Statement stmt;

            string sql = """
                UPDATE radios SET title=$TITLE, url=$URL WHERE id=$ID;
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$TITLE", radio.title);
            set_parameter_str (stmt, sql, "$URL", radio.url);
            set_parameter_int (stmt, sql, "$ID", radio.ID);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

        public void insert_radio (PlayMyMusic.Objects.Radio radio) {
            Sqlite.Statement stmt;

            string sql = """
                INSERT OR IGNORE INTO radios (title, url) VALUES ($TITLE, $URL);
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$TITLE", radio.title);
            set_parameter_str (stmt, sql, "$URL", radio.url);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM radios WHERE url=$URL;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$URL", radio.url);

            if (stmt.step () == Sqlite.ROW) {
                radio.ID = stmt.column_int (0);
                lock (_radios) {
                    _radios.append (radio);
                }
                this.added_new_radio (radio);
                stdout.printf ("Radio ID: %d\n", radio.ID);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

        public void delete_radio (PlayMyMusic.Objects.Radio radio) {
            Sqlite.Statement stmt;

            string sql = """
                DELETE FROM radios WHERE id=$ID;
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", radio.ID);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                removed_radio (radio);
                radio.removed ();
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

        public bool radio_station_exists (string url) {
            bool file_exists = false;
            Sqlite.Statement stmt;

            string sql = """
                SELECT COUNT (*) FROM radios WHERE url=$url;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$url", url);

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

        private void pragma_foreign_keys () {
            string sql = """PRAGMA foreign_keys = ON;""";
            if (db.exec (sql, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }
        }
    }
}
