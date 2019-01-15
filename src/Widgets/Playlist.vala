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

namespace PlayMyMusic.Widgets {
    public class Playlist : Gtk.Grid {
        Services.LibraryManager library_manager;

        public Objects.Playlist playlist { get; private set; }
        public string title { get { return playlist.title; } }

        TrackStyle track_style;

        Gtk.Label playlist_title;
        Gtk.Label playlist_counter;
        Gtk.Label playlist_duration;
        Gtk.ListBox tracks;
        Gtk.Menu menu;
        Gtk.Popover rename_playlist_popover;
        Gtk.Entry rename_playlist_entry;

        bool only_mark = false;
        string string_counter = _("<small>%u Tracks</small>");
        string string_duration = "<small>%s</small>";

        public signal void track_selected ();

        construct {
            library_manager = Services.LibraryManager.instance;
            library_manager.player_state_changed.connect ((state) => {
                if (library_manager.player.play_mode != Services.PlayMode.PLAYLIST || library_manager.player.current_track.playlist.ID != playlist.ID) {
                    tracks.unselect_all ();
                }
            });
        }

        public Playlist (Objects.Playlist playlist, TrackStyle track_style = TrackStyle.PLAYLIST) {
            this.track_style = track_style;
            this.playlist = playlist;

            this.playlist.track_added.connect ((track) => {
                add_track (track);
                playlist_counter.label = string_counter.printf (playlist.tracks.length ());
                playlist_duration.label = string_duration.printf(Utils.get_formated_duration (playlist.duration));
            });
            this.playlist.track_removed.connect (() => {
                playlist_counter.label = string_counter.printf (playlist.tracks.length ());
                playlist_duration.label = string_duration.printf(Utils.get_formated_duration (playlist.duration));
            });
            this.playlist.updated.connect (() => {
                playlist_title.label = playlist.title;
                playlist_title.tooltip_text = playlist.title;
            });
            this.playlist.tracks_resorted.connect (() => {
                tracks.invalidate_sort ();
            });

            build_ui ();
            show_tracks ();
        }

        private void build_ui () {
            this.can_focus = false;
            this.width_request = 256;

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.spacing = 6;

            if (track_style == TrackStyle.PLAYLIST) {
                var event_box = new Gtk.EventBox ();
                event_box.button_press_event.connect (show_context_menu);

                playlist_title = new Gtk.Label (playlist.title);
                playlist_title.tooltip_text = playlist.title;
                playlist_title.halign = Gtk.Align.START;
                playlist_title.get_style_context ().add_class ("h3");
                playlist_title.margin_start = 12;
                playlist_title.margin_end = 12;
                playlist_title.ellipsize = Pango.EllipsizeMode.END;
                event_box.add (playlist_title);

                var details_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
                details_box.margin_start = 12;
                details_box.margin_end = 12;

                playlist_counter = new Gtk.Label (string_counter.printf (playlist.tracks.length ()));
                playlist_counter.halign = Gtk.Align.START;
                playlist_counter.use_markup = true;

                playlist_duration = new Gtk.Label (string_duration.printf(Utils.get_formated_duration (playlist.duration)));
                playlist_duration.use_markup = true;

                details_box.pack_start (playlist_counter, true, true, 0);
                details_box.pack_end (playlist_duration, false, false, 0);

                content.pack_start (event_box, false, false, 0);
                content.pack_start (details_box, false, false, 0);
                content.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false, 0);

                // POPOVER REGION
                rename_playlist_popover = new Gtk.Popover (playlist_title);
                rename_playlist_popover.position = Gtk.PositionType.BOTTOM;

                var rename_playlist = new Gtk.Grid ();
                rename_playlist.row_spacing = 6;
                rename_playlist.column_spacing = 12;
                rename_playlist.margin = 12;
                rename_playlist_popover.add (rename_playlist);

                rename_playlist_entry = new Gtk.Entry ();
                var rename_playlist_save = new Gtk.Button.with_label (_("Rename"));
                rename_playlist_save.get_style_context ().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);

