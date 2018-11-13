/*-
 * Copyright (c) 2018-2018 Artem Anufrij <artem.anufrij@live.de>
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

namespace PlayMyMusic.Widgets.Views {
    public class Queue : Gtk.Grid {
        public signal void moved_to_playlist ();
        Services.LibraryManager library_manager;
        Services.Player player;

        public Objects.Playlist playlist { get; private set; }
        Widgets.Playlist queue;

        Gtk.Grid content;
        Gtk.Label message;

        construct {
            library_manager = Services.LibraryManager.instance;
            player = library_manager.player;
            player.state_changed.connect ((state) => {
                if (state == Gst.State.PLAYING
                    && player.play_mode == Services.PlayMode.PLAYLIST
                    && player.current_track.playlist.ID == playlist.ID) {
                    queue.mark_playing_track (player.current_track);
                }
            });
        }

        public Queue () {
            playlist = library_manager.db_manager.get_queue ();
            playlist.track_added.connect (() => {
                set_visibility ();
            });
            playlist.track_removed.connect (() => {
                set_visibility ();
            });
            playlist.started_init_playing.connect (() => {
                queue.mark_playing_track (playlist.get_first_track ());
            });
            build_ui ();
        }

        private void build_ui () {
            queue = new Widgets.Playlist (playlist, TrackStyle.QUEUE);
            queue.height_request = 320;

            var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            controls.halign = Gtk.Align.FILL;

            var button_trash_queue = new Gtk.Button.from_icon_name ("edit-delete-symbolic");
            button_trash_queue.tooltip_text = _("Clear the Queue");
            button_trash_queue.margin = 6;
            button_trash_queue.margin_end = 0;
            button_trash_queue.clicked.connect (() => {
                while (playlist.tracks.first () != null) {
                    library_manager.remove_track_from_playlist (playlist.tracks.first ().data);
                }
            });

            var button_create_playlist = new Gtk.Button.from_icon_name ("playlist-symbolic");
            button_create_playlist.tooltip_text = _("Create new Playlist based on this Queue");
            button_create_playlist.margin = 6;
            button_create_playlist.clicked.connect (() => {
                var new_playlist = library_manager.create_new_playlist ();
                var date_time = new GLib.DateTime.now_local ().format ("%Y-%m-%d %H:%M:%S");
                new_playlist.title = _ ("Queue from %s").printf (date_time);
                library_manager.db_manager.update_playlist (new_playlist);

                foreach (var track in playlist.tracks) {
                    library_manager.add_track_into_playlist (new_playlist, track.ID);
                }

                moved_to_playlist ();
            });

            var button_export_playlist = new Gtk.Button.from_icon_name ("document-export-symbolic");
            button_export_playlist.tooltip_text = _("Export Queue…");
            button_export_playlist.margin = 6;
            button_export_playlist.clicked.connect (() => {
                library_manager.export_playlist (playlist, "Queue");
            });

            controls.pack_start (button_export_playlist, false, false);

            controls.pack_end (button_create_playlist, false, false);
            controls.pack_end (button_trash_queue, false, false);

            content = new Gtk.Grid ();

            content.attach (queue, 0, 0);
            content.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 1);
            content.attach (controls, 0, 2);

            message = new Gtk.Label (_("Queue is empty"));
            message.get_style_context ().add_class ("h3");
            message.margin = 12;

            this.add (content);
            this.add (message);

            this.show_all ();
            set_visibility ();
        }

        private void set_visibility () {
            if (playlist.has_available_tracks ()) {
                content.show ();
                message.hide ();
            } else {
                content.hide ();
                message.show ();
            }
        }
    }
}