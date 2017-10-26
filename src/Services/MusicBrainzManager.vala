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
    public class MusicBrainzManager {
        static MusicBrainzManager _instance = null;

        public static MusicBrainzManager instance {
            get {
                if (_instance == null) {
                    _instance = new MusicBrainzManager();
                }
                return _instance;
            }
        }

        private MusicBrainzManager () {}

        GLib.List<Objects.Artist> artists = new GLib.List<Objects.Artist> ();

        bool artist_thread_running = false;

        public void fill_artist_cover_queue (Objects.Artist artist) {
            lock (artists) {
                artists.append (artist);
            }
            if (!artist_thread_running) {
                artist_thread_running = true;
                new Thread<void*> (null, () => {
                    var session = new Soup.Session.with_options ("user_agent", "PlayMyMusic/0.1.0 (https://github.com/artemanufrij/playmymusic)");
                    Objects.Artist? first = null;
                    while (artists.length () > 0) {

                        lock (artists) {
                            first = artists.first ().data;
                            if (first != null) {
                                artists.remove (first);
                            }
                        }

                        if (first!= null && first.cover == null) {
                            foreach (var album in first.albums) {
                                Thread.usleep (1000000);
                                string uri = "http://musicbrainz.org/ws/2/release/?query=release:%s AND artist:%s&fmt=json".printf (album.title, first.name);
                                var msg = new Soup.Message ("GET", uri);
                                session.send_message (msg);
                                if (msg.status_code == 200) {
                                    var body = (string)msg.response_body.data;
                                    var parser = new Json.Parser ();
                                    Json.Node root = null;
                                    try {
                                        parser.load_from_data (body);
                                        root = parser.get_root ();
                                    } catch (Error err) {
                                        warning (err.message);
                                    }
                                    if (root != null) {
                                        if (root.get_object ().has_member ("releases")) {
                                            var releases = root.get_object ().get_member ("releases").get_array ();
                                            if (releases.get_length () > 0) {
                                                var release = releases.get_element (0).get_object ();
                                                if (release.has_member ("artist-credit")) {
                                                    var artists = release.get_member ("artist-credit").get_array ();
                                                    if (artists.get_length () > 0) {
                                                        var art = artists.get_element (0).get_object ();
                                                        if (art.has_member ("artist")) {
                                                            var art_obj = art.get_member ("artist").get_object ();
                                                            if (art_obj.has_member ("id")) {
                                                                var artist_id = art_obj.get_string_member ("id");
                                                                stdout.printf ("ARTIST ID: %s\n", artist_id);
                                                                var pixbuf = get_pixbuf_by_artist_id (artist_id);
                                                                if (pixbuf != null) {
                                                                    pixbuf = LibraryManager.instance.align_and_scale_pixbuf (pixbuf, 256);
                                                                    try {
                                                                        pixbuf.save (first.cover_path, "jpeg", "quality", "100");
                                                                        first.load_cover_async.begin ();
                                                                        break;
                                                                    } catch (Error err) {
                                                                        warning (err.message);
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    artist_thread_running = false;
                    return null;
                });
            }
        }


        public static void fill_audio_cd (PlayMyMusic.Objects.AudioCD audio_cd) {
            var session = new Soup.Session.with_options  ("user_agent", "PlayMyMusic/0.1.0 (https://github.com/artemanufrij/playmymusic)");
            string uri = "http://musicbrainz.org/ws/2/discid/%s?inc=artists+recordings&fmt=json".printf (audio_cd.mb_disc_id);
            string album_id = "";

            var msg = new Soup.Message ("GET", uri);
            session.send_message (msg);
            if (msg.status_code == 200) {
                var body = (string)msg.response_body.data;
                var parser = new Json.Parser ();
                Json.Node root = null;
                try {
                    parser.load_from_data (body);
                    root = parser.get_root ();
                } catch (Error err) {
                    warning (err.message);
                }
                if (root != null) {
                    var o = root.get_object ();
                    if (o.has_member ("releases")) {
                        var releases = o.get_member ("releases");

                        var release = releases.get_array ().get_element (0);
                        audio_cd.title = release.get_object ().get_string_member ("title");
                        album_id = release.get_object ().get_string_member ("id");

                        var media_arr = release.get_object ().get_member ("media");
                        var media = media_arr.get_array().get_element (0);
                        var tracks = media.get_object ().get_member ("tracks");

                        foreach (var track in tracks.get_array ().get_elements ()) {
                            var track_title = track.get_object ().get_string_member ("title");
                            var track_number = track.get_object ().get_string_member ("number");
                            audio_cd.update_track_title (int.parse (track_number), track_title);
                        }

                        var artists = release.get_object ().get_member ("artist-credit");
                        var artist = artists.get_array ().get_element (0);
                        audio_cd.artist = artist.get_object ().get_string_member ("name");
                    }
                }

                if (album_id != "" && audio_cd.cover == null) {
                    uri = "http://coverartarchive.org/release/%s".printf (album_id);
                    msg = new Soup.Message ("GET", uri);
                    session.send_message (msg);
                    if (msg.status_code == 200) {
                        body = (string)msg.response_body.data;
                        root = null;
                        try {
                            parser.load_from_data (body);
                            root = parser.get_root ();
                        } catch (Error err) {
                            warning (err.message);
                        }
                        if (root != null) {
                            var o = root.get_object ();
                            if (o.has_member ("images")) {
                                var images = o.get_member ("images");
                                var image = images.get_array ().get_element (0);

                                o = image.get_object ();
                                if (o.has_member ("thumbnails")) {
                                    var thumbnail = o.get_member ("thumbnails");
                                    var large = thumbnail.get_object ().get_string_member ("large");

                                    var pixbuf = get_pixbuf_from_url (large);
                                    if (pixbuf != null) {
                                        pixbuf = LibraryManager.instance.align_and_scale_pixbuf (pixbuf, 320);
                                        try {
                                            pixbuf.save (audio_cd.cover_path, "jpeg", "quality", "100");
                                            audio_cd.load_cover_async.begin ();
                                        } catch (Error err) {
                                            warning (err.message);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        public Gdk.Pixbuf? get_pixbuf_by_artist_id (string id) {
            var session = new Soup.Session.with_options  ("user_agent", "PlayMyMusic/0.1.0 (https://github.com/artemanufrij/playmymusic)");
            string uri = "http://musicbrainz.org/ws/2/artist/%s?inc=url-rels&fmt=json".printf (id);
            var msg = new Soup.Message ("GET", uri);
            session.send_message (msg);

            if (msg.status_code == 200) {
                var body = (string)msg.response_body.data;
                var parser = new Json.Parser ();
                Json.Node root = null;
                try {
                    parser.load_from_data (body);
                    root = parser.get_root ();
                } catch (Error err) {
                    warning (err.message);
                }
                if (root != null && root.get_object ().has_member ("relations")) {
                    var array = root.get_object ().get_member ("relations").get_array ();
                    foreach (unowned Json.Node item in array.get_elements ()) {
                        var o = item.get_object ();
                        if (o.has_member ("type") && o.get_string_member ("type") == "image" && o.has_member ("url")) {
                            var url = o.get_member ("url").get_object ();
                            if (url.has_member ("resource")) {
                                var resource = url.get_string_member ("resource");
                                if (resource.index_of ("wikimedia.org") > -1) {
                                    var wiki_url = get_raw_url_for_wikimedia (resource);
                                    return get_pixbuf_from_url (wiki_url);
                                } else {
                                    return get_pixbuf_from_url (resource);
                                }
                                stdout.printf ("%s\n", resource);
                            }
                        }
                    }
                }
            }

            return null;
        }

        public string get_raw_url_for_wikimedia (string url) {
            MatchInfo match_info;
            var regex = new Regex ("(?<=/File:)[^<]*");
            if (regex.match (url, 0, out match_info)) {
                var session = new Soup.Session.with_options  ("user_agent", "PlayMyMusic/0.1.0 (https://github.com/artemanufrij/playmymusic)");
                var image_id = match_info.fetch (0);
                var request_url = "https://en.wikipedia.org/w/api.php?action=query&titles=File:%s&prop=imageinfo&iiprop=url&iiurlwidth=500&iiurlheight=500&format=json".printf (image_id);
                var msg = new Soup.Message ("GET", request_url);
                session.send_message (msg);
                if (msg.status_code == 200) {
                    var body = (string)msg.response_body.data;
                    regex = new Regex ("(?<=\"thumburl\":\")[^\"]*");
                    if (regex.match (body, 0, out match_info)) {
                        var result = match_info.fetch (0);
                        return result;
                    }
                }
            }
            return "";
        }

        public static Gdk.Pixbuf? get_pixbuf_from_url (string url) {
            if (!url.has_prefix ("http")) {
                return null;
            }
            Gdk.Pixbuf? return_value = null;
            var session = new Soup.Session.with_options ("user_agent", "PlayMyMusic/0.1.0 (https://github.com/artemanufrij/playmymusic)");
            var msg = new Soup.Message ("GET", url);
            session.send_message (msg);
            if (msg.status_code == 200) {
                string tmp_file = GLib.Path.build_filename (GLib.Environment.get_user_cache_dir (), Random.next_int ().to_string () + ".jpg");
                var fs = FileStream.open(tmp_file, "w");
                fs.write (msg.response_body.data, (size_t)msg.response_body.length);
                try {
                    return_value = new Gdk.Pixbuf.from_file (tmp_file);
                } catch (Error err) {
                    warning (err.message);
                }
                File f = File.new_for_path (tmp_file);
                f.delete_async.begin ();
            }
            return return_value;
        }
    }
}
