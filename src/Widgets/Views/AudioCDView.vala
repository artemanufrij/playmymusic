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

namespace PlayMyMusic.Widgets.Views {
    public class AudioCDView : Gtk.Grid {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Settings settings;

        public PlayMyMusic.Objects.AudioCD? current_audio_cd { get; private set; }
        private string _filter = "";
        public string filter {
            get {
                return _filter;
            } set {
                if (_filter != value) {
                    _filter = value;
                    tracks.invalidate_filter ();
                }
            }
        }

        Gtk.Image icon_repeat_on;
        Gtk.Image icon_repeat_off;
        Gtk.Image icon_shuffle_on;
        Gtk.Image icon_shuffle_off;

        Gtk.Grid content;
        Gtk.Overlay overlay;
        Gtk.ListBox tracks;
        Gtk.Image cover;
        Gtk.Image background;
        Gtk.Label title;
        Gtk.Label artist;
        Gtk.Button shuffle_button;
        Gtk.Button repeat_button;
        Gtk.Menu menu;

        bool only_mark = false;
        string waiting_for_play = "";

        construct {
            settings = PlayMyMusic.Settings.get_default ();
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            var player = library_manager.player;
            player.state_changed.connect ((state) => {
                mark_playing_track (player.current_track);
            });

            settings.notify["repeat-mode"].connect (() => {
                if (settings.repeat_mode) {
                    repeat_button.set_image (icon_repeat_on);
                } else {
                    repeat_button.set_image (icon_repeat_off);
                }
                repeat_button.show_all ();
            });

            settings.notify["shuffle-mode"].connect (() => {
                if (settings.shuffle_mode) {
                    shuffle_button.set_image (icon_shuffle_on);
                } else {
                    shuffle_button.set_image (icon_shuffle_off);
                }
                repeat_button.show_all ();
            });
        }

        public AudioCDView () {
            build_ui ();
        }

