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

namespace PlayMyMusic.Utils {
    public static string get_formated_duration (uint64 duration) {
        uint seconds = (uint)(duration / 1000000000);
        if (seconds < 3600) {
            uint minutes = seconds / 60;
            seconds -= minutes * 60;
            return "%u:%02u".printf (minutes, seconds);
        }

        uint hours = seconds / 3600;
        seconds -= hours * 3600;
        uint minutes = seconds / 60;
        seconds -= minutes * 60;
        return "%u:%02u:%02u".printf (hours, minutes, seconds);
    }

    public static bool is_audio_file (string mime_type) {
        return mime_type.has_prefix ("audio/") && !mime_type.contains ("x-mpegurl") && !mime_type.contains ("x-scpls");
    }

    public static void delete_uri_recursive (string uri) {
        try {
            var directory = File.new_for_uri (uri);
            var children = directory.enumerate_children ("standard::*", GLib.FileQueryInfoFlags.NONE);
            FileInfo file_info = null;
            while ((file_info = children.next_file ()) != null) {
                if (file_info.get_file_type () == FileType.DIRECTORY) {
                    delete_uri_recursive (directory.get_uri () + "/" + file_info.get_name ());
                } else {
                    var usb = File.new_for_uri (directory.get_uri () + "/" + file_info.get_name ());
                    usb.delete ();
                }
            }
            directory.delete ();
        } catch (Error err) {
            warning (err.message);
        }
    }

    public static string markdown_format (string input) {
        return input.replace ("&", "&amp;").replace ("<", "&#60;").replace (">", "&#62;");
    }

    public static void set_custom_css_style (Gdk.Screen screen) {
        Granite.Widgets.Utils.set_theming_for_screen (
            screen,
                """
                    .artist-title {
                        color: #fff;
                        text-shadow: 0px 1px 2px alpha (#000, 1);
                    }
                    .artist-sub-title {
                        color: #fff;
                        text-shadow: 0px 1px 2px alpha (#000, 1);
                    }
                    .playlist-tracks {
                        background: transparent;
                    }
                    .mode_button_split {
                        border-left-width: 1px;
                    }
                    .artist-tracks {
                        background: rgba (245, 245, 245, 0.75);
                    }
                    .artist-tracks-dark {
                        background: rgba (54, 59, 62, 0.75);
                    }
                    .custom_titlebar {
                        padding-top: 0px;
                        padding-bottom: 0px;
                    }
                    .track-drag-begin {
                        border-top: 1px solid #666666;
                    }
                    .mobile-close-button {
                        padding: 3px;
                        opacity: 0.75;
                    }
                """,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
    }
}
