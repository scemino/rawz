const std = @import("std");
const GameFrac = @import("GameFrac.zig");
const util = @import("util.zig");
const assert = std.debug.assert;

pub const GAME_MIX_FREQ = 22050;

const GAME_PAULA_FREQ: i32 = 7159092;
const GAME_MAX_AUDIO_SAMPLES = 2048 * 16; // max number of audio samples in internal sample buffer
const GAME_MIX_BUF_SIZE = 4096 * 8;
const GAME_MIX_CHANNELS = GAME_SFX_NUM_CHANNELS + 1; // 4 channels + 1 for debug

const GAME_SFX_NUM_CHANNELS = 4;
const period_table = [_]u16{ 1076, 1016, 960, 906, 856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453, 428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226, 214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113 };

const snd_log = std.log.scoped(.sound);

const GameAudioSfxInstrument = struct {
    data: []const u8,
    volume: u16 = 0,
};

pub const GameAudioSfxPattern = struct {
    note_1: u16 = 0,
    note_2: u16 = 0,
    sample_start: u16 = 0,
    sample_buffer: ?[]const u8 = null,
    sample_len: u16 = 0,
    loop_pos: u16 = 0,
    loop_data: ?[]const u8 = null,
    loop_len: u16 = 0,
    period_arpeggio: u16 = 0, // unused by Another World tracks
    sample_volume: u16 = 0,
};

const GameAudioSfxModule = struct {
    data: []const u8,
    cur_pos: u16 = 0,
    cur_order: u8 = 0,
    num_order: u8 = 0,
    order_table: []const u8,
    samples: [15]GameAudioSfxInstrument,
};

const GameAudioSfxChannel = struct {
    sample_data: []const u8,
    sample_len: u16 = 0,
    sample_loop_pos: u16 = 0,
    sample_loop_len: u16 = 0,
    volume: u16 = 0,
    pos: GameFrac,

    pub fn mix(ch: *GameAudioSfxChannel, s: *i16) void {
        if (ch.sample_len == 0) {
            return;
        }
        const pos1: i32 = @intCast(ch.pos.offset >> GameFrac.bits);
        ch.pos.offset = @intCast(ch.pos.offset +% ch.pos.inc);
        var pos2: i32 = pos1 + 1;
        if (ch.sample_loop_len != 0) {
            if (pos1 >= ch.sample_loop_pos +% ch.sample_loop_len - 1) {
                pos2 = ch.sample_loop_pos;
                ch.pos.offset = @bitCast(pos2 << GameFrac.bits);
            }
        } else if (pos1 >= ch.sample_len - 1) {
            ch.sample_len = 0;
            return;
        }
        const s1 = @as(i8, @bitCast(ch.sample_data[@intCast(pos1)]));
        const s2 = @as(i8, @bitCast(ch.sample_data[@intCast(pos2)]));
        var sample: i32 = ch.pos.interpolate(s1, s2);
        sample = s.* +% @as(i32, @intCast(toi16(@divTrunc(sample * ch.volume, 64))));
        s.* = if (sample < -32768) -32768 else if (sample > 32767) 32767 else @as(i16, @intCast(sample));
    }

    fn toi16(a: i32) i16 {
        if (a <= -128) {
            return -32768;
        }
        if (a >= 127) {
            return 32767;
        }
        const uns_1: u8 = @as(u8, @bitCast(@as(i8, @intCast(a)))) ^ 0x80;
        const uns_2: u32 = @intCast(uns_1);
        const i = @as(i32, @bitCast((uns_2 << 8) | uns_2)) - 32768;
        return @intCast(i);
    }
};

