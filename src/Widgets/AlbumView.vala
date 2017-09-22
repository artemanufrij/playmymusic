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
    public class AlbumView : Gtk.Box {
        PlayMyMusic.Services.LibraryManager library_manager;

        Gtk.Image cover;
        Gtk.ListBox tracks;

        public AlbumView () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            library_manager = PlayMyMusic.Services.LibraryManager.instance;

            build_ui ();
        }

        private void build_ui () {
            cover = new Gtk.Image ();
            var tracks_scroll = new Gtk.ScrolledWindow (null, null);

            tracks = new Gtk.ListBox ();
            tracks.set_sort_func (tracks_sort_func);
            tracks.selected_rows_changed.connect (play_track);
            tracks_scroll.add (tracks);

            var album_toolbar = new Gtk.ActionBar ();
            album_toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_INLINE_TOOLBAR);

            var random_button = new Gtk.Button.from_icon_name ("media-playlist-no-shuffle-symbolic");
            random_button.tooltip_text = _("Random");
            album_toolbar.pack_start (random_button);

            var repeat_button = new Gtk.Button.from_icon_name ("media-playlist-no-repeat-symbolic");
            repeat_button.tooltip_text = _("Random");
            album_toolbar.pack_start (repeat_button);

            this.pack_start (cover, false, false, 0);
            this.pack_start (tracks_scroll, true, true, 0);
            this.pack_end (album_toolbar, false, false, 0);
        }

        public void mark_playing_track (Objects.Track? track) {
            if (track == null) {
                tracks.unselect_all ();
                return;
            }
            foreach (var item in tracks.get_children ()) {
                if ((item as Widgets.Track).track.path == track.path) {
                    (item as Widgets.Track).activate ();
                }
            }
        }

        private void play_track () {
            var selected_row = tracks.get_selected_row ();
            if (selected_row != null) {
                library_manager.play ((selected_row as Widgets.Track).track);
            }
        }

        public void show_album_viewer (PlayMyMusic.Objects.Album album) {
            this.tracks.@foreach ((child) => {
                this.tracks.remove (child);
            });
            cover.pixbuf = album.cover;
            foreach (var track in album.tracks) {
                this.tracks.add (new PlayMyMusic.Widgets.Track (track));
            }
            this.show_all ();
        }

        private int tracks_sort_func (Gtk.ListBoxRow child1, Gtk.ListBoxRow child2) {
            var item1 = (Widgets.Track)child1;
            var item2 = (Widgets.Track)child2;
            if (item1 != null && item2 != null) {
                if (item1.track_number > 0 && item2.track_number > 0){
                    return item1.track_number - item2.track_number;
                }
                return item1.title.collate (item2.title);
            }
            return 0;
        }
    }
}
