/*-
 * Copyright (c) 2017-2018 Artem Anufrij <artem.anufrij@live.de>
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
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
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
        public signal void added_new_artist (Objects.Artist artist);
        public signal void added_new_album (Objects.Album album);
        public signal void added_new_playlist (Objects.Playlist playlist);
        public signal void added_new_radio (Objects.Radio radio);
        public signal void adden_new_track (Objects.Track track);
        public signal void removed_playlist (Objects.Playlist playlist);
        public signal void artist_removed (Objects.Artist artist);
        public signal void removed_radio (Objects.Radio radio);

        GLib.List<Objects.Artist> _artists = null;
        public GLib.List<Objects.Artist> artists {
            get {
                if (_artists == null) {
                    _artists = get_artist_collection ();
                }
                return _artists;
            }
        }

        GLib.List<Objects.Radio> _radios = null;
        public  GLib.List<Objects.Radio> radios {
            get {
                if (_radios == null) {
                    _radios = get_radio_collection ();
                }
                return _radios;
            }
        }

        GLib.List<Objects.Playlist> _playlists = null;
        public GLib.List<Objects.Playlist> playlists {
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
            artist_removed.connect ((artist) => {
                _artists.remove (artist);
            });
        }

        private DataBaseManager () {
            open_database ();
        }

        private void open_database () {
            Sqlite.Database.open (PlayMyMusicApp.instance.DB_PATH, out db);

            string q;
            q = """CREATE TABLE IF NOT EXISTS artists (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                name        TEXT    NOT NULL,
                CONSTRAINT unique_artist UNIQUE (name)
                );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS albums (
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

            q = """CREATE TABLE IF NOT EXISTS tracks (
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

            q = """CREATE TABLE IF NOT EXISTS blacklist (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                path        TEXT        NOT NULL
                )""";
            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS radios (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                title       TEXT        NOT NULL,
                url         TEXT        NOT NULL,
                CONSTRAINT unique_url UNIQUE (url)
                );""";
            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS playlists (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                title       TEXT        NOT NULL,
                CONSTRAINT unique_title UNIQUE (title)
                );""";
            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """INSERT OR IGNORE INTO playlists (title) VALUES ('""" + PlayMyMusicApp.instance.QUEUE_SYS_NAME + """');""";
            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS playlist_tracks (
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

            q = """CREATE TABLE IF NOT EXISTS settings_tracks_hidden_columns (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                column      TEXT        NOT NULL
                );""";
            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """PRAGMA foreign_keys = ON;""";
            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }
        }

        public void reset_database () {
            File db_path = File.new_for_path (PlayMyMusicApp.instance.DB_PATH);
            try {
                db_path.delete ();
            } catch (Error err) {
                warning (err.message);
            }
            _artists = new GLib.List<Objects.Artist> ();
            open_database ();
        }

// ARTIST REGION
        public GLib.List<Objects.Artist> get_artist_collection () {
            GLib.List<Objects.Artist> return_value = new GLib.List<Objects.Artist> ();

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

        public Objects.Artist? get_artist_by_name (string name) {
            Objects.Artist? return_value = null;
            lock (_artists) {
                foreach (var artist in artists) {
                    if (artist.name == name) {
                        return_value = artist;
                        break;
                    }
                }
            }
            return return_value;
        }

        public Objects.Artist? get_artist_by_album_id (int id) {
            Objects.Artist? return_value = null;
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

        public Objects.Artist _fill_artist (Sqlite.Statement stmt) {
            Objects.Artist return_value = new Objects.Artist ();
            return_value.ID = stmt.column_int (0);
            return_value.name = stmt.column_text (1);
            return return_value;
        }

        public void insert_artist (Objects.Artist artist) {
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

        public void update_artist (Objects.Artist artist) {
            Sqlite.Statement stmt;
            string sql = """
                UPDATE artists SET name=$NAME WHERE id=$ID;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", artist.ID);
            set_parameter_str (stmt, sql, "$NAME", artist.name);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                artist.updated ();
            }
            stmt.reset ();
        }

        public Objects.Artist insert_artist_if_not_exists (Objects.Artist new_artist) {
            Objects.Artist? return_value = null;
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

        public void remove_artist (Objects.Artist artist) {
            Sqlite.Statement stmt;

            string sql = """
                DELETE FROM artists WHERE id=$ID;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", artist.ID);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                stdout.printf ("Artist Removed: %d\n", artist.ID);
                artist.removed ();
            }
            stmt.reset ();
        }

// ALBUM REGION
        public GLib.List<Objects.Album> get_album_collection (Objects.Artist artist) {
            GLib.List<Objects.Album> return_value = new GLib.List<Objects.Album> ();
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

        public Objects.Album? get_album_by_track_id (int id) {
            Objects.Album? return_value = null;
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

        private Objects.Album _fill_album (Sqlite.Statement stmt, Objects.Artist? artist) {
            Objects.Album return_value = new Objects.Album (artist);
            return_value.ID = stmt.column_int (0);
            return_value.title = stmt.column_text (1);
            return_value.year = stmt.column_int (2);
            return return_value;
        }

        public void insert_album (Objects.Album album) {
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
                stdout.printf ("Album ID: %d - %s\n", album.ID, album.title);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

        public void update_album (Objects.Album album) {
            Sqlite.Statement stmt;

            string sql = """
                UPDATE albums SET artist_id=$ARTIST_ID, title=$TITLE, year=$YEAR WHERE id=$ID;
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", album.ID);
            set_parameter_int (stmt, sql, "$ARTIST_ID", album.artist.ID);
            set_parameter_str (stmt, sql, "$TITLE", album.title);
            set_parameter_int (stmt, sql, "$YEAR", album.year);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                album.updated ();
            }
            stmt.reset ();
        }

        public void remove_album (Objects.Album album) {
            Sqlite.Statement stmt;

            string sql = """
                DELETE FROM albums WHERE id=$ID;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", album.ID);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                stdout.printf ("Album Removed: %d\n", album.ID);
                album.removed ();
            }
            stmt.reset ();
        }

// PLAYLIST REGION
        public GLib.List<Objects.Playlist> get_playlist_collection () {
            GLib.List<Objects.Playlist> return_value = new GLib.List<Objects.Playlist> ();
            Sqlite.Statement stmt;

            string sql = """
                SELECT id, title FROM playlists ORDER BY LOWER(title);
            """;
            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                var item = new Objects.Playlist ();
                item.ID = stmt.column_int (0);
                item.title = stmt.column_text (1);
                return_value.append (item);
            }
            stmt.reset ();
            return return_value;
        }

        public Objects.Playlist? get_playlist_by_title (string title) {
            foreach (var playlist in playlists) {
                if (playlist.title == title) {
                    return playlist;
                }
            }
            return null;
        }

        public Objects.Playlist? get_playlist_by_id (int id) {
            foreach (var playlist in playlists) {
                if (playlist.ID == id) {
                    return playlist;
                }
            }
            return null;
        }

        public Objects.Playlist? get_queue () {
            return get_playlist_by_title (PlayMyMusicApp.instance.QUEUE_SYS_NAME);
        }

        public void update_playlist (Objects.Playlist playlist) {
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
                _playlists.sort ((a, b) => {
                    return a.title.collate (b.title);
                });
                playlist.updated ();
            }
            stmt.reset ();
        }

        public void remove_track_from_playlist (Objects.Track track) {
            Sqlite.Statement stmt;
            string sql = """
                DELETE FROM playlist_tracks WHERE playlist_id=$PLAYLIST_ID AND track_id=$TRACK_ID;
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$PLAYLIST_ID", track.playlist.ID);
            set_parameter_int (stmt, sql, "$TRACK_ID", track.ID);
            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                track.removed ();
            }
            stmt.reset ();
        }

        public void insert_playlist (Objects.Playlist playlist) {
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

        public void insert_track_into_playlist (Objects.Playlist playlist, int track_id) {
            int next_sort_item = playlist.get_next_sort_item ();

            Sqlite.Statement stmt;
            string sql = """
                INSERT INTO playlist_tracks (playlist_id, track_id, sort) VALUES ($PLAYLIST_ID, $TRACK_ID, $SORT);
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$PLAYLIST_ID", playlist.ID);
            set_parameter_int (stmt, sql, "$TRACK_ID", track_id);
            set_parameter_int (stmt, sql, "$SORT", next_sort_item);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                var track = get_track_by_id (track_id);
                track.track = next_sort_item;
                track.set_playlist (playlist);
                playlist.add_track (track);
            }
            stmt.reset ();
        }

        public void resort_track_in_playlist (Objects.Playlist playlist, Objects.Track track, int new_sort_value) {
            Sqlite.Statement stmt;
            string sql ="";

            if (track.track > new_sort_value) {
                sql = """
                    UPDATE playlist_tracks SET sort=(sort+1) WHERE playlist_id=$PLAYLIST_ID AND sort<$SORT_BEFORE AND sort>=$SORT_NEW;
                """;
            } else {
                sql = """
                    UPDATE playlist_tracks SET sort=(sort-1) WHERE playlist_id=$PLAYLIST_ID AND sort>$SORT_BEFORE AND sort<$SORT_NEW;
                """;
            }
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$PLAYLIST_ID", playlist.ID);
            set_parameter_int (stmt, sql, "$SORT_BEFORE", track.track);
            set_parameter_int (stmt, sql, "$SORT_NEW", new_sort_value);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            if (track.track > new_sort_value) {
                sql = """
                    UPDATE playlist_tracks SET sort=$SORT WHERE playlist_id=$PLAYLIST_ID AND track_id=$TRACK_ID;
                """;
            } else {
                sql = """
                    UPDATE playlist_tracks SET sort=$SORT-1 WHERE playlist_id=$PLAYLIST_ID AND track_id=$TRACK_ID;
                """;
            }
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$PLAYLIST_ID", playlist.ID);
            set_parameter_int (stmt, sql, "$TRACK_ID", track.ID);
            set_parameter_int (stmt, sql, "$SORT", new_sort_value);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                playlist.resort_track (track, new_sort_value);
            }
            stmt.reset ();
        }

        public void remove_playlist (Objects.Playlist playlist) {
            if (playlist.title == PlayMyMusicApp.instance.QUEUE_SYS_NAME) {
                return;
            }

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
        public GLib.List<Objects.Track> get_track_collection (Objects.TracksContainer container) {
            GLib.List<Objects.Track> return_value = new GLib.List<Objects.Track> ();
            Sqlite.Statement stmt;

            string sql;

            if (container is Objects.Album) {
                sql = """
                    SELECT id, title, genre, track, disc, duration, path
                    FROM tracks
                    WHERE album_id=$CONTAINER_ID
                    ORDER BY disc, track, title;
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

        public Objects.Track? get_track_by_id (int id) {
            Objects.Track? return_value = null;
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

        public Objects.Track? get_track_by_uri (string uri) {
            Objects.Track? return_value = null;
            Sqlite.Statement stmt;

            string sql = """
                SELECT id, title, genre, track, disc, duration, path
                FROM tracks
                WHERE path=$URI;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$URI", uri);

            if (stmt.step () == Sqlite.ROW) {
                return_value = _fill_track (stmt, null);
            }
            stmt.reset ();
            return return_value;
        }

        private Objects.Track _fill_track (Sqlite.Statement stmt, Objects.TracksContainer? container) {
            Objects.Track return_value = new Objects.Track (container);
            return_value.ID = stmt.column_int (0);
            return_value.title = stmt.column_text (1);
            return_value.genre = stmt.column_text (2);
            return_value.track = stmt.column_int (3);
            return_value.disc = stmt.column_int (4);
            return_value.duration = (uint64)stmt.column_int64 (5);
            return_value.uri = stmt.column_text (6);
            if (return_value.uri.has_prefix ("/")) {
                return_value.uri =  "file://" + return_value.uri;
            }
            return return_value;
        }

        public void insert_track (Objects.Track track) {
            Sqlite.Statement stmt;

            string sql = """
                INSERT OR IGNORE INTO tracks (album_id, title, genre, track, disc, duration, path) VALUES ($ALBUM_ID, $TITLE, $GENRE, $TRACK, $DISC, $DURATION, $URI);
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ALBUM_ID", track.album.ID);
            set_parameter_str (stmt, sql, "$TITLE", track.title);
            set_parameter_str (stmt, sql, "$GENRE", track.genre);
            set_parameter_int (stmt, sql, "$TRACK", track.track);
            set_parameter_int (stmt, sql, "$DISC", track.disc);
            set_parameter_int64 (stmt, sql, "$DURATION", (int64)track.duration);
            set_parameter_str (stmt, sql, "$URI", track.uri);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM tracks WHERE path=$URI;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$URI", track.uri);

            if (stmt.step () == Sqlite.ROW) {
                track.ID = stmt.column_int (0);
                stdout.printf ("Track ID: %d - %s\n", track.ID, track.title);
                adden_new_track (track);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

        public void update_track (Objects.Track track) {
            Sqlite.Statement stmt;

            string sql = """
                UPDATE tracks SET album_id=$ALBUM_ID, title=$TITLE, genre=$GENRE, track=$TRACK, disc=$DISC, duration=$DURATION, path=$URI WHERE id=$ID;
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", track.ID);
            set_parameter_int (stmt, sql, "$ALBUM_ID", track.album.ID);
            set_parameter_str (stmt, sql, "$TITLE", track.title);
            set_parameter_str (stmt, sql, "$GENRE", track.genre);
            set_parameter_int (stmt, sql, "$TRACK", track.track);
            set_parameter_int (stmt, sql, "$DISC", track.disc);
            set_parameter_int64 (stmt, sql, "$DURATION", (int64)track.duration);
            set_parameter_str (stmt, sql, "$URI", track.uri);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

        public void remove_track (Objects.Track track) {
            Sqlite.Statement stmt;

            string sql = """
                DELETE FROM tracks WHERE id=$ID;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", track.ID);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                stdout.printf ("Track Removed: %d\n", track.ID);
                track.removed ();
            }
            stmt.reset ();
        }

// RADIO REGION
        public GLib.List<Objects.Radio> get_radio_collection () {
            GLib.List<Objects.Radio> return_value = new GLib.List<Objects.Radio> ();

            Sqlite.Statement stmt;
            string sql = """
                SELECT id, title, url FROM radios ORDER BY title;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                var item = new Objects.Radio ();
                item.ID = stmt.column_int (0);
                item.title = stmt.column_text (1);
                item.url = stmt.column_text (2);
                return_value.append (item);
            }
            stmt.reset ();
            return return_value;
        }

        public Objects.Radio? get_radio_by_id (int id) {
            lock (_radios) {
                foreach (var radio in radios) {
                    if (radio.ID == id) {
                        return radio;
                    }
                }
            }
            return null;
        }

        public Objects.Radio? get_radio_by_url (string url) {
            lock (_radios) {
                foreach (var radio in radios) {
                    if (radio.url == url) {
                        return radio;
                    }
                }
            }
            return null;
        }

        public void update_radio (Objects.Radio radio) {
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

        public void insert_radio (Objects.Radio radio) {
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

        public void delete_radio (Objects.Radio radio) {
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

// SETTINGS REGION
        public GLib.List<string> settings_get_hidde_columns () {
            GLib.List<string> return_value = new GLib.List<string> ();

            Sqlite.Statement stmt;
            string sql = """
                SELECT id, column FROM settings_tracks_hidden_columns ORDER BY column;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                return_value.append (stmt.column_text (1));
            }
            stmt.reset ();
            return return_value;
        }

        public bool settings_delete_hidden_column (string column) {
            var return_value = false;
            Sqlite.Statement stmt;

            string sql = """
                DELETE FROM settings_tracks_hidden_columns WHERE column=$COLUMN;
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$COLUMN", column);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                return_value = true;
            }
            stmt.reset ();

            return return_value;
        }

        public bool settings_insert_hidden_column (string column) {
            var return_value = false;
            Sqlite.Statement stmt;

            string sql = """
                INSERT INTO settings_tracks_hidden_columns (column) VALUES ($COLUMN);
            """;
            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$COLUMN", column);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                return_value = true;
            }
            stmt.reset ();

            return return_value;
        }


// UTILITIES REGION
        public bool music_file_exists (string uri) {
            bool file_exists = false;
            Sqlite.Statement stmt;

            string sql = """
                SELECT COUNT (*) FROM tracks WHERE path=$URI;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$URI", uri);

            if (stmt.step () == Sqlite.ROW) {
                file_exists = stmt.column_int (0) > 0;
            }

            // [0.3.1] JUST NEEDED IF DATABASE CONTAINS /path/to/file LOCATIONS
            if (!file_exists && uri.has_prefix ("file://")) {
                stmt.reset ();
                db.prepare_v2 (sql, sql.length, out stmt);
                set_parameter_str (stmt, sql, "$URI", uri.substring (7));
                if (stmt.step () == Sqlite.ROW) {
                    file_exists = stmt.column_int (0) > 0;
                }
            }
            stmt.reset ();
            return file_exists;
        }

        public bool radio_station_exists (string url) {
            bool file_exists = false;
            Sqlite.Statement stmt;

            string sql = """
                SELECT COUNT (*) FROM radios WHERE url=$URL;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$URL", url);

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