                rename_playlist_entry.changed.connect (() => {
                    rename_playlist_save.sensitive = valid_new_playlist ();
                });
                rename_playlist_entry.key_press_event.connect ((key) => {
                    if ((key.keyval == Gdk.Key.Return || key.keyval == Gdk.Key.KP_Enter) && Gdk.ModifierType.CONTROL_MASK in key.state && valid_new_playlist ()) {
                        save_new_playlist ();
                    }
                    return false;
                });
                rename_playlist.attach (rename_playlist_entry, 0, 0);

                rename_playlist_save.clicked.connect (() => {
                    save_new_playlist ();
                });
                rename_playlist.attach (rename_playlist_save, 0, 1);

// CONTEXT MENU REGION
                menu = new Gtk.Menu ();
                var menu_rename_playlist = new Gtk.MenuItem.with_label (_("Rename Playlist"));
                menu_rename_playlist.activate.connect (() => {
                    rename_playlist_entry.text = playlist.title;
                    rename_playlist_popover.show_all ();
                    rename_playlist_save.sensitive = false;
                });
                menu.add (menu_rename_playlist);

                var menu_remove_playlist = new Gtk.MenuItem.with_label (_("Remove Playlist"));
                menu_remove_playlist.activate.connect (() => {
                    library_manager.remove_playlist (playlist);
                });
                menu.add (menu_remove_playlist);

                menu.add (new Gtk.SeparatorMenuItem ());

                var menu_export_playlist = new Gtk.MenuItem.with_label (_("Export Playlist…"));
                menu_export_playlist.activate.connect (() => {
                    library_manager.export_playlist (playlist);
                });
                menu.add (menu_export_playlist);

                menu.show_all ();
            }

// TRACKS REGION
            tracks = new Gtk.ListBox ();
            tracks.get_style_context ().add_class ("playlist-tracks");
            tracks.selected_rows_changed.connect (play_track);
            tracks.set_sort_func (tracks_sort_func);

            var tracks_scroll = new Gtk.ScrolledWindow (null, null);
            tracks_scroll.expand = true;

            tracks_scroll.add (tracks);

            content.pack_start (tracks_scroll, true, true, 0);

            this.add (content);
        }

        private void save_new_playlist () {
            this.playlist.title = rename_playlist_entry.text.strip ();
            library_manager.db_manager.update_playlist (this.playlist);
            rename_playlist_popover.hide ();
        }

        private bool valid_new_playlist () {
            string new_title = rename_playlist_entry.text.strip ();
            return new_title != "" && library_manager.db_manager.get_playlist_by_title (new_title) == null;
        }

        private void show_tracks () {
            tracks.unselect_all ();
            foreach (var track in playlist.tracks) {
                add_track (track);
            }
        }

        private void add_track (Objects.Track track) {
            var item = new Widgets.Track (track, track_style);
            tracks.add (item);
            item.show_all ();
        }

        private void play_track () {
            var selected_row = tracks.get_selected_row ();
            if (selected_row != null && !only_mark) {
                library_manager.play_track ((selected_row as Widgets.Track).track, Services.PlayMode.PLAYLIST);
                track_selected ();
            }
        }

        public void mark_playing_track (Objects.Track? track) {
            tracks.unselect_all ();
            if (track == null) {
                return;
            }
            foreach (var child in tracks.get_children ()) {
                if ((child as Widgets.Track).track.ID == track.ID) {
                    only_mark = true;
                    child.activate ();
                    only_mark = false;
                    return;
                }
            }
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                menu.popup_at_pointer (null);
                return true;
            } if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 1) {
                if (library_manager.player.play_mode != Services.PlayMode.PLAYLIST || library_manager.player.current_track.playlist.ID != playlist.ID) {
                    library_manager.play_track (playlist.get_first_track (), Services.PlayMode.PLAYLIST);
                }
            }
            return false;
        }

        private int tracks_sort_func (Gtk.ListBoxRow child1, Gtk.ListBoxRow child2) {
            var item1 = (Widgets.Track)child1;
            var item2 = (Widgets.Track)child2;
            if (item1 != null && item2 != null) {
                return item1.track.track - item2.track.track;
            }
            return 0;
        }
    }
}