        private void build_ui () {
            overlay = new Gtk.Overlay ();
            overlay.height_request = 512;

            content = new Gtk.Grid ();
            content.column_spacing = 90;
            content.row_spacing = 24;
            content.margin_left = 96;
            content.margin_right = 90;
            content.margin_bottom = 48;
            content.margin_top = 48;

            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            cover = new Gtk.Image ();
            cover.set_from_icon_name ("media-optical-cd-audio-symbolic", Gtk.IconSize.DIALOG);
            cover.height_request = 320;
            cover.width_request = 320;
            cover.get_style_context ().add_class ("card");
            cover.valign = Gtk.Align.START;
            cover.margin_top = 48;
            cover.margin_left = 6;
            cover.margin_right = 6;
            event_box.add (cover);

            menu = new Gtk.Menu ();
            var menu_new_cover = new Gtk.MenuItem.with_label (_("Set new Cover…"));
            menu_new_cover.activate.connect (() => {
                var new_cover = library_manager.choose_new_cover ();
                if (new_cover != null) {
                    try {
                        var pixbuf = new Gdk.Pixbuf.from_file (new_cover);
                        this.background.pixbuf = null;
                        current_audio_cd.set_new_cover (pixbuf, 320);
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
            });
            menu.append (menu_new_cover);
            menu.show_all ();

            title = new Gtk.Label ("");
            title.get_style_context ().add_class ("h1");
            title.halign = Gtk.Align.START;

            artist = new Gtk.Label ("");
            artist.get_style_context ().add_class ("h2");
            artist.halign = Gtk.Align.START;

            var tracks_scroll = new Gtk.ScrolledWindow (null, null);

            tracks = new Gtk.ListBox ();
            tracks.get_style_context ().add_class ("playlist-tracks");
            tracks.set_filter_func (tracks_filter_func);
            tracks.selected_rows_changed.connect (play_track);
            tracks.expand = true;
            tracks_scroll.add (tracks);

            var action_toolbar = new Gtk.ActionBar ();
            action_toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_INLINE_TOOLBAR);

            var eject_button = new Gtk.Button.from_icon_name ("media-eject-symbolic", Gtk.IconSize.BUTTON);
            eject_button.clicked.connect (() => {
                if (library_manager.player.play_mode == PlayMyMusic.Services.PlayMode.AUDIO_CD) {
                    library_manager.player.stop ();
                }
                if (current_audio_cd.volume.can_eject ()) {
                    current_audio_cd.volume.get_drive ().eject_with_operation.begin (MountUnmountFlags.NONE, null);
                }
            });

            icon_shuffle_on = new Gtk.Image.from_icon_name ("media-playlist-shuffle-symbolic", Gtk.IconSize.BUTTON);
            icon_shuffle_off = new Gtk.Image.from_icon_name ("media-playlist-no-shuffle-symbolic", Gtk.IconSize.BUTTON);

            shuffle_button = new Gtk.Button ();
            if (settings.shuffle_mode) {
                shuffle_button.set_image (icon_shuffle_on);
            } else {
                shuffle_button.set_image (icon_shuffle_off);
            }
            shuffle_button.tooltip_text = _("Shuffle");
            shuffle_button.can_focus = false;
            shuffle_button.clicked.connect (() => {
                settings.shuffle_mode = !settings.shuffle_mode;
            });

            icon_repeat_on = new Gtk.Image.from_icon_name ("media-playlist-repeat-symbolic", Gtk.IconSize.BUTTON);
            icon_repeat_off = new Gtk.Image.from_icon_name ("media-playlist-no-repeat-symbolic", Gtk.IconSize.BUTTON);

            repeat_button = new Gtk.Button ();
            if (settings.repeat_mode) {
                repeat_button.set_image (icon_repeat_on);
            } else {
                repeat_button.set_image (icon_repeat_off);
            }
            repeat_button.tooltip_text = _("Repeat");
            repeat_button.can_focus = false;
            repeat_button.clicked.connect (() => {
                settings.repeat_mode = !settings.repeat_mode;
            });

            action_toolbar.pack_start (eject_button);
            action_toolbar.pack_end (repeat_button);
            action_toolbar.pack_end (shuffle_button);

            content.attach (event_box, 1, 0, 1, 3);
            content.attach (title, 0, 0);
            content.attach (artist, 0, 1);
            content.attach (tracks_scroll, 0, 2);

            background = new Gtk.Image ();
            background.opacity = 0.5;

            overlay.add_overlay (background);
            overlay.add_overlay (content);

            this.attach (overlay, 0, 0);
            this.attach (action_toolbar, 0, 1);
            this.show_all ();
        }

        public void show_audio_cd (PlayMyMusic.Objects.AudioCD audio_cd) {
            if (current_audio_cd == audio_cd) {
                return;
            }
            if (current_audio_cd != null) {
                current_audio_cd.track_added.disconnect (add_track);
                current_audio_cd.cover_changed.disconnect (change_cover);
                current_audio_cd.background_changed.disconnect (load_background);
                current_audio_cd.background_found.disconnect (load_background);
            }
            current_audio_cd = audio_cd;
            this.title.label = current_audio_cd.title;
            this.artist.label = current_audio_cd.artist;

            load_background ();
            foreach (var track in current_audio_cd.tracks) {
                add_track (track);
            }
            current_audio_cd.track_added.connect (add_track);
            current_audio_cd.notify ["title"].connect (() => {
                this.title.label = current_audio_cd.title;
            });
            current_audio_cd.notify ["artist"].connect (() => {
                this.artist.label = current_audio_cd.artist;
            });
            current_audio_cd.cover_changed.connect (change_cover);
            current_audio_cd.background_changed.connect (load_background);
            current_audio_cd.background_found.connect (load_background);
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }

        public void mark_playing_track (Objects.Track? track) {
            tracks.unselect_all ();
            if (track == null) {
                return;
            }
            foreach (var child in tracks.get_children ()) {
                if ((child as Widgets.Track).track.uri == track.uri) {
                    only_mark = true;
                    (child as Widgets.Track).activate ();
                    only_mark = false;
                    return;
                }
            }
        }

        public void load_background () {
            int width = this.overlay.get_allocated_width ();
            int height = this.overlay.get_allocated_height ();

            if (current_audio_cd == null || current_audio_cd.background == null || (background.pixbuf != null && background.pixbuf.width == width && background.pixbuf.height == height)) {
                return;
            }

            if (height < width) {
                var pix =  current_audio_cd.background.scale_simple (width, width, Gdk.InterpType.BILINEAR);
                background.pixbuf = new Gdk.Pixbuf.subpixbuf (pix, 0, (int)(pix.height - height) / 2, width, height);
            } else {
                var pix =  current_audio_cd.background.scale_simple (height, height, Gdk.InterpType.BILINEAR);
                background.pixbuf = new Gdk.Pixbuf.subpixbuf (pix, (int)(pix.width - width) / 2, 0, width, height);
            }
        }

        private void change_cover () {
            cover.pixbuf = current_audio_cd.cover;
        }

        private void add_track (PlayMyMusic.Objects.Track track) {
            Idle.add (() => {
                var item = new PlayMyMusic.Widgets.Track (track, TrackStyle.AUDIO_CD);
                this.tracks.add (item);
                item.show_all ();
                if (waiting_for_play != "" && track.uri == waiting_for_play) {
                    library_manager.play_track (track, Services.PlayMode.AUDIO_CD);
                }
                return false;
            });
        }

        public void reset () {
            foreach (var child in tracks.get_children ()) {
                child.destroy ();
            }
            current_audio_cd = null;
            background.pixbuf = null;
            this.title.label = "";
            this.artist.label = "";
            this.cover.set_from_icon_name ("media-optical-cd-audio-symbolic", Gtk.IconSize.DIALOG);
        }

        private void play_track () {
            var selected_row = tracks.get_selected_row ();
            if (selected_row != null && !only_mark) {
                library_manager.play_track ((selected_row as Widgets.Track).track, Services.PlayMode.AUDIO_CD);
            }
        }

        public void open_file (File file) {
            waiting_for_play = file.get_uri ().replace ("%20", " ");
            foreach (var child in tracks.get_children ()) {
                if ((child as Widgets.Track).track.uri == waiting_for_play) {
                    library_manager.play_track ((child as Widgets.Track).track, Services.PlayMode.AUDIO_CD);
                    waiting_for_play = "";
                    return;
                }
            }
        }

        private bool tracks_filter_func (Gtk.ListBoxRow child) {
            if (filter.strip ().length == 0) {
                return true;
            }

            string[] filter_elements = filter.strip ().down ().split (" ");
            var track = (child as PlayMyMusic.Widgets.Track).track;

            foreach (string filter_element in filter_elements) {
                if (!track.title.down ().contains (filter_element)) {
                    return false;
                }
            }
            return true;
        }
    }
}
