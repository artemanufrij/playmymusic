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

namespace PlayMyMusic {
    public class MainWindow : Gtk.Window {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Settings settings;

        public signal void ctrl_press ();
        public signal void ctrl_release ();

        //CONTROLS
        Gtk.HeaderBar headerbar;
        Gtk.SearchEntry search_entry;
        Gtk.Spinner spinner;
        Gtk.Button play_button;
        Gtk.Button next_button;
        Gtk.Button previous_button;
        Gtk.MenuItem menu_item_resync;
        Gtk.MenuItem menu_item_reset;
        Gtk.CheckMenuItem menu_sort_1;
        Gtk.CheckMenuItem menu_sort_2;
        Gtk.CheckMenuItem menu_sort_3;
        Gtk.Image icon_play;
        Gtk.Image icon_pause;
        public Gtk.Stack content;

        Gtk.Widget audio_cd_widget;
        Gtk.Image artist_button;
        Gtk.Image playlist_button;
        Gtk.Image tracks_button;

        Gtk.Image icon_repeat_one;
        Gtk.Image icon_repeat_all;
        Gtk.Image icon_repeat_off;
        Gtk.Image icon_shuffle_on;
        Gtk.Image icon_shuffle_off;
        Gtk.Button repeat_button;
        Gtk.Button shuffle_button;
        Gtk.Box mode_buttons;

        Granite.Widgets.ModeButton view_mode;
        Granite.Widgets.Toast toast;

        Widgets.Views.AlbumsView albums_view;
        Widgets.Views.ArtistsView artists_view;
        Widgets.Views.RadiosView radios_view;
        Widgets.Views.PlaylistsView playlists_view;
        Widgets.Views.AudioCDView audio_cd_view;
        Widgets.Views.TracksView tracks_view;
        public Widgets.Views.MobilePhone mobile_phone_view { get; private set; }

        Widgets.TrackTimeLine timeline;

        Notification desktop_notification;

        bool send_desktop_notification = true;
        uint adjust_timer = 0;

        public bool ctrl_pressed { get; private set; default = false; }

        const Gtk.TargetEntry[] targets = {
            {"text/uri-list", 0, 0}
        };

        construct {
            settings = PlayMyMusic.Settings.get_default ();
            settings.notify["use-dark-theme"].connect (() => {
                Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = settings.use_dark_theme;
            });
            settings.notify["repeat-mode"].connect (() => {
                set_repeat_symbol ();
            });
            settings.notify["shuffle-mode"].connect (() => {
                set_shuffle_symbol ();
            });
            settings.notify["sort-mode-album-view"].connect (() => {
                set_sort_mode_album_view ();
            });
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.sync_started.connect (() => {
                Idle.add (() => {
                    headerbar.pack_end (spinner);
                    spinner.active = true;
                    spinner.show ();
                    menu_item_resync.sensitive = false;
                    menu_item_reset.sensitive = false;
                    return false;
                });
            });
            library_manager.sync_finished.connect (() => {
                Idle.add (() => {
                    spinner.active = false;
                    headerbar.remove (spinner);
                    menu_item_resync.sensitive = true;
                    menu_item_reset.sensitive = true;
                    return false;
                });
            });
            library_manager.added_new_artist.connect (() => {
                if (!artist_button.sensitive) {
                    artist_button.sensitive = true;
                    playlist_button.sensitive = true;
                    tracks_button.sensitive = true;
                }
            });
            library_manager.player_state_changed.connect ((state) => {
                play_button.sensitive = true;
                if (state == Gst.State.PLAYING) {
                    play_button.image = icon_pause;
                    play_button.tooltip_text = _ ("Pause");
                    if (library_manager.player.current_track != null) {
                        timeline.set_playing_track (library_manager.player.current_track);
                        headerbar.set_custom_title (timeline);
                        send_notification (library_manager.player.current_track);
                        previous_button.sensitive = true;
                        next_button.sensitive = true;
                    } else if (library_manager.player.current_file != null) {
                        timeline.set_playing_file (library_manager.player.current_file);
                        headerbar.set_custom_title (timeline);
                        previous_button.sensitive = false;
                        next_button.sensitive = false;
                    } else if (library_manager.player.current_radio != null) {
                        headerbar.title = library_manager.player.current_radio.title;
                        previous_button.sensitive = false;
                        next_button.sensitive = false;
                    }
                } else {
                    if (state != Gst.State.PAUSED) {
                        headerbar.set_custom_title (null);
                        headerbar.title = _ ("Melody");
                    } else {
                        timeline.set_playing_track (library_manager.player.current_track);
                        headerbar.set_custom_title (timeline);
                    }
                    play_button.image = icon_play;
                    play_button.tooltip_text = _ ("Play");
                }
            });
            library_manager.audio_cd_connected.connect ((audio_cd) => {
                audio_cd_view.show_audio_cd (audio_cd);
                audio_cd_widget.show ();
                view_mode.set_active (5);
            });
            library_manager.audio_cd_disconnected.connect ((volume) => {
                if (audio_cd_view.current_audio_cd != null && audio_cd_view.current_audio_cd.volume == volume) {
                    if (library_manager.player.play_mode == PlayMyMusic.Services.PlayMode.AUDIO_CD) {
                        library_manager.player.reset_playing ();
                    }
                    audio_cd_view.reset ();
                    audio_cd_widget.hide ();
                    if (view_mode.selected == 5) {
                        show_playing_view ();
                    }
                }
            });
            library_manager.mobile_phone_connected.connect ((volume) => {
                adjust_background_images ();
            });
            library_manager.mobile_phone_disconnected.connect ((volume) => {
                adjust_background_images ();
            });
            library_manager.artist_removed.connect (() => {
                if (library_manager.artists.length () == 0) {
                    reset_all_views ();
                }
            });
            library_manager.cache_loaded.connect (() => {
                Idle.add (()=> {
                    load_content_from_database.begin ((obj, res) => {
                        if (settings.sync_files) {
                            library_manager.sync_library_content.begin ();
                        }
                        albums_view.activate_by_id (settings.last_album_id);
                        load_last_played_track ();
                        content.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
                    });
                    return false;
                });
            });

            Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.LINK);

