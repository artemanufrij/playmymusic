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

namespace PlayMyMusic.Widgets.Views {
    public class ArtistView : Gtk.Grid {
        Services.LibraryManager library_manager;
        Services.Player player;
        Settings settings;

        Gtk.ListBox tracks;

        Gtk.Box content;

        Gtk.Label artist_name;
        Gtk.Label artist_sub_title;
        Gtk.Image background;
        Gtk.Box header;
        Granite.Widgets.AlertView alert_view;

        bool only_mark = false;

        public Objects.Artist current_artist { get; private set; }

        construct {
            settings = Settings.get_default ();
            library_manager = Services.LibraryManager.instance;
            player = Services.Player.instance;
            player.state_changed.connect ((state) => {
                mark_playing_track (player.current_track);
            });

            settings.notify["use-dark-theme"].connect (() => {
                if (settings.use_dark_theme) {
                    tracks.get_style_context ().add_class ("artist-tracks-dark");
                    tracks.get_style_context ().remove_class ("artist-tracks");
                } else {
                    tracks.get_style_context ().add_class ("artist-tracks");
                    tracks.get_style_context ().remove_class ("artist-tracks-dark");
                }
            });
        }

        public ArtistView () {
            build_ui ();
        }

        private void build_ui () {
            content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.expand = true;

            header = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            header.height_request = 256;
            header.valign = Gtk.Align.CENTER;

            artist_name = new Gtk.Label ("");
            artist_name.valign = Gtk.Align.END;
            artist_name.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);
            header.pack_start (artist_name, true, true);

            artist_sub_title = new Gtk.Label ("");
            artist_sub_title.valign = Gtk.Align.START;
            artist_sub_title.use_markup = true;
            artist_sub_title.opacity = 0.75;
            header.pack_start (artist_sub_title, true, true);

            background = new Gtk.Image ();
            background.expand = true;

            var tracks_scroll = new Gtk.ScrolledWindow (null, null);
            tracks_scroll.expand = true;

            tracks = new Gtk.ListBox ();
            tracks.set_sort_func (tracks_sort_func);
            tracks.selected_rows_changed.connect (play_track);
            if (settings.use_dark_theme) {
                tracks.get_style_context ().add_class ("artist-tracks-dark");
            } else {
                tracks.get_style_context ().add_class ("artist-tracks");
            }
            tracks_scroll.add (tracks);

            content.pack_start (header, false, false, 0);
            content.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false, 0);
            content.pack_start (tracks_scroll, true, true, 0);

            alert_view = new Granite.Widgets.AlertView (_("Choose an Artist"), _("No Artist selected"), "avatar-default-symbolic");

            var overlay = new Gtk.Overlay ();
            overlay.add_overlay (background);
            overlay.add_overlay (content);
            overlay.add_overlay (alert_view);

            this.attach (new Gtk.Separator (Gtk.Orientation.VERTICAL), 0, 0);
            this.attach (overlay, 1, 0);
        }

        public void show_artist_viewer (Objects.Artist artist) {
            if (current_artist == artist) {
                return;
            }

            if (current_artist != null) {
                current_artist.track_added.disconnect (add_track);
                current_artist.background_changed.disconnect (load_background);
            }
            current_artist = artist;
            this.reset ();
            alert_view.hide ();

            load_background ();
            foreach (var track in artist.tracks) {
                add_track (track);
            }

            current_artist.track_added.connect (add_track);
            current_artist.background_changed.connect (load_background);
        }

        public void load_background () {
            int width = this.content.get_allocated_width ();
            int height = this.content.get_allocated_height ();
            if (current_artist == null || current_artist.background_path == null || current_artist.background == null || (background.pixbuf != null && background.pixbuf.width == width && background.pixbuf.height == height)) {
                return;
            }
            if (height < width) {
                var pix =  current_artist.background.scale_simple (width, width, Gdk.InterpType.BILINEAR);
                background.pixbuf = new Gdk.Pixbuf.subpixbuf (pix, 0, (int)(pix.height - height) / 2, width, height);
            } else {
                var pix =  current_artist.background.scale_simple (height, height, Gdk.InterpType.BILINEAR);
                background.pixbuf = new Gdk.Pixbuf.subpixbuf (pix, (int)(pix.width - width) / 2, 0, width, height);
            }

            artist_name.get_style_context ().add_class ("artist-title");
            artist_sub_title.get_style_context ().add_class ("artist-sub-title");
        }

        private void update_header () {
            artist_name.label = current_artist.name;
            artist_sub_title.label =  _("<b>%d Tracks</b> in <b>%d Album</b>(s)").printf ((int)current_artist.tracks.length (), (int)current_artist.albums.length ());
        }

        public void reset () {
            foreach (var child in tracks.get_children ()) {
                child.destroy ();
            }
            background.clear ();
            artist_name.label = "";
            artist_sub_title.label = "";
            artist_name.get_style_context ().remove_class ("artist-title");
            artist_sub_title.get_style_context ().remove_class ("artist-sub-title");
            alert_view.show ();
        }

        private void add_track (Objects.Track track) {
            Idle.add (() => {
                var item = new Widgets.Track (track, TrackStyle.ARTIST);
                this.tracks.add (item);
                update_header ();
                if (player.current_track != null && player.current_track.ID == track.ID) {
                    item.activate ();
                }
                return false;
            });
        }

        private void play_track () {
            var selected_row = tracks.get_selected_row ();
            if (selected_row != null && !only_mark) {
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
                    only_mark = true;
                    child.activate ();
                    if (PlayMyMusicApp.instance.mainwindow.content.visible_child_name == "artists") {
                        child.grab_focus ();
                    }
                    only_mark = false;
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