const GameAudioChannel = struct {
    data: ?[]const u8,
    pos: GameFrac,
    len: u32 = 0,
    loop_len: u32 = 0,
    loop_pos: u32 = 0,
    volume: i32 = 0,
    mute: bool = false,

    pub fn initRaw(chan: *GameAudioChannel, data: []const u8, frequency: u8, volume: i32, mixingFreq: i32) void {
        const freq = getSoundFreq(frequency);
        chan.data = data[8..];
        chan.pos.reset(freq, mixingFreq);

        const len: u32 = @as(u32, @intCast(util.readBeU16(data[0..]))) * 2;
        chan.loop_len = @as(u32, @intCast(util.readBeU16(data[2..]))) * 2;
        chan.loop_pos = if (chan.loop_len > 0) len else 0;
        chan.len = len;

        chan.volume = volume;
    }

    pub fn mixRaw(chan: *GameAudioChannel, sample: *i16) void {
        if (chan.data) |data| {
            var pos = chan.pos.getInt();
            chan.pos.offset = @intCast(chan.pos.offset +% chan.pos.inc);
            if (chan.loop_len != 0) {
                if (pos >= chan.loop_pos + chan.loop_len) {
                    pos = chan.loop_pos;
                    chan.pos.offset = @intCast((chan.loop_pos << GameFrac.bits) +% chan.pos.inc);
                }
            } else if (pos >= chan.len) {
                chan.data = null;
                return;
            }
            const vol = if (chan.mute) 0 else chan.volume;
            sample.* = mixi16(sample.*, @divTrunc(@as(i32, toRawi16(data[pos] ^ 0x80)) * vol, 64));
        }
    }

    fn mixi16(sample1: i32, sample2: i32) i16 {
        const sample: i32 = sample1 + sample2;
        return @intCast(if (sample < -32768) -32768 else if (sample > 32767) 32767 else sample);
    }

    fn toRawi16(a: i32) i16 {
        return @truncate(((a << 8) | a) - 32768);
    }

    fn getSoundFreq(period: u8) i32 {
        return @divTrunc(GAME_PAULA_FREQ, @as(i32, @intCast(period_table[period])) * 2);
    }
};

pub const ResRead = *const fn (user_data: ?*anyopaque, id: u16) ?[]const u8;

