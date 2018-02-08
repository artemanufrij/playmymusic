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

        public bool is_copying { get; private set; }

        public GLib.List<MobilePhoneMusicFolder> music_folders;

        string no_items = _ ("No Music Files found");

        construct {
            music_folders = new GLib.List<MobilePhoneMusicFolder> ();
            copy_started.connect (
                () => {
                    is_copying = true;
                });
            copy_finished.connect (
                () => {
                    is_copying = false;
                });
        }

        public MobilePhone (Volume volume) {
            this.volume = volume;
            if (this.volume.get_mount () == null || volume.get_activation_root () == null) {
                this.volume.mount.begin (
                    MountMountFlags.NONE,
                    null,
                    null,
                    (obj, res) => {
                        calculate_storage ();
                        found_music_folder (volume.get_activation_root ().get_uri ());
                    });
            } else {
                calculate_storage ();
                found_music_folder (volume.get_activation_root ().get_uri ());
            }
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
            new Thread <void*> (
                "found_music_folder",
                () => {
                    var file = File.new_for_uri (uri);
                    try {
                        var children = file.enumerate_children ("standard::*", GLib.FileQueryInfoFlags.NONE);
                        FileInfo file_info = null;
                        while ((file_info = children.next_file ()) != null) {
                            if (file_info.get_file_type () == FileType.DIRECTORY) {
                                if (file_info.get_name ().down () == "music") {
                                    create_music_folder (uri + file_info.get_name () + "/");
                                    break;
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
            if (is_copying) {
                return;
            }
            copy_started ();
            copy_progress ("", 0, 1);

            new Thread<void*> (
                "add_album",
                () => {
                    var artist_folder = target_folder.get_sub_folder (album.artist.name);
                    if (artist_folder == null) {
                        Idle.add (
                            () => {
                                copy_finished ();
                                return false;
                            });
                        return null;
                    }
                    copy_cover (artist_folder.file.get_uri () + "/artist.jpg", album.artist.cover_path);

                    var album_folder = artist_folder.get_sub_folder (album.title);
                    if (album_folder == null) {
                        Idle.add (
                            () => {
                                copy_finished ();
                                return false;
                            });
                        return null;
                    }

                    copy_cover (album_folder.file.get_uri () + "/cover.jpg", album.cover_path);
                    int progress = 0;
                    foreach (var track in album.tracks) {
                        stdout.printf ("%s\n", album_folder.file.get_uri () + "/" + Path.get_basename (track.uri));
                        var target = File.new_for_uri (album_folder.file.get_uri () + "/" + Path.get_basename (track.uri));
                        Idle.add (
                            () => {
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
                    Idle.add (
                        () => {
                            copy_finished ();
                            return false;
                        });
                    return null;
                });
        }

        public void add_artist (Artist artist, MobilePhoneMusicFolder target_folder) {
            if (is_copying) {
                return;
            }
            copy_started ();
            copy_progress ("", 0, 1);

            new Thread<void*> (
                "add_artist",
                () => {
                    var artist_folder = target_folder.get_sub_folder (artist.name);
                    if (artist_folder == null) {
                        Idle.add (
                            () => {
                                    copy_finished ();
                                return false;
                            });
                        return null;
                    }

                    int progress = 0;
                    foreach (var album in artist.albums) {
                        var album_folder = artist_folder.get_sub_folder (album.title);
                        if (album_folder == null) {
                            Idle.add (
                                () => {
                                    copy_finished ();
                                    return false;
                                });
                            return null;
                        }

                        foreach (var track in album.tracks) {
                            stdout.printf ("%s\n", album_folder.file.get_uri () + "/" + Path.get_basename (track.uri));
                            var target = File.new_for_uri (GLib.Uri.unescape_string (album_folder.file.get_uri () + "/" + Path.get_basename (track.uri)));
                            Idle.add (
                                () => {
                                    copy_progress (track.title, progress++, artist.tracks.length ());
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
                    }
                    Idle.add (
                        () => {
                            copy_finished ();
                            return false;
                        });
                    return null;
                });
        }

        public void add_track (Track track, MobilePhoneMusicFolder target_folder) {
            if (is_copying) {
                return;
            }
            copy_started ();
            copy_progress ("", 0, 1);
            new Thread<void*> (
                "add_track",
                () => {
                    var artist_folder = target_folder.get_sub_folder (track.album.artist.name);
                    if (artist_folder == null) {
                        Idle.add (
                            () => {
                                copy_finished ();
                                return false;
                            });
                        return null;
                    }

                    var album_folder = artist_folder.get_sub_folder (track.album.title);
                    if (album_folder == null) {
                        Idle.add (
                            () => {
                                copy_finished ();
                                return false;
                            });
                        return null;
                    }

                    stdout.printf ("%s\n", album_folder.file.get_uri () + "/" + Path.get_basename (track.uri));
                    var target = File.new_for_uri (album_folder.file.get_uri () + "/" + Path.get_basename (track.uri));

                    if (target.query_exists ()) {
                        Idle.add (
                            () => {
                                copy_finished ();
                                return false;
                            });
                        return null;
                    }

                    var source = File.new_for_uri (track.uri);
                    try {
                        source.copy (target, FileCopyFlags.NONE);
                        calculate_storage ();
                    } catch (Error err) {
                        warning (err.message);
                    }

                    target.dispose ();
                    source.dispose ();

                    Idle.add (
                        () => {
                            copy_finished ();
                            return false;
                        });
                    return null;
                });
        }

        private void create_music_folder (string uri) {
            var music_folder = new MobilePhoneMusicFolder (uri);
            music_folder.name = music_folder.file.get_parent ().get_basename ();

            if (has_folder (music_folder.name)) {
                return;
            }

            var empty_folder = new Granite.Widgets.SourceList.Item (no_items);
            music_folder.add (empty_folder);
            empty_folder.visible = music_folder.n_children < 2;

            music_folder.subfolder_deleted.connect (
                () => {
                    empty_folder.visible = music_folder.n_children < 2;
                    calculate_storage ();
                });

            music_folder.child_added.connect (
                (item) => {
                    empty_folder.visible = music_folder.n_children < 2;
                });

            music_folders.append (music_folder);
            music_folder_found (music_folder);
        }

        private bool has_folder (string name) {
            foreach (var music_folder in music_folders) {
                if (music_folder.name == name) {
                    return true;
                }
            }
            return false;
        }

        private void copy_cover (string folder, string cover) {
            var source = File.new_for_path (cover);
            if (source.query_exists ()) {
                var target = File.new_for_uri (folder);
                if (!target.query_exists ()) {
                    try {
                        source.copy (target, FileCopyFlags.NONE);
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
                target.dispose ();
            }
            source.dispose ();
        }
    }
}
