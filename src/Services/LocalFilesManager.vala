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
    public class LocalFilesManager : GLib.Object {
        static LocalFilesManager _instance = null;
        public static LocalFilesManager instance {
            get {
                if (_instance == null) {
                    _instance = new LocalFilesManager ();
                }
                return _instance;
            }
        }

        public signal void scan_started ();
        public signal void found_music_file (string path);

        private LocalFilesManager () { }

        public void scan (string path) {
            scan_started ();
            scan_local_files (path);
        }

        private void scan_local_files (string uri) {
            new Thread<void*> ("scan_local_files", () => {
                File directory = File.new_for_uri (uri.replace ("#", "%23"));
                stdout.printf ("%s\n", directory.get_uri ());
                try {
                    var children = directory.enumerate_children ("standard::*," + FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_IS_HIDDEN + "," + FileAttribute.STANDARD_IS_SYMLINK + "," + FileAttribute.STANDARD_SYMLINK_TARGET, GLib.FileQueryInfoFlags.NONE);
                    FileInfo file_info = null;

                    while ((file_info = children.next_file ()) != null) {
                        if (file_info.get_is_hidden ()) {
                            continue;
                        }

                        if (file_info.get_is_symlink ()) {
                            string target = file_info.get_symlink_target ();
                            var symlink = File.new_for_path (target);
                            var file_type = symlink.query_file_type (0);
                            if (file_type == FileType.DIRECTORY) {
                                scan_local_files (target);
                            }
                        } else if (file_info.get_file_type () == FileType.DIRECTORY) {
                            // Without usleep it crashes on smb:// protocol and mounted devices
                            //if (!directory.get_uri ().has_prefix ("file://")) {
                                Thread.usleep (1000000);
                            //}
                            scan_local_files (directory.get_uri () + "/" + file_info.get_name ());
                        } else {
                            string mime_type = file_info.get_content_type ();
                            if (Utils.is_audio_file (mime_type)) {
                                found_music_file (directory.get_uri () + "/" + file_info.get_name ().replace ("#", "%23"));
                            }
                        }
                    }
                    children.close ();
                    children.dispose ();
                } catch (Error err) {
                    warning ("%s\n%s", err.message, uri);
                }
                directory.dispose ();
                return null;
            });
        }

        public string get_file_uri (string path, string parent = "") {
            string file_uri = path;
            if (!path.has_prefix ("/")) {
                file_uri = "%s/%s".printf(parent, path);
                stdout.printf ("%s seems not an absolute path: adding parent (%s)\n", path, file_uri);
            }

            File path_file = File.new_for_path(file_uri);
            try {
                FileInfo path_file_info = path_file.query_info ("%s,%s".printf (FileAttribute.STANDARD_SYMLINK_TARGET, FileAttribute.STANDARD_IS_SYMLINK), FileQueryInfoFlags.NONE);
                if (path_file_info.get_is_symlink ()) {
                    stdout.printf ("%s is symlink: getting target...\n", file_uri);
                    file_uri = path_file_info.get_symlink_target ();
                    file_uri = (!file_uri.has_prefix ("/")) ? "%s/%s".printf(parent, file_uri) : file_uri;
                    stdout.printf ("Target: %s\n", file_uri);
                    path_file = File.new_for_path (file_uri);
                }
            } catch (Error error) {
                // cannot parse file symlinks informations
                // ignore it
            }

            stdout.printf ("Returning absolute path: %s\n", path_file.resolve_relative_path (".").get_path ());
            return path_file.resolve_relative_path (".").get_path ();
        }
    }
}