const GameAudioSfxPlayer = struct {
    delay: u16 = 0,
    res_num: u16 = 0,
    sfx_mod: GameAudioSfxModule,
    playing: bool = false,
    samples_left: i32 = 0,
    channels: [GAME_SFX_NUM_CHANNELS]GameAudioSfxChannel,
    callback: ?*const fn (user_data: ?*anyopaque, pat_note2: u16) void = null,
    callback_user_data: ?*anyopaque = null,

    pub fn playSfxMusic(self: *GameAudioSfxPlayer) void {
        self.playing = true;
        self.samples_left = 0;
        self.channels = std.mem.zeroes(@TypeOf(self.channels));
    }

    pub fn sfxSetEventsDelay(self: *GameAudioSfxPlayer, delay: u16) void {
        snd_log.debug("SfxPlayer::setEventsDelay({})", .{delay});
        self.delay = delay;
    }

    pub fn stopSfxMusic(self: *GameAudioSfxPlayer) void {
        snd_log.debug("SfxPlayer::stop()", .{});
        self.playing = false;
    }

    pub fn handlePattern(player: *GameAudioSfxPlayer, channel: u2, data: []const u8) void {
        var pat = std.mem.zeroes(GameAudioSfxPattern);
        pat.note_1 = util.readBeU16(data);
        pat.note_2 = util.readBeU16(data[2..]);
        if (pat.note_1 != 0xFFFD) {
            const sample: u16 = (pat.note_2 & 0xF000) >> 12;
            if (sample != 0) {
                const ptr = player.sfx_mod.samples[sample - 1].data;
                if (ptr.len > 0) {
                    snd_log.debug("SfxPlayer::handlePattern() preparing sample {}", .{sample});
                    pat.sample_volume = player.sfx_mod.samples[sample - 1].volume;
                    pat.sample_start = 8;
                    pat.sample_buffer = ptr;
                    pat.sample_len = util.readBeU16(ptr) *% 2;
                    const loop_len: u16 = util.readBeU16(ptr[2..]) *% 2;
                    if (loop_len != 0) {
                        pat.loop_pos = pat.sample_len;
                        pat.loop_data = ptr;
                        pat.loop_len = loop_len;
                    } else {
                        pat.loop_pos = 0;
                        pat.loop_data = null;
                        pat.loop_len = 0;
                    }
                    var m: i16 = @bitCast(pat.sample_volume);
                    const effect: u8 = @truncate((@as(u16, @intCast(pat.note_2)) & 0x0F00) >> 8);
                    if (effect == 5) { // volume up
                        const volume: u8 = @intCast(pat.note_2 & 0xFF);
                        m += volume;
                        if (m > 0x3F) {
                            m = 0x3F;
                        }
                    } else if (effect == 6) { // volume down
                        const volume: u8 = @intCast(pat.note_2 & 0xFF);
                        m -= volume;
                        if (m < 0) {
                            m = 0;
                        }
                    }
                    player.channels[channel].volume = @bitCast(m);
                    pat.sample_volume = @bitCast(m);
                }
            }
        }
        if (pat.note_1 == 0xFFFD) {
            snd_log.debug("SfxPlayer::handlePattern() _syncVar = 0x{X}", .{pat.note_2});
            if (player.callback) |cb| cb(player.callback_user_data, pat.note_2);
        } else if (pat.note_1 != 0) {
            pat.period_arpeggio = pat.note_1;
            if (pat.period_arpeggio == 0xFFFE) {
                player.channels[channel] = std.mem.zeroes(@TypeOf(player.channels[channel]));
            } else if (pat.sample_buffer) |buf| {
                // TODO: fix and activate this: assert(pat.note_1 >= 0x37 and pat.note_1 < 0x1000);
                // convert Amiga period value to hz
                const freq: i32 = @divTrunc(GAME_PAULA_FREQ, @as(i32, @intCast(pat.note_1)) * 2);
                snd_log.debug("SfxPlayer::handlePattern() adding sample freq = 0x{X}", .{freq});
                var ch = &player.channels[channel];
                ch.sample_data = buf[pat.sample_start..];
                ch.sample_len = pat.sample_len;
                ch.sample_loop_pos = pat.loop_pos;
                ch.sample_loop_len = pat.loop_len;
                ch.volume = pat.sample_volume;
                ch.pos.offset = 0;
                ch.pos.inc = @divTrunc(@as(u64, @intCast(freq)) << GameFrac.bits, @as(u64, @intCast(GAME_MIX_FREQ)));
            }
        }
    }

    pub fn sfxLoadModule(player: *GameAudioSfxPlayer, buf: []const u8, delay: u16, pos: u8, user_data: ?*anyopaque, res_read: ResRead) void {
        player.sfx_mod = std.mem.zeroes(@TypeOf(player.sfx_mod));
        player.sfx_mod.cur_order = pos;
        player.sfx_mod.num_order = buf[0x3F];
        snd_log.debug("SfxPlayer::loadSfxModule() curOrder = 0x{X} numOrder = 0x{X}", .{ player.sfx_mod.cur_order, player.sfx_mod.num_order });
        player.sfx_mod.order_table = buf[0x40..];
        if (delay == 0) {
            player.delay = util.readBeU16(buf);
        } else {
            player.delay = delay;
        }
        player.sfx_mod.data = buf[0xC0..];
        snd_log.debug("SfxPlayer::loadSfxModule() eventDelay = {} ms", .{player.delay});
        player.sfxPrepareInstruments(buf[2..], user_data, res_read);
    }

    fn sfxPrepareInstruments(player: *GameAudioSfxPlayer, buf: []const u8, user_data: ?*anyopaque, res_read: ResRead) void {
        var p = buf;
        player.sfx_mod.samples = std.mem.zeroes(@TypeOf(player.sfx_mod.samples));
        for (&player.sfx_mod.samples, 0..) |*ins, i| {
            const res_num = std.mem.readInt(u16, p[0..2], .big);
            p = p[2..];
            if (res_num != 0) {
                ins.volume = util.readBeU16(p);
                if (res_read(user_data, res_num)) |ins_buf| {
                    ins.data = ins_buf;
                    snd_log.debug("Loaded instrument 0x{X} n={} volume={}", .{ res_num, i, ins.volume });
                } else {
                    snd_log.err("Error loading instrument 0x{X:0>2}", .{res_num});
                }
            }
            p = p[2..]; // skip volume
        }
    }
};

pub const GameAudioCallback = ?*const fn ([]const f32) void;