            this.drag_motion.connect ((context, x, y, time) => {
                Gtk.drag_unhighlight (this);
                return true;
            });
            this.drag_data_received.connect ((drag_context, x, y, data, info, time) => {
                foreach (var uri in data.get_uris ()) {
                    var file = File.new_for_uri (uri);
                    try {
                        var file_info = file.query_info ("standard::*", GLib.FileQueryInfoFlags.NONE);

                        if (file_info.get_file_type () == FileType.DIRECTORY) {
                            library_manager.scan_local_library_for_new_files (file.get_uri ());
                            continue;
                        }

                        string mime_type = file_info.get_content_type ();
                        if (Utils.is_audio_file (mime_type)) {
                            library_manager.found_local_music_file (file.get_uri ());
                        }
                    } catch (Error err) {
                        warning (err.message);
                    }
                    file.dispose ();
                }
            });
            this.configure_event.connect ((event) => {
                artists_view.load_background ();
                audio_cd_view.load_background ();
                tracks_view.load_background ();

                adjust_background_images ();
                return false;
            });
            this.delete_event.connect (() => {
                save_settings ();
                if (settings.play_in_background && library_manager.player.get_state () == Gst.State.PLAYING) {
                    this.hide_on_delete ();
                    return true;
                }
                return false;
            });
            this.destroy.connect (() => {
                library_manager.player.stop ();
            });
            this.key_press_event.connect ((event) => {
                if (event.keyval == 65507) {
                    ctrl_pressed = true;
                    ctrl_press ();
                }
                return false;
            });
            this.key_release_event.connect ((event) => {
                if (event.keyval == 65507) {
                    ctrl_pressed = false;
                    ctrl_release ();
                }
                return true;
            });
        }

        public MainWindow () {
            load_settings ();
            build_ui ();

            library_manager.load_database_cache.begin ();
            Utils.set_custom_css_style (this.get_screen ());
        }

