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
    public class AlbumView : Gtk.Grid {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Services.Player player;
        PlayMyMusic.Settings settings;

        Gtk.Image cover;
        Gtk.ListBox tracks;

        Gtk.Image icon_repeat_on;
        Gtk.Image icon_repeat_off;
        Gtk.Image icon_shuffle_on;
        Gtk.Image icon_shuffle_off;

        PlayMyMusic.Objects.Album current_album;

        public AlbumView () {
            settings = PlayMyMusic.Settings.get_default ();
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            player = PlayMyMusic.Services.Player.instance;
            player.play_mode_shuffle = settings.shuffle_mode;
            player.play_mode_repeat = settings.repeat_mode;
            build_ui ();
        }

        private void build_ui () {
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.vexpand = true;
            cover = new Gtk.Image ();
            var tracks_scroll = new Gtk.ScrolledWindow (null, null);

            tracks = new Gtk.ListBox ();
            tracks.set_sort_func (tracks_sort_func);
            tracks.selected_rows_changed.connect (play_track);
            tracks_scroll.add (tracks);

            var album_toolbar = new Gtk.ActionBar ();
            album_toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_INLINE_TOOLBAR);

            icon_shuffle_on = new Gtk.Image.from_icon_name ("media-playlist-shuffle-symbolic", Gtk.IconSize.BUTTON);
            icon_shuffle_off = new Gtk.Image.from_icon_name ("media-playlist-no-shuffle-symbolic", Gtk.IconSize.BUTTON);

            var shuffle_button = new Gtk.Button ();
            if (settings.shuffle_mode) {
                shuffle_button.set_image (icon_shuffle_on);
            } else {
                shuffle_button.set_image (icon_shuffle_off);
            }
            shuffle_button.tooltip_text = _("Shuffle");
            shuffle_button.can_focus = false;
            shuffle_button.clicked.connect (() => {
                player.play_mode_shuffle = !player.play_mode_shuffle;
                settings.shuffle_mode = player.play_mode_shuffle;
                if (player.play_mode_shuffle) {
                    shuffle_button.set_image (icon_shuffle_on);
                } else {
                    shuffle_button.set_image (icon_shuffle_off);
                }
            });
            album_toolbar.pack_start (shuffle_button);

            icon_repeat_on = new Gtk.Image.from_icon_name ("media-playlist-repeat-symbolic", Gtk.IconSize.BUTTON);
            icon_repeat_off = new Gtk.Image.from_icon_name ("media-playlist-no-repeat-symbolic", Gtk.IconSize.BUTTON);

            var repeat_button = new Gtk.Button ();
            if (settings.repeat_mode) {
                repeat_button.set_image (icon_repeat_on);
            } else {
                repeat_button.set_image (icon_repeat_off);
            }
            repeat_button.tooltip_text = _("Repeat");
            repeat_button.can_focus = false;
            repeat_button.clicked.connect (() => {
                player.play_mode_repeat = !player.play_mode_repeat;
                settings.repeat_mode = player.play_mode_repeat;
                if (player.play_mode_repeat) {
                    repeat_button.set_image (icon_repeat_on);
                } else {
                    repeat_button.set_image (icon_repeat_off);
                }
            });
            album_toolbar.pack_start (repeat_button);

            content.pack_start (cover, false, false, 0);
            content.pack_start (tracks_scroll, true, true, 0);
            content.pack_end (album_toolbar, false, false, 0);

            var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);
            this.attach (separator, 0, 0);
            this.attach (content, 1, 0);
        }

        public void mark_playing_track (Objects.Track? track) {
            if (track == null) {
                tracks.unselect_all ();
                return;
            }
            foreach (var item in tracks.get_children ()) {
                if ((item as Widgets.Track).track.ID == track.ID) {
                    (item as Widgets.Track).activate ();
                }
            }
        }

        public void play_album () {
            library_manager.play_track (current_album.get_first_track ());
        }

        private void play_track () {
            var selected_row = tracks.get_selected_row ();
            if (selected_row != null) {
                library_manager.play_track ((selected_row as Widgets.Track).track);
            }
        }

        public void show_album_viewer (PlayMyMusic.Objects.Album album) {
            if (current_album != null) {
                current_album.track_added.disconnect (add_track);
            }
            current_album = album;
            this.tracks.@foreach ((child) => {
                this.tracks.remove (child);
            });
            if (album.cover == null) {
                cover.set_from_icon_name ("audio-x-generic-symbolic", Gtk.IconSize.DIALOG);
                cover.height_request = 256;
                cover.width_request = 256;
            } else {
                cover.pixbuf = album.cover;
            }
            this.show_all ();
            foreach (var track in album.tracks) {
                add_track (track);
            }
            current_album.track_added.connect (add_track);
        }

        private void add_track (PlayMyMusic.Objects.Track track) {
            var item = new PlayMyMusic.Widgets.Track (track);
            this.tracks.add (item);
            item.show_all ();
        }

        private int tracks_sort_func (Gtk.ListBoxRow child1, Gtk.ListBoxRow child2) {
            var item1 = (Widgets.Track)child1;
            var item2 = (Widgets.Track)child2;
            if (item1 != null && item2 != null) {
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
