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

namespace PlayMyMusic.Utils {
    public class MusicBrainz {
        public static string get_artist_id_from_artist_ws_2 (string body) {
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
                            var artist = artists.get_element (0).get_object ();
                            return artist.get_member ("artist").get_object ().get_string_member ("id");
                        }
                    }
                }
            }
            return "";
        }

        public static string get_large_thumbnail_from_release (string body) {
            var parser = new Json.Parser ();
            Json.Node root = null;
            try {
                parser.load_from_data (body);
                root = parser.get_root ();
            } catch (Error err) {
                warning (err.message);
            }
            if (root != null) {
                if (root.get_object ().has_member ("images")) {
                    var images = root.get_object ().get_member ("images").get_array ();
                    var image = images.get_element (0).get_object ();
                    if (image.has_member ("thumbnails")) {
                        var thumbnail = image.get_member ("thumbnails");
                        return thumbnail.get_object ().get_string_member ("large");
                    }
                }
            }
            return "";
        }
    }
}