        public void build_ui () {
            // CONTENT
            content = new Gtk.Stack ();

            headerbar = new Gtk.HeaderBar ();
            headerbar.title = _ ("Melody");
            headerbar.show_close_button = true;
            headerbar.get_style_context ().add_class ("default-decoration");
            this.set_titlebar (headerbar);

            header_build_play_buttons ();

            header_build_playmode_buttons ();

            header_build_views_buttons ();

            header_build_timeline ();

            header_build_app_menu ();

            header_build_style_switcher ();

            header_build_search_entry ();

            header_build_playlist_control ();

            // SPINNER
            spinner = new Gtk.Spinner ();

            // TOAST
            toast = new Granite.Widgets.Toast ("");

            // VIEWES
            mobile_phone_view = new Widgets.Views.MobilePhone ();

            albums_view = new Widgets.Views.AlbumsView (this);
            albums_view.album_selected.connect (() => {
                previous_button.sensitive = true;
                play_button.sensitive = true;
                next_button.sensitive = true;
            });

            artists_view = new Widgets.Views.ArtistsView (this);
            artists_view.artist_selected.connect (() => {
                previous_button.sensitive = true;
                play_button.sensitive = true;
                next_button.sensitive = true;
            });

            playlists_view = new Widgets.Views.PlaylistsView ();

            radios_view = new Widgets.Views.RadiosView ();

            audio_cd_view = new Widgets.Views.AudioCDView ();

            tracks_view = new Widgets.Views.TracksView ();
            tracks_view.app_message.connect ((message) => {
                toast.title = message;
                toast.send_notification ();
            });

            var splash_message = new Granite.Widgets.AlertView (_ ("Loading…"), _ ("Reading out database content"), "audio-x-generic-symbolic");

            content.add_named (splash_message, "splash");
            content.add_named (albums_view, "albums");
            content.add_named (artists_view, "artists");
            content.add_named (tracks_view, "tracks");
            content.add_named (playlists_view, "playlists");
            content.add_named (radios_view, "radios");
            content.add_named (audio_cd_view, "audiocd");

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.pack_start (mobile_phone_view, false, false, 0);
            box.pack_end (content, true, true, 0);

            var overlay = new Gtk.Overlay ();
            overlay.add_overlay (box);
            overlay.add_overlay (toast);

            this.add (overlay);
            this.show_all ();

            audio_cd_widget.hide ();
            mobile_phone_view.reveal_child = false;
            mobile_phone_view.hide_spinner ();

            library_manager.device_manager.init ();

            radios_view.unselect_all ();
            search_entry.grab_focus ();

            content.visible_child_name = "splash";
        }

        private void header_build_play_buttons () {
            icon_play = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            icon_pause = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);

            previous_button = new Gtk.Button.from_icon_name ("media-skip-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            previous_button.valign = Gtk.Align.CENTER;
            previous_button.can_focus = false;
            previous_button.tooltip_text = _ ("Previous");
            previous_button.sensitive = false;
            previous_button.clicked.connect (() => {
                library_manager.player.prev ();
            });

            play_button = new Gtk.Button ();
            play_button.can_focus = false;
            play_button.valign = Gtk.Align.CENTER;
            play_button.image = icon_play;
            play_button.tooltip_text = _ ("Play");
            play_button.sensitive = false;
            play_button.clicked.connect (() => {
                toggle_playing ();
            });

            next_button = new Gtk.Button.from_icon_name ("media-skip-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            next_button.valign = Gtk.Align.CENTER;
            next_button.can_focus = false;
            next_button.tooltip_text = _ ("Next");
            next_button.sensitive = false;
            next_button.clicked.connect (() => {
                library_manager.player.next ();
            });

            headerbar.pack_start (previous_button);
            headerbar.pack_start (play_button);
            headerbar.pack_start (next_button);
        }

        private void header_build_playmode_buttons () {
            icon_shuffle_on = new Gtk.Image.from_icon_name ("media-playlist-shuffle-symbolic", Gtk.IconSize.BUTTON);
            icon_shuffle_off = new Gtk.Image.from_icon_name ("media-playlist-no-shuffle-symbolic", Gtk.IconSize.BUTTON);

            shuffle_button = new Gtk.Button ();
            if (settings.shuffle_mode) {
                shuffle_button.set_image (icon_shuffle_on);
                shuffle_button.tooltip_text = _ ("Shuffle On");
            } else {
                shuffle_button.set_image (icon_shuffle_off);
                shuffle_button.tooltip_text = _ ("Shuffle Off");
            }
            shuffle_button.can_focus = false;
            shuffle_button.clicked.connect (() => {
                settings.shuffle_mode = !settings.shuffle_mode;
            });

            icon_repeat_one = new Gtk.Image.from_icon_name ("media-playlist-repeat-one-symbolic", Gtk.IconSize.BUTTON);
            icon_repeat_all = new Gtk.Image.from_icon_name ("media-playlist-repeat-symbolic", Gtk.IconSize.BUTTON);
            icon_repeat_off = new Gtk.Image.from_icon_name ("media-playlist-no-repeat-symbolic", Gtk.IconSize.BUTTON);

            repeat_button = new Gtk.Button ();
            set_repeat_symbol ();
            repeat_button.can_focus = false;
            repeat_button.clicked.connect (() => {
                settings.switch_repeat_mode ();
            });

            mode_buttons = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            mode_buttons.pack_start (shuffle_button);
            mode_buttons.pack_start (repeat_button);

            headerbar.pack_start (mode_buttons);
        }

        private void header_build_views_buttons () {
            bool has_artists = library_manager.artists.length () > 0;

            view_mode = new Granite.Widgets.ModeButton ();
            view_mode.homogeneous = false;
            view_mode.valign = Gtk.Align.CENTER;
            view_mode.margin_start = 12;

            var album_button = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.BUTTON);
            album_button.tooltip_text = _ ("Albums");
            view_mode.append (album_button);

            artist_button = new Gtk.Image.from_icon_name ("avatar-default-symbolic", Gtk.IconSize.BUTTON);
            artist_button.tooltip_text = _ ("Artists");
            view_mode.append (artist_button);
            artist_button.sensitive = has_artists;

            tracks_button = new Gtk.Image.from_icon_name ("view-list-symbolic", Gtk.IconSize.BUTTON);
            tracks_button.tooltip_text = _ ("Tracks");
            view_mode.append (tracks_button);
            tracks_button.sensitive = has_artists;

            playlist_button = new Gtk.Image.from_icon_name ("playlist-symbolic", Gtk.IconSize.BUTTON);
            playlist_button.tooltip_text = _ ("Playlists");
            view_mode.append (playlist_button);
            playlist_button.sensitive = has_artists;

            var radio_button = new Gtk.Image.from_icon_name ("internet-radio-symbolic", Gtk.IconSize.BUTTON);
            radio_button.tooltip_text = _ ("Radio Stations");
            view_mode.append (radio_button);
            var wid = view_mode.get_children ().last ().data;
            wid.margin_start = 4;
            wid.get_style_context ().add_class ("mode_button_split");

            var audio_cd_button = new Gtk.Image.from_icon_name ("media-optical-cd-audio-symbolic", Gtk.IconSize.BUTTON);
            audio_cd_button.tooltip_text = _ ("Audio CD");
            view_mode.append (audio_cd_button);
            audio_cd_widget = view_mode.get_children ().last ().data;

            view_mode.mode_changed.connect (() => {
                switch (view_mode.selected) {
                    case 1 :
                        show_artists ();
                        break;
                    case 2 :
                        show_tracks ();
                        break;
                    case 3 :
                        show_playlists ();
                        break;
                    case 4 :
                        show_radiostations ();
                        break;
                    case 5 :
                        show_audio_cd ();
                        break;
                    default :
                        show_albums ();
                        break;
                }
            });
            headerbar.pack_start (view_mode);
        }

