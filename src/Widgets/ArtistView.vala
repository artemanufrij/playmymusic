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

namespace PlayMyMusic.Widgets {
    public class ArtistView : Gtk.Grid {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Services.Player player;
        PlayMyMusic.Settings settings;

        Gtk.ListBox tracks;

        Gtk.Image icon_repeat_on;
        Gtk.Image icon_repeat_off;
        Gtk.Image icon_shuffle_on;
        Gtk.Image icon_shuffle_off;
        Gtk.Button repeat_button;
        Gtk.Button shuffle_button;
        Gtk.Label artist_name;
        Gtk.Label artist_sub_title;
        Gtk.Image background;
        Gtk.Grid header;
        Gtk.ScrolledWindow tracks_scroll;

        public PlayMyMusic.Objects.Artist current_artist { get; private set; }

        construct {
            settings = PlayMyMusic.Settings.get_default ();
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.player_state_changed.connect ((state) => {
                var curret_track = library_manager.player.current_track;
                if (state == Gst.State.PLAYING && curret_track != null) {
                    mark_playing_track (curret_track);
                } else if (state == Gst.State.NULL || curret_track == null) {
                    mark_playing_track (null);
                }
            });

            player = PlayMyMusic.Services.Player.instance;

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

            Granite.Widgets.Utils.set_theming_for_screen (
                this.get_screen (),
                """
                    .artist-title {
                        color: #fff;
                        text-shadow: 0px 1px 2px alpha (#000, 1);
                    }
                    .artist-sub-title {
                        color: #fff;
                        text-shadow: 0px 1px 2px alpha (#000, 1);
                        opacity: 0.75;
                    }
                """,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

        }

        public ArtistView () {
            build_ui ();
        }

        private void build_ui () {
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.expand = true;

            header = new Gtk.Grid ();
            header.row_spacing = 6;
            header.valign = Gtk.Align.CENTER;

            artist_name = new Gtk.Label ("");
            artist_name.valign = Gtk.Align.END;
            artist_name.hexpand = true;
            artist_name.get_style_context ().add_class (Granite.StyleClass.H1_TEXT);
            artist_name.get_style_context ().add_class ("artist-title");
            header.attach (artist_name, 0, 0);

            artist_sub_title = new Gtk.Label ("");
            artist_sub_title.valign = Gtk.Align.START;
            artist_sub_title.use_markup = true;
            artist_sub_title.get_style_context ().add_class ("artist-sub-title");
            header.attach (artist_sub_title, 0, 1);

            background = new Gtk.Image ();

            var overlay = new Gtk.Overlay ();
            overlay.height_request = 256;
            overlay.add_overlay (background);
            overlay.add_overlay (header);

            tracks_scroll = new Gtk.ScrolledWindow (null, null);
            tracks_scroll.expand = true;

            tracks = new Gtk.ListBox ();
            tracks.set_sort_func (tracks_sort_func);
            tracks.selected_rows_changed.connect (play_track);
            tracks_scroll.add (tracks);

            var action_toolbar = new Gtk.ActionBar ();
            action_toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_INLINE_TOOLBAR);

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

            action_toolbar.pack_end (repeat_button);
            action_toolbar.pack_end (shuffle_button);

            content.pack_start (overlay, false, false, 0);
            content.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false, 0);
            content.pack_start (tracks_scroll, true, true, 0);
            content.pack_end (action_toolbar, false, false, 0);

            var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);
            this.attach (separator, 0, 0);
            this.attach (content, 1, 0);
        }

        public void show_artist_viewer (PlayMyMusic.Objects.Artist artist) {
            if (current_artist == artist) {
                return;
            }

            if (current_artist != null) {
                current_artist.track_added.disconnect (add_track);
                current_artist.background_changed.disconnect (change_background);
                current_artist.background = null;
            }
            current_artist = artist;

            background.pixbuf = null;
            change_background ();

            this.reset ();
            foreach (var track in artist.tracks) {
                add_track (track);
            }

            current_artist.track_added.connect (add_track);
            current_artist.background_changed.connect (change_background);

            if (player.current_track != null) {
                mark_playing_track (player.current_track);
            }
        }

        public void change_background () {
            int width = this.header.get_allocated_width ();
            int height = background.get_allocated_height ();
            if (current_artist == null || current_artist.background_path == null || current_artist.background == null || (background.pixbuf != null && background.pixbuf.width == width)) {
                return;
            }
            try {
                var pix =  current_artist.background.scale_simple (width, width, Gdk.InterpType.BILINEAR);
                background.pixbuf = new Gdk.Pixbuf.subpixbuf (pix, 0, (int)(pix.height - height) / 2, width, height);
            } catch (Error err) {
                warning (err.message);
                background.pixbuf = null;
            }
            return;
        }

        private void update_header () {
            artist_name.label = current_artist.name;
            artist_sub_title.label =  _("<b>%d Tracks</b> in <b>%d Album</b>(s)").printf ((int)current_artist.tracks.length (), (int)current_artist.albums.length ());
        }

        public void reset () {
            foreach (var child in tracks.get_children ()) {
                tracks.remove (child);
            }
        }

        private void add_track (PlayMyMusic.Objects.Track track) {
            var item = new PlayMyMusic.Widgets.Track (track);
            this.tracks.add (item);
            item.show_all ();
            update_header ();
        }

        private void play_track () {
            var selected_row = tracks.get_selected_row ();
            if (selected_row != null) {
                library_manager.play_track ((selected_row as Widgets.Track).track, Services.PlayMode.ARTIST);
            }
        }

        public void play_artist () {
            Objects.Track? track;
            if (settings.shuffle_mode) {
                track = current_artist.get_shuffle_track (null);
            } else {
                track = current_artist.get_first_track ();
            }
            library_manager.play_track (track, Services.PlayMode.ARTIST);
        }

        public void mark_playing_track (Objects.Track? track) {
            tracks.unselect_all ();
            if (track == null) {
                return;
            }
            foreach (var child in tracks.get_children ()) {
                if ((child as Widgets.Track).track.ID == track.ID) {
                    (child as Widgets.Track).activate ();

                    Gtk.Allocation alloc;
                    child.get_allocation (out alloc);

                    stdout.printf ("alloc %d - %d\n", alloc.y, child.get_allocated_height ());
                    return;
                }
            }
        }

        private int tracks_sort_func (Gtk.ListBoxRow child1, Gtk.ListBoxRow child2) {
            var item1 = (Widgets.Track)child1;
            var item2 = (Widgets.Track)child2;
            if (item1 != null && item2 != null) {
                if (item1.track.album.year != item2.track.album.year) {
                    return item1.track.album.year - item2.track.album.year;
                }
                if (item1.track.album.title != item2.track.album.title) {
                    return item1.track.album.title.collate (item2.track.album.title);
                }
                if (item1.disc_number != item2.disc_number){
                    return item1.disc_number - item2.disc_number;
                }
                if (item1.track_number != item2.track_number){
                    return item1.track_number - item2.track_number;
                }
                return item1.title.collate (item2.title);
            }
            return 0;
        }
    }
}
