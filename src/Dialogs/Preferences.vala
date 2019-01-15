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

namespace PlayMyMusic.Dialogs {
    public class Preferences : Gtk.Dialog {
        PlayMyMusic.Settings settings;

        construct {
            settings = PlayMyMusic.Settings.get_default ();
        }

        public Preferences (Gtk.Window parent) {
            Object (
                transient_for: parent,
                deletable: false,
                resizable: false
                );
            build_ui ();

            this.response.connect ((source, response_id) => {
                switch (response_id) {
                    case Gtk.ResponseType.CLOSE:
                        destroy ();
                        break;
                }
            });
        }

        private void build_ui () {
            title = _("Preferences");
            var content = get_content_area () as Gtk.Box;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 12;
            grid.margin = 12;

            var play_in_background = new Gtk.Switch ();
            play_in_background.active = settings.play_in_background;
            play_in_background.notify["active"].connect (() => { settings.play_in_background = play_in_background.active; });

            var sync_files = new Gtk.Switch ();
            sync_files.active = settings.sync_files;
            sync_files.notify["active"].connect (() => { settings.sync_files = sync_files.active; });

            var load_content = new Gtk.Switch ();
            load_content.active = settings.load_content_from_musicbrainz;
            load_content.notify["active"].connect (() => { settings.load_content_from_musicbrainz = load_content.active; });

            var save_custom_covers = new Gtk.Switch ();
            save_custom_covers.active = settings.save_custom_covers;
            save_custom_covers.notify["active"].connect (() => { settings.save_custom_covers = save_custom_covers.active; });

            var save_id3_tags = new Gtk.Switch ();
            save_id3_tags.active = settings.save_id3_tags;
            save_id3_tags.notify["active"].connect (() => { settings.save_id3_tags = save_id3_tags.active; });

            var import_into_library = new Gtk.Switch ();
            import_into_library.active = settings.import_into_library;
            import_into_library.notify["active"].connect (() => { settings.import_into_library = import_into_library.active; });

            var remove_playlist_if_empty = new Gtk.Switch();
            remove_playlist_if_empty.active = settings.remove_playlist_if_empty;
            remove_playlist_if_empty.notify["active"].connect (() => { settings.remove_playlist_if_empty = remove_playlist_if_empty.active; });

            var remember_track_progress = new Gtk.Switch ();
            remember_track_progress.active = settings.remember_track_progress;
            remember_track_progress.notify["active"].connect (() => { settings.remember_track_progress = remember_track_progress.active; });

            grid.attach (label_generator (_ ("Play in background if closed")), 0, 0);
            grid.attach (play_in_background, 1, 0);
            grid.attach (label_generator (_ ("Sync files on start up")), 0, 1);
            grid.attach (sync_files, 1, 1);
            grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 2, 2, 1);
            grid.attach (label_generator (_ ("Load Content from MusicBrainz")), 0, 3);
            grid.attach (load_content, 1, 3);
            grid.attach (label_generator (_ ("Save custom Covers in Library folder")), 0, 4);
            grid.attach (save_custom_covers, 1, 4);
            grid.attach (label_generator (_ ("Save changes into ID3-Tag")), 0, 5);
            grid.attach (save_id3_tags, 1, 5);
            grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 6, 2, 1);
            grid.attach (label_generator (_ ("Copy Imported Files into Library")), 0, 7);
            grid.attach (import_into_library, 1, 7);
            grid.attach (label_generator (_ ("Remove Playlist if last Track was removed")), 0, 8);
            grid.attach (remove_playlist_if_empty, 1, 8);
            grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 9, 2, 1);
            grid.attach (label_generator (_ ("Remember Track progress")), 0, 10);
            grid.attach (remember_track_progress, 1, 10);

            content.pack_start (grid, false, false, 0);

            this.add_button (_ ("Close"), Gtk.ResponseType.CLOSE);
            this.show_all ();
        }

        private Gtk.Label label_generator (string content) {
            return new Gtk.Label (content) {
                halign = Gtk.Align.START,
                hexpand = true
            };
        }
    }
}