        private void header_build_timeline () {
            timeline = new Widgets.TrackTimeLine ();
            timeline.goto_current_track.connect ((track) => {
                if (track != null) {
                    switch (library_manager.player.play_mode) {
                    case PlayMyMusic.Services.PlayMode.ALBUM :
                        view_mode.set_active (0);
                        albums_view.activate_by_track (track);
                        break;
                    case PlayMyMusic.Services.PlayMode.ARTIST :
                        view_mode.set_active (1);
                        artists_view.activate_by_track (track);
                        break;
                    case PlayMyMusic.Services.PlayMode.TRACKS :
                        view_mode.set_active (2);
                        tracks_view.activate_by_track (track);
                        break;
                    case PlayMyMusic.Services.PlayMode.PLAYLIST :
                        view_mode.set_active (3);
                        playlists_view.activate_by_track (track);
                        break;
                    case PlayMyMusic.Services.PlayMode.AUDIO_CD :
                        view_mode.set_active (4);
                        break;
                    }
                }
            });
        }

        private void header_build_app_menu () {
            var app_menu = new Gtk.MenuButton ();
            app_menu.valign = Gtk.Align.CENTER;
            app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR));

            var settings_menu = new Gtk.Menu ();

            var menu_item_library = new Gtk.MenuItem.with_label (_ ("Change Music Folder…"));
            menu_item_library.activate.connect (() => {
                var folder = library_manager.choose_folder ();
                if (folder != null) {
                    settings.library_location = folder;
                    library_manager.scan_local_library_for_new_files (folder);
                }
            });

            var menu_item_import = new Gtk.MenuItem.with_label (_ ("Import Music…"));
            menu_item_import.activate.connect (() => {
                var folder = library_manager.choose_folder ();
                if (folder != null) {
                    library_manager.scan_local_library_for_new_files (folder);
                }
            });

            menu_item_reset = new Gtk.MenuItem.with_label (_ ("Reset all views"));
            menu_item_reset.activate.connect (() => {
                reset_all_views ();
                library_manager.reset_library ();
            });

            menu_item_resync = new Gtk.MenuItem.with_label (_ ("Resync Library"));
            menu_item_resync.activate.connect (() => {
                library_manager.sync_library_content.begin ();
            });

            var menu_sort = new Gtk.MenuItem.with_label (_("Sorting"));
            var menu_sort_sub = new Gtk.Menu ();
            menu_sort.set_submenu (menu_sort_sub);
            menu_sort_1 = new Gtk.CheckMenuItem.with_label (_("Artist - Year - Album"));
            menu_sort_2 = new Gtk.CheckMenuItem.with_label (_("Album - Artist"));
            menu_sort_3 = new Gtk.CheckMenuItem.with_label (_("Artist - Album"));
            set_sort_mode_album_view ();

            menu_sort_1.toggled.connect (() => {
                if (menu_sort_1.active) {
                    settings.sort_mode_album_view = 1;
                }
            });
            menu_sort_2.toggled.connect (() => {
                if (menu_sort_2.active) {
                    settings.sort_mode_album_view = 2;
                }
            });
            menu_sort_3.toggled.connect (() => {
                if (menu_sort_3.active) {
                    settings.sort_mode_album_view = 3;
                }
            });

            menu_sort_sub.add (menu_sort_1);
            menu_sort_sub.add (menu_sort_2);
            menu_sort_sub.add (menu_sort_3);

            var menu_item_preferences = new Gtk.MenuItem.with_label (_ ("Preferences"));
            menu_item_preferences.activate.connect (() => {
                var preferences = new Dialogs.Preferences (this);
                preferences.run ();
            });

            settings_menu.append (menu_item_library);
            settings_menu.append (menu_item_import);
            settings_menu.append (new Gtk.SeparatorMenuItem ());
            settings_menu.append (menu_item_resync);
            settings_menu.append (menu_item_reset);
            settings_menu.append (new Gtk.SeparatorMenuItem ());
            settings_menu.append (menu_sort);
            settings_menu.append (new Gtk.SeparatorMenuItem ());
            settings_menu.append (menu_item_preferences);
            settings_menu.show_all ();

            app_menu.clicked.connect (() => {
                if (content.visible_child_name == "albums") {
                    menu_sort.show ();
                } else {
                    menu_sort.hide ();
                }
            });
            app_menu.popup = settings_menu;
            headerbar.pack_end (app_menu);
        }

        private void header_build_style_switcher () {
            if (PlayMyMusicApp.instance.get_os_info ("PRETTY_NAME").index_of ("elementary") == -1) {
                return;
            }

            var mode_switch = new Granite.ModeSwitch.from_icon_name ("display-brightness-symbolic", "weather-clear-night-symbolic");
            mode_switch.valign = Gtk.Align.CENTER;
            mode_switch.active = settings.use_dark_theme;
            mode_switch.notify["active"].connect (() => {
                settings.use_dark_theme = mode_switch.active;
            });
            headerbar.pack_end (mode_switch);
        }

        private void header_build_search_entry () {
            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _ ("Search Music");
            search_entry.margin_end = 5;
            search_entry.valign = Gtk.Align.CENTER;
            search_entry.search_changed.connect (() => {
                switch (view_mode.selected) {
                    case 1 :
                        artists_view.filter = search_entry.text;
                        break;
                    case 2 :
                        tracks_view.filter = search_entry.text;
                        break;
                    case 3 :
                        playlists_view.filter = search_entry.text;
                        break;
                    case 4 :
                        radios_view.filter = search_entry.text;
                        break;
                    case 5 :
                        audio_cd_view.filter = search_entry.text;
                        break;
                    default :
                        albums_view.filter = search_entry.text;
                        break;
                }
            });
            headerbar.pack_end (search_entry);
        }

        private void header_build_playlist_control () {
            var queue_popover = new Gtk.Popover (null);
            var queue_button = new Gtk.Button.from_icon_name ("playlist-queue-symbolic");
            var queue = new Widgets.Views.Queue ();
            queue.playlist.track_added.connect (() => {
                if (queue_button.opacity != 1) {
                    queue_button.opacity = 1;
                }
            });
            queue.playlist.track_removed.connect (() => {
                if (!queue.playlist.has_tracks ()) {
                    queue_button.opacity = 0.5;
                }
            });
            queue.moved_to_playlist.connect (() => {
                show_playlists ();
            });
            queue_popover.add (queue);

            queue_button.valign = Gtk.Align.CENTER;
            queue_button.opacity = queue.playlist.has_tracks () ? 1 : 0.5;
            queue_button.tooltip_text = _("Queue");

            queue_button.clicked.connect (() => {
                //WORKAROUND: Don't know how to avoid focus grabing of 'queue' object
                queue.sensitive = false;
                queue_popover.show ();
                queue.sensitive = true;
            });
            queue_popover.set_relative_to (queue_button);

            headerbar.pack_end (queue_button);
        }

        public override bool key_press_event (Gdk.EventKey e) {
            if (!search_entry.is_focus && e.str.strip ().length > 0) {
                search_entry.grab_focus ();
            } else if (!search_entry.is_focus && e.keyval == Gdk.Key.space) {
                toggle_playing ();
            }
            return base.key_press_event (e);
        }

        public void show_view_index (int index) {
            // AUDIO CD VIEW
            if (index == 5 && !audio_cd_widget.visible) {
                return;
            }
            view_mode.selected = index;
        }

        private void show_albums () {
            mode_buttons.opacity = 1;
            if (mobile_phone_view.current_mobile_phone != null && !mobile_phone_view.stay_closed) {
                mobile_phone_view.reveal_child = true;
            }
            content.visible_child_name = "albums";
            search_entry.text = albums_view.filter;
        }

        private void show_artists () {
            mode_buttons.opacity = 1;
            if (mobile_phone_view.current_mobile_phone != null && !mobile_phone_view.stay_closed) {
                mobile_phone_view.reveal_child = true;
            }
            if (artist_button.sensitive) {
                content.visible_child_name = "artists";
                search_entry.text = artists_view.filter;
                adjust_background_images ();
            } else {
                view_mode.set_active (0);
            }
        }

        private void show_tracks () {
            mode_buttons.opacity = 1;
            mobile_phone_view.reveal_child = false;
            if (tracks_button.sensitive) {
                content.visible_child_name = "tracks";
                search_entry.text = tracks_view.filter;
                adjust_background_images ();
            } else {
                view_mode.set_active (0);
            }
        }

        private void show_playlists () {
            mode_buttons.opacity = 1;
            mobile_phone_view.reveal_child = false;
            if (playlist_button.sensitive) {
                if (library_manager.player.play_mode != PlayMyMusic.Services.PlayMode.PLAYLIST || playlists_view.filter != "") {
                    search_entry.grab_focus ();
                }
                content.visible_child_name = "playlists";
                search_entry.text = playlists_view.filter;
            } else {
                view_mode.set_active (0);
            }
        }

        private void show_radiostations () {
            mode_buttons.opacity = 0;
            mobile_phone_view.reveal_child = false;
            if (library_manager.player.current_radio == null || radios_view.filter != "") {
                search_entry.grab_focus ();
            }
            content.visible_child_name = "radios";
            search_entry.text = radios_view.filter;
        }

        private void show_audio_cd () {
            mode_buttons.opacity = 1;
            mobile_phone_view.reveal_child = false;
            if (library_manager.player.play_mode != PlayMyMusic.Services.PlayMode.AUDIO_CD || audio_cd_view.filter != "") {
                search_entry.grab_focus ();
            }
            previous_button.sensitive = true;
            play_button.sensitive = true;
            next_button.sensitive = true;
            content.visible_child_name = "audiocd";
            search_entry.text = audio_cd_view.filter;
            adjust_background_images ();
        }

        private void send_notification (Objects.Track track) {
            if (!is_active && send_desktop_notification) {
                if (desktop_notification == null) {
                    desktop_notification = new Notification ("");
                }
                desktop_notification.set_title (track.title);
                if (library_manager.player.play_mode == PlayMyMusic.Services.PlayMode.AUDIO_CD) {
                    desktop_notification.set_body (_ ("<b>%s</b> by <b>%s</b>").printf (track.audio_cd.title, track.audio_cd.artist));
                    try {
                        var icon = GLib.Icon.new_for_string (track.audio_cd.cover_path);
                        desktop_notification.set_icon (icon);
                    } catch (Error err) {
                        warning (err.message);
                    }
                } else {
                    desktop_notification.set_body (_ ("<b>%s</b> by <b>%s</b>").printf (track.album.title, track.album.artist.name));
                    try {
                        var icon = GLib.Icon.new_for_string (track.album.cover_path);
                        desktop_notification.set_icon (icon);
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
                this.application.send_notification (PlayMyMusicApp.instance.application_id, desktop_notification);
            }
        }

        private void adjust_background_images () {
            if (adjust_timer != 0) {
                Source.remove (adjust_timer);
                adjust_timer = 0;
            }
            adjust_timer = GLib.Timeout.add (250, () => {
                artists_view.load_background ();
                audio_cd_view.load_background ();
                tracks_view.load_background ();
                Source.remove (adjust_timer);
                adjust_timer = 0;
                return false;
            });
        }

        private async void load_content_from_database () {
            foreach (var artist in library_manager.artists) {
                artists_view.add_artist (artist);
                foreach (var album in artist.albums) {
                    albums_view.add_album (album);
                    foreach (var track in album.tracks) {
                        tracks_view.add_track (track);
                    }
                }
            }
            tracks_view.init_end ();
            albums_view.do_sort (true);
        }

        private void reset_all_views () {
            search_entry.text = "";
            settings.last_artist_id = 0;
            settings.last_album_id = 0;
            view_mode.set_active (0);
            artist_button.sensitive = false;
            playlist_button.sensitive = false;
            tracks_button.sensitive = false;
            albums_view.reset ();
            artists_view.reset ();
            radios_view.reset ();
            tracks_view.reset ();
        }

        public void toggle_playing () {
            send_desktop_notification = false;
            if (library_manager.player.current_track != null || library_manager.player.current_radio != null || library_manager.player.current_file != null) {
                library_manager.player.toggle_playing ();
            } else {
                switch (view_mode.selected) {
                    case 0 :
                        albums_view.play_selected_album ();
                        break;
                    case 1 :
                        artists_view.play_selected_artist ();
                        break;
                    case 4 :
                        audio_cd_view.play_audio_cd ();
                        break;
                }
            }
            send_desktop_notification = true;
        }

        private void show_playing_view () {
            var current_state = library_manager.player.get_state ();
            if (current_state == Gst.State.PLAYING || current_state == Gst.State.PAUSED) {
                switch (library_manager.player.play_mode) {
                    case PlayMyMusic.Services.PlayMode.ALBUM :
                        view_mode.set_active (0);
                        break;
                    case PlayMyMusic.Services.PlayMode.ARTIST :
                        view_mode.set_active (1);
                        break;
                    case PlayMyMusic.Services.PlayMode.PLAYLIST :
                        view_mode.set_active (3);
                        break;
                    case PlayMyMusic.Services.PlayMode.RADIO :
                        view_mode.set_active (4);
                        break;
                }
            } else {
                view_mode.set_active (0);
            }
        }

        public void next () {
            send_desktop_notification = false;
            library_manager.player.next ();
            send_desktop_notification = true;
        }

        public void prev () {
            send_desktop_notification = false;
            library_manager.player.prev ();
            send_desktop_notification = true;
        }

        public void open_file (File file) {
            if (file.get_uri ().has_prefix ("cdda://")) {
                audio_cd_view.open_file (file);
            } else if (!albums_view.open_file (Uri.unescape_string (file.get_uri ()))) {
                library_manager.player.set_file (file);
            }
        }

        private void load_last_played_track () {
            send_desktop_notification = false;
            switch (settings.track_source) {
                case "albums" :
                    view_mode.set_active (0);
                    var album = albums_view.activate_by_id (settings.last_album_id);
                    if (album != null) {
                        var track = album.get_track_by_id (settings.last_track_id);
                        if (track != null) {
                            library_manager.player.load_track (track, PlayMyMusic.Services.PlayMode.ALBUM, settings.track_progress);
                        }
                    }
                    break;
                case "artists" :
                    view_mode.set_active (1);
                    var artist = artists_view.activate_by_id (settings.last_artist_id);
                    if (artist != null) {
                        var track = artist.get_track_by_id (settings.last_track_id);
                        if (track != null) {
                            library_manager.player.load_track (track, PlayMyMusic.Services.PlayMode.ARTIST, settings.track_progress);
                        }
                    }
                    break;
                case "tracks" :
                    view_mode.set_active (2);
                    break;
                case "playlists" :
                    if (settings.last_playlist_id != library_manager.db_manager.get_queue ().ID) {
                        view_mode.set_active (3);
                    } else {
                        view_mode.set_active (0);
                    }
                    var playlist = playlists_view.activate_by_id (settings.last_playlist_id);
                    if (playlist != null) {
                        var track = playlist.get_track_by_id (settings.last_track_id);
                        if (track != null) {
                            library_manager.player.load_track (track, PlayMyMusic.Services.PlayMode.PLAYLIST, settings.track_progress);
                        }
                    }
                    break;
                default :
                    if (settings.view_index != 5 || audio_cd_view.current_audio_cd != null) {
                        view_mode.set_active (settings.view_index);
                    } else {
                        view_mode.set_active (0);
                    }
                    break;
            }
            send_desktop_notification = true;
        }

        public void search_reset () {
            if (this.search_entry.text != "") {
                this.search_entry.text = "";
            } else if (view_mode.selected == 0) {
                albums_view.unselect_all ();
            } else if (view_mode.selected == 1) {
                artists_view.unselect_all ();
            }
        }

        private void set_repeat_symbol () {
            switch (settings.repeat_mode) {
            case RepeatMode.ALL :
                repeat_button.set_image (icon_repeat_all);
                repeat_button.tooltip_text = _ ("Repeat All");
                break;
            case RepeatMode.ONE :
                repeat_button.set_image (icon_repeat_one);
                repeat_button.tooltip_text = _ ("Repeat One");
                break;
            default :
                repeat_button.set_image (icon_repeat_off);
                repeat_button.tooltip_text = _ ("Repeat Off");
                break;
            }
            repeat_button.show_all ();
        }

        private void set_shuffle_symbol () {
            if (settings.shuffle_mode) {
                shuffle_button.set_image (icon_shuffle_on);
                shuffle_button.tooltip_text = _ ("Shuffle On");
            } else {
                shuffle_button.set_image (icon_shuffle_off);
                shuffle_button.tooltip_text = _ ("Shuffle Off");
            }
            repeat_button.show_all ();
        }

        private void set_sort_mode_album_view () {
            menu_sort_1.active = false;
            menu_sort_2.active = false;
            menu_sort_3.active = false;
            switch (settings.sort_mode_album_view) {
                case 2:
                    menu_sort_2.active = true;
                    break;
                case 3:
                    menu_sort_3.active = true;
                    break;
                default:
                    menu_sort_1.active = true;
                    break;
            }
        }

        private void load_settings () {
            if (settings.window_maximized) {
                this.maximize ();
                this.set_default_size (1024, 720);
            } else {
                this.set_default_size (settings.window_width, settings.window_height);
            }

            if (settings.window_x < 0 || settings.window_y < 0 ) {
                this.window_position = Gtk.WindowPosition.CENTER;
            } else {
                this.move (settings.window_x, settings.window_y);
            }

            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = settings.use_dark_theme;
        }

        private void save_settings () {
            settings.window_maximized = this.is_maximized;
            settings.view_index = view_mode.selected;
            var current_track = library_manager.player.current_track;

            if (current_track != null && (library_manager.player.get_state () == Gst.State.PLAYING || library_manager.player.get_state () == Gst.State.PAUSED) &&
                (library_manager.player.play_mode == PlayMyMusic.Services.PlayMode.ALBUM
                 || library_manager.player.play_mode == PlayMyMusic.Services.PlayMode.ARTIST
                 || library_manager.player.play_mode == PlayMyMusic.Services.PlayMode.TRACKS
                 || library_manager.player.play_mode == PlayMyMusic.Services.PlayMode.PLAYLIST)) {
                settings.last_track_id = library_manager.player.current_track.ID;
                if (settings.remember_track_progress) {
                    settings.track_progress = library_manager.player.get_position_progress ();
                } else {
                    settings.track_progress = 0;
                }
                switch (library_manager.player.play_mode) {
                    case PlayMyMusic.Services.PlayMode.ALBUM :
                        settings.last_album_id = current_track.album.ID;
                        settings.track_source = "albums";
                        break;
                    case PlayMyMusic.Services.PlayMode.ARTIST :
                        settings.last_artist_id = current_track.album.artist.ID;
                        settings.track_source = "artists";
                        break;
                    case PlayMyMusic.Services.PlayMode.TRACKS :
                        settings.track_source = "tracks";
                        break;
                    case PlayMyMusic.Services.PlayMode.PLAYLIST :
                        settings.last_playlist_id = current_track.playlist.ID;
                        settings.track_source = "playlists";
                        break;
                }
            } else {
                settings.last_track_id = 0;
                settings.track_progress = 0;
                settings.track_source = "";
            }

            if (!settings.window_maximized) {
                int x, y;
                this.get_position (out x, out y);
                settings.window_x = x;
                settings.window_y = y;

                int width, height;
                this.get_size (out width, out height);
                settings.window_width = width;
                settings.window_height = height;
            }
        }
    }
}
