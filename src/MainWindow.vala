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

namespace PlayMyMusic {

    public class MainWindow : Gtk.Window {

        PlayMyMusic.Services.LibraryManager library_manager;

        //CONTROLS
        Gtk.SearchEntry search_entry;
        Gtk.Spinner spinner;
        Gtk.FlowBox albums;

        Gtk.Button playButton;
        Widgets.AlbumView album_view;
        Widgets.TrackTimeLine timeline;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.tag_discover_started.connect (() => {
                spinner.active = true;
            });
            library_manager.tag_discover_finished.connect (() => {
                spinner.active = false;
            });
            library_manager.added_new_album.connect((album) => {
                var a = new Widgets.Album (album);
                a.show_all ();
                albums.add (a);
            });
            library_manager.player_state_changed.connect ((state) => {
                if (state == Gst.State.PLAYING) {
                    playButton.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                    playButton.tooltip_text = _("Pause");

                    album_view.mark_playing_track (library_manager.player.current_track);

                    timeline.set_playing_track (library_manager.player.current_track);
                } else {
                    if (state == Gst.State.PAUSED) {
                        timeline.pause_playing ();
                    } else {
                        timeline.stop_playing ();
                    }
                    if (state == Gst.State.NULL) {
                        album_view.mark_playing_track (null);
                    }

                    playButton.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                    playButton.tooltip_text = _("Play");
                }
            });
        }

        public MainWindow () {
            this.width_request = 960;
            this.height_request = 720;

            build_ui ();

            show_albums_from_database.begin ((obj, res) => {
                library_manager.scan_local_library (GLib.Environment.get_user_special_dir (GLib.UserDirectory.MUSIC));
            });
        }

        public void build_ui () {
            var headerbar = new Gtk.HeaderBar ();
            headerbar.title = _("Play My Music");
            headerbar.show_close_button = true;
            this.set_titlebar (headerbar);

            // PLAY BUTTONS
            var previousButton = new Gtk.Button.from_icon_name ("media-skip-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            previousButton.tooltip_text = _("Previous");
            previousButton.clicked.connect (() => {
                library_manager.player.prev ();
            });

            playButton = new Gtk.Button.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            playButton.tooltip_text = _("Play");
            playButton.clicked.connect (() => {
                library_manager.player.toggle_playing ();
            });

            var nextButton = new Gtk.Button.from_icon_name ("media-skip-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            nextButton.tooltip_text = _("Next");
            nextButton.clicked.connect (() => {
                library_manager.player.next ();
            });

            headerbar.pack_start (previousButton);
            headerbar.pack_start (playButton);
            headerbar.pack_start (nextButton);

            // TIMELINE
            timeline = new Widgets.TrackTimeLine ();
            headerbar.set_custom_title (timeline);

            // SETTINGS MENU
            var app_menu = new Gtk.MenuButton ();
            app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR));

            var settings_menu = new Gtk.Menu ();
            var menu_item_import = new Gtk.MenuItem.with_label (_("Import to Library…"));
            var menu_item_rescan = new Gtk.MenuItem.with_label (_("Rescan Library…"));
            menu_item_rescan.activate.connect (() => {
                album_view.hide ();
                foreach (var item in albums.get_children ()) {
                    albums.remove (item);
                }
                library_manager.rescan_library ();
            });

            settings_menu.append (menu_item_import);
            settings_menu.append (new Gtk.SeparatorMenuItem ());
            settings_menu.append (menu_item_rescan);
            settings_menu.show_all ();

            app_menu.popup = settings_menu;
            headerbar.pack_end (app_menu);

            // SEARCH ENTRY
            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Search Music");
            search_entry.margin_right = 5;
            search_entry.search_changed.connect (() => {
                albums.invalidate_filter ();
            });
            headerbar.pack_end (search_entry);

            // SPINNER
            spinner = new Gtk.Spinner ();
            headerbar.pack_end (spinner);

            albums = new Gtk.FlowBox ();
            albums.margin = 24;
            albums.homogeneous = true;
            albums.row_spacing = 12;
            albums.column_spacing = 24;
            albums.selection_mode = Gtk.SelectionMode.NONE;
            albums.max_children_per_line = 24;
            albums.valign = Gtk.Align.START;
            albums.set_sort_func (albums_sort_func);
            albums.set_filter_func (albums_filter_func);
            albums.child_activated.connect (show_album_viewer);
            var albums_scroll = new Gtk.ScrolledWindow (null, null);

            albums_scroll.add (albums);

            album_view = new Widgets.AlbumView ();

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.pack_start (albums_scroll, true, true, 0);
            box.pack_start (album_view, false, false, 0);

            this.add (box);

            this.show_all ();
            album_view.hide ();
            search_entry.grab_focus ();
        }

        private void show_album_viewer (Gtk.FlowBoxChild item) {
            var album = (item as Widgets.Album);
            album_view.show_album_viewer (album.album);
            if (library_manager.player.current_track != null) {
                album_view.mark_playing_track (library_manager.player.current_track);
            }
        }

        private async void show_albums_from_database () {
            foreach (var artist in library_manager.artists) {
                foreach (var album in artist.albums) {
                    var a = new Widgets.Album (album);
                    a.show_all ();
                    albums.add (a);
                }
            }
        }

        private bool albums_filter_func (Gtk.FlowBoxChild child) {
            var query = search_entry.text.strip ().down ();
            if (query.length == 0) {
                return true;
            }

            string[] filter_elements = query.split (" ");
            var album = (child as Widgets.Album).album;

            foreach (string filter_element in filter_elements) {
                if (!album.title.down ().contains (filter_element) && !album.artist.name.down ().contains (filter_element)) {
                    bool track_title = false;
                    foreach (var track in album.tracks) {
                        if (track.title.down ().contains (filter_element)) {
                            track_title = true;
                        }
                    }
                    if (track_title) {
                        continue;
                    }
                    return false;
                }
            }
            return true;
        }

        private int albums_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = (Widgets.Album)child1;
            var item2 = (Widgets.Album)child2;
            if (item1 != null && item2 != null) {
                if (item1.album.artist.name == item2.album.artist.name) {
                    if (item1.album.year > 0 && item2.album.year > 0) {
                        return item1.album.year - item2.album.year;
                    }
                    return item1.title.collate (item2.title);
                }
                return item1.album.artist.name.collate (item2.album.artist.name);
            }
            return 0;
        }
    }
}
