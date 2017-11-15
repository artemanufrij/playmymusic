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

namespace PlayMyMusic.Objects {
    public class MobilePhone : GLib.Object {
        public Volume volume { get; private set; }

        public signal void music_folder_found (MobilePhoneMusicFolder music_folder);
        public signal void storage_calculated ();
        public signal void copy_started ();
        public signal void copy_finished ();
        public signal void copy_progress (string title, uint count, uint sum);

        public uint64 size { get; private set; }
        public uint64 free { get; private set; }

        public GLib.List<MobilePhoneMusicFolder> music_folders;

        string no_items = _("Empty Music Folder");

        construct {
            music_folders = new GLib.List<MobilePhoneMusicFolder> ();
        }

        public MobilePhone (Volume volume) {
            this.volume = volume;
            this.volume.mount.begin (MountMountFlags.NONE, null, null, (obj, res) => {
                calculate_storage ();
                found_music_folder (volume.get_activation_root ().get_uri ());
            });
        }

        private void calculate_storage () {
            try {
                var info = volume.get_activation_root ().query_filesystem_info ("filesystem::*");
                free = info.get_attribute_uint64 ("filesystem::free");
                size = info.get_attribute_uint64 ("filesystem::size");
                storage_calculated ();
            } catch (Error err) {
                warning (err.message);
            }
        }

        public void found_music_folder (string uri) {
            new Thread <void*> (null, () => {
                var file = File.new_for_uri (uri);
                try {
                    var children = file.enumerate_children ("standard::*", GLib.FileQueryInfoFlags.NONE);
                    FileInfo file_info = null;
                    while ((file_info = children.next_file ()) != null) {
                        if (file_info.get_file_type () == FileType.DIRECTORY) {
                            if (file_info.get_name ().down () == "music") {
                                create_music_folder (uri + file_info.get_name () + "/");
                            } else {
                                found_music_folder (uri + file_info.get_name () + "/");
                            }
                        }
                    }
                } catch (Error err) {
                    warning (err.message);
                }
                return null;
            });
        }

        public void add_album (Album album, MobilePhoneMusicFolder target_folder) {
            copy_started ();
            copy_progress ("", 0, album.tracks.length ());

            new Thread<void*> (null, () => {
                var artist_folder = target_folder.get_sub_folder (album.artist.name);
                if (artist_folder == null) {
                    Idle.add (() => {
                        copy_finished ();
                        return false;
                    });
                    return null;
                }

                var album_folder = artist_folder.get_sub_folder (album.title);
                if (album_folder == null) {
                    Idle.add (() => {
                        copy_finished ();
                        return false;
                    });
                    return null;
                }
                int progress = 0;
                foreach (var track in album.tracks) {

                stdout.printf ("%s\n", album_folder.file.get_uri () + "/" + Path.get_basename (track.path));
                    var target = File.new_for_uri (album_folder.file.get_uri () + "/" + Path.get_basename (track.path));
                    Idle.add (() => {
                        copy_progress (track.title, progress++, album.tracks.length ());
                        return false;
                    });

                    if (target.query_exists ()) {
                        target.dispose ();
                        continue;
                    }

                    var source = File.new_for_uri (track.uri);
                    try {
                        source.copy (target, FileCopyFlags.NONE);
                        calculate_storage ();
                    } catch (Error err) {
                        warning (err.message);
                        continue;
                    }

                    target.dispose ();
                    source.dispose ();
                }
                Idle.add (() => {
                    copy_finished ();
                    return false;
                });
                return null;
            });
        }

        public void add_artist (Artist album, MobilePhoneMusicFolder target_folder) {

        }

        private void create_music_folder (string uri) {
            var music_folder = new MobilePhoneMusicFolder (uri);
            music_folder.name = music_folder.file.get_parent ().get_basename ();

            var empty_folder = new Granite.Widgets.SourceList.Item (no_items);
            music_folder.add (empty_folder);
            empty_folder.visible = music_folder.n_children < 2;

            music_folder.subfolder_deleted.connect (() => {
                empty_folder.visible = music_folder.n_children < 2;
                calculate_storage ();
            });

            music_folder.child_added.connect ((item) => {
                empty_folder.visible = music_folder.n_children < 2;
            });

            music_folders.append (music_folder);
            music_folder_found (music_folder);
        }
    }
}
