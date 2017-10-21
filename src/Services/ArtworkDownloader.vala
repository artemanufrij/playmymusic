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

// JUST A TRY. NOT REALY RELEVANT

/*
namespace PlayMyMusic.Services {


//http://musicbrainz.org/ws/2/release/?query=artist:Sting%20and%20title:The%20Best%20of%2025%20Years&limit=1

//http://ia801503.us.archive.org/32/items/mbid-c38ebc48-4d8a-4d6a-9554-09a931a9d725/index.json

http://coverartarchive.org/release/c38ebc48-4d8a-4d6a-9554-09a931a9d725

    public class ArtworkDownloader {
        public static Gdk.Pixbuf? get_arist_artwork (string name) {

            string request_url = "http://musicbrainz.org/ws/2/artist/?query=artist:" + name.strip().down().replace (" ", "_") + "&limit=5";
            stdout.printf ("%s\n\n", request_url);

            var session = new Soup.Session.with_options  ("user_agent", "PlayMyMusic/0.1.0 (https://github.com/artemanufrij/playmymusic)");
            var msg = new Soup.Message ("GET", request_url);

            session.send_message (msg);

            stdout.printf (msg.status_code.to_string () + "\n\n");

            if (msg.status_code == 200) {
                var body = (string)msg.response_body.data;

                var regex = new Regex ("(?<=artist\\sid=\")[\\w-]*");
                MatchInfo match_info;
                if (regex.match (body, 0, out match_info)) {
                    var artist_id = match_info.fetch (0);

                    stdout.printf ("\n%s\n", artist_id);

                    request_url = "http://musicbrainz.org/ws/2/artist/" + artist_id + "?inc=url-rels";

                    msg = new Soup.Message ("GET", request_url);
                    session.send_message (msg);
                    if (msg.status_code == 200) {
                        body = (string)msg.response_body.data;

                        regex = new Regex ("(?<=wikimedia\\.org/wiki/File:)[^<]*");
                        if (regex.match (body, 0, out match_info)) {
                            var image_id = match_info.fetch (0);
                            stdout.printf ("\n%s\n", image_id);

                            request_url = "https://en.wikipedia.org/w/api.php?action=query&titles=File:" + image_id + "&prop=imageinfo&iiprop=url&iiurlwidth=600&iiurlheight=600&format=json";
                            msg = new Soup.Message ("GET", request_url);
                            session.send_message (msg);
                            if (msg.status_code == 200) {
                                body = (string)msg.response_body.data;


                                string image_url = "";
                                int image_width = 0;
                                int image_height = 0;
                                regex = new Regex ("(?<=thumburl\":\")[^\"]*");
                                if (regex.match (body, 0, out match_info)) {
                                    image_url = match_info.fetch (0);
                                }
                                regex = new Regex ("(?<=thumbwidth\":)[\\d]*");
                                if (regex.match (body, 0, out match_info)) {
                                    image_width = int.parse (match_info.fetch (0));
                                }
                                regex = new Regex ("(?<=thumbheight\":)[\\d]*");
                                if (regex.match (body, 0, out match_info)) {
                                    image_height = int.parse (match_info.fetch (0));
                                }

                                if (image_url != "" && image_width > 0 && image_height > 0) {

                                    stdout.printf ("w: %d - h: %d: %s\n\n", image_width, image_height, image_url);

                                    msg = new Soup.Message ("GET", image_url);
                                    session.send_message (msg);
                                    if (msg.status_code == 200) {
                                        string tmp_file = GLib.Path.build_filename (GLib.Environment.get_user_cache_dir (), name + ".jpg");
                                        var fs = FileStream.open(tmp_file, "w");
                                        fs.write(msg.response_body.data, (size_t)msg.response_body.length);
                                        var return_value = new Gdk.Pixbuf.from_file (tmp_file);
                                        File f = File.new_for_path (tmp_file);
                                        f.delete_async.begin ();
                                        return return_value;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return null;
        }
    }
}
*/

