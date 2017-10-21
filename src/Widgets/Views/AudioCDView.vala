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

        Gtk.ListBox tracks;
        Gtk.Image cover;

        bool only_mark = false;
        string waiting_for_play = "";

        construct {
            settings = PlayMyMusic.Settings.get_default ();
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            var player = library_manager.player;
            player.state_changed.connect ((state) => {
                mark_playing_track (player.current_track);
            });
        }

        public AudioCDView () {
            build_ui ();
        }

        private void build_ui () {
            cover = new Gtk.Image ();
            cover.set_from_icon_name ("media-optical-cd-audio-symbolic", Gtk.IconSize.DIALOG);
            cover.height_request = 256;
            cover.width_request = 256;
            cover.get_style_context ().add_class ("card");
            cover.valign = Gtk.Align.CENTER;
            cover.margin = 96;
            this.attach (cover, 0, 0);

            var tracks_scroll = new Gtk.ScrolledWindow (null, null);
            tracks_scroll.expand = true;


            tracks = new Gtk.ListBox ();
            tracks.get_style_context ().add_class ("playlist-tracks");
            tracks.selected_rows_changed.connect (play_track);
            tracks.valign = Gtk.Align.CENTER;
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

            var icon_shuffle_on = new Gtk.Image.from_icon_name ("media-playlist-shuffle-symbolic", Gtk.IconSize.BUTTON);
            var icon_shuffle_off = new Gtk.Image.from_icon_name ("media-playlist-no-shuffle-symbolic", Gtk.IconSize.BUTTON);

            var shuffle_button = new Gtk.Button ();
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

            var icon_repeat_on = new Gtk.Image.from_icon_name ("media-playlist-repeat-symbolic", Gtk.IconSize.BUTTON);
            var icon_repeat_off = new Gtk.Image.from_icon_name ("media-playlist-no-repeat-symbolic", Gtk.IconSize.BUTTON);

            var repeat_button = new Gtk.Button ();
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
            this.attach (action_toolbar, 0, 1, 2, 1);

            this.attach (tracks_scroll, 1, 0);
            this.show_all ();
        }

        public void show_audio_cd (PlayMyMusic.Objects.AudioCD audio_cd) {
            if (current_audio_cd == audio_cd) {
                return;
            }
            if (current_audio_cd != null) {
                current_audio_cd.track_added.disconnect (add_track);
            }
            current_audio_cd = audio_cd;

            foreach (var track in current_audio_cd.tracks) {
                add_track (track);
            }
            current_audio_cd.track_added.connect (add_track);
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
                }
            }
        }

        private void add_track (PlayMyMusic.Objects.Track track) {
            var item = new PlayMyMusic.Widgets.Track (track, false);
            this.tracks.add (item);
            item.show_all ();
            if (waiting_for_play != "" && track.uri == waiting_for_play) {
                library_manager.play_track (track, Services.PlayMode.AUDIO_CD);
            }
        }

        public void reset () {
            foreach (var child in tracks.get_children ()) {
                child.destroy ();
            }
            current_audio_cd = null;
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
    }
}
