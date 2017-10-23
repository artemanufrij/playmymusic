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

        public static Gdk.Pixbuf? get_pixbuf_from_url (string url) {
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