pub const Audio = struct {
    sample_buffer: [GAME_MAX_AUDIO_SAMPLES]f32,
    samples: [GAME_MIX_BUF_SIZE]i16,
    channels: [GAME_MIX_CHANNELS]GameAudioChannel,
    sfx_player: GameAudioSfxPlayer,
    mute_music: bool,
    callback: GameAudioCallback,

    pub fn init(self: *Audio, callback: GameAudioCallback) void {
        self.callback = callback;
    }

    pub fn sfxStart(self: *Audio) void {
        snd_log.debug("SfxPlayer::start()", .{});
        self.sfx_player.sfx_mod.cur_pos = 0;
    }

    pub fn stopSound(self: *Audio, channel: u3) void {
        snd_log.debug("Mixer::stopChannel({})", .{channel});
        self.channels[channel].data = null;
    }

    pub fn stopAll(self: *Audio) void {
        for (0..GAME_MIX_CHANNELS) |i| {
            self.stopSound(@intCast(i));
        }
        self.sfx_player.stopSfxMusic();
    }

    pub fn mixChannels(self: *Audio, samples: []i16) void {
        var smp = samples;
        // TODO: kAmigaStereoChannels ?
        //     if (kAmigaStereoChannels) {
        //      for (int i = 0; i < count; i += 2) {
        //         _game_audio_mix_raw(&game.audio.channels[0], samples);
        //         _game_audio_mix_raw(&game.audio.channels[3], samples);
        //        ++samples;
        //        _game_audio_mix_raw(&game.audio.channels[1], samples);
        //        _game_audio_mix_raw(&game.audio.channels[2], samples);
        //        ++samples;
        //      }
        //    } else
        {
            while (smp.len > 0) {
                for (&self.channels) |*channel| {
                    channel.mixRaw(&smp[0]);
                }
                smp[1] = smp[0];
                smp = smp[2..];
            }
        }
    }

    pub fn update(self: *Audio, num_samples: usize) void {
        assert(num_samples < GAME_MIX_BUF_SIZE);
        assert(num_samples < GAME_MAX_AUDIO_SAMPLES);
        @memset(&self.samples, 0);
        self.mixChannels(self.samples[0..num_samples]);
        self.sfxReadSamples(self.samples[0..num_samples]);
        for (self.samples[0..num_samples], 0..) |sample, i| {
            self.sample_buffer[i] = ((@as(f32, @floatFromInt(sample)) + 32768.0) / 32768.0) - 1.0;
        }
        if (self.callback) |cb| {
            cb(self.sample_buffer[0..num_samples]);
        }
    }

    fn sfxReadSamples(self: *Audio, buf: []i16) void {
        const player = &self.sfx_player;
        if (player.delay != 0 and !self.mute_music) {
            self.sfxMixSamples(buf);
        }
    }

    fn sfxMixSamples(self: *Audio, buffer: []i16) void {
        var buf = buffer;
        var len: i32 = @divTrunc(@as(i32, @intCast(buf.len)), 2);
        var player = &self.sfx_player;
        while (len != 0) {
            if (player.samples_left == 0) {
                self.sfxHandleEvents();
                const samples_per_tick = @divTrunc(GAME_MIX_FREQ * @divTrunc(@as(i32, @intCast(player.delay)) * 60 * 1000, GAME_PAULA_FREQ), 1000);
                player.samples_left = samples_per_tick;
            }
            const count = if (player.samples_left > len) len else player.samples_left;
            player.samples_left -= count;
            len -= count;
            for (0..@intCast(count)) |_| {
                player.channels[0].mix(&buf[0]);
                player.channels[3].mix(&buf[0]);
                player.channels[1].mix(&buf[1]);
                player.channels[2].mix(&buf[1]);
                buf = buf[2..];
            }
        }
    }

    fn sfxHandleEvents(self: *Audio) void {
        var player = &self.sfx_player;
        var order: usize = player.sfx_mod.order_table[player.sfx_mod.cur_order];
        var pattern_data = player.sfx_mod.data[@as(usize, player.sfx_mod.cur_pos) + order * 1024 ..];
        inline for (0..4) |ch| {
            player.handlePattern(@intCast(ch), pattern_data);
            pattern_data = pattern_data[4..];
        }
        player.sfx_mod.cur_pos += 4 * 4;
        snd_log.debug("SfxPlayer::handleEvents() order = 0x{X} curPos = 0x{X}", .{ order, player.sfx_mod.cur_pos });
        if (player.sfx_mod.cur_pos >= 1024) {
            player.sfx_mod.cur_pos = 0;
            order = player.sfx_mod.cur_order + 1;
            if (order == player.sfx_mod.num_order) {
                self.stopAll();
                order = 0;
                player.playing = false;
            }
            player.sfx_mod.cur_order = @truncate(order);
        }
    }
};
