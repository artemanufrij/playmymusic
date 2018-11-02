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

namespace PlayMyMusic {
    public enum RepeatMode {
        OFF = 0,
        ALL = 1,
        ONE = 2
    }

    public class Settings : Granite.Services.Settings {
        private static Settings settings;
        public static Settings get_default () {
            if (settings == null) {
                settings = new Settings ();
            }
            return settings;
        }
        public int window_width { get; set; }
        public int window_height { get; set; }
        public int window_x { get; set; }
        public int window_y { get; set; }
        public bool window_maximized { get; set; }
        public bool shuffle_mode { get; set; }
        public RepeatMode repeat_mode { get; set; }
        public int last_artist_id { get; set; }
        public int last_album_id { get; set; }
        public int last_playlist_id { get; set; }
        public int last_track_id { get; set; }
        public double track_progress { get; set; }
        public string track_source { get; set; }
        public bool remember_track_progress { get; set; }
        public bool play_in_background { get; set; }
        public bool sync_files { get; set; }
        public string [] artists { get; set; }
        public string [] covers { get; set; }
        public string library_location { get; set; }
        public int view_index { get; set; }
        public string [] hidden_tracks_columns { get; set; }
        public bool load_content_from_musicbrainz { get; set; }
        public bool use_dark_theme { get; set; }
        public bool save_custom_covers { get; set; }
        public bool save_id3_tags { get; set; }
        public bool import_into_library { get; set; }
        public bool remove_playlist_if_empty { get; set; }
        public int sort_mode_album_view { get; set; }

        private Settings () {
            base ("com.github.artemanufrij.playmymusic");
        }

        public void switch_repeat_mode () {
            switch (settings.repeat_mode) {
                case RepeatMode.ALL:
                    settings.repeat_mode = RepeatMode.ONE;
                    break;
                case RepeatMode.ONE:
                    settings.repeat_mode = RepeatMode.OFF;
                    break;
                default:
                    settings.repeat_mode = RepeatMode.ALL;
                    break;
            }
        }
    }
}
