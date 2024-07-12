const std = @import("std");
const audio = @import("sokol").audio;
const glue = @import("glue.zig");
const assert = std.debug.assert;

pub const GAME_WIDTH = 320;
pub const GAME_HEIGHT = 200;

const GAME_ENTRIES_COUNT_20TH = 178;
const GAME_MEM_BLOCK_SIZE = 1 * 1024 * 1024;
const GAME_NUM_TASKS = 64;

const GAME_MIX_FREQ = 44100;
const GAME_MIX_BUF_SIZE = 4096 * 8;
const GAME_MIX_CHANNELS = 4;
const GAME_SFX_NUM_CHANNELS = 4;
const GAME_MAX_AUDIO_SAMPLES = 2048 * 16; // max number of audio samples in internal sample buffer

const _GFX_COL_ALPHA = 0x10; // transparent pixel (OR'ed with 0x8)
const _GFX_COL_PAGE = 0x11; // buffer 0 pixel
const _GFX_COL_BMP = 0xFF; // bitmap in buffer 0 pixel
const _GFX_FMT_CLUT = 0;
const _GFX_FMT_RGB555 = 1;
const _GFX_FMT_RGB = 2;
const _GFX_FMT_RGBA = 3;

const _GAME_INACTIVE_TASK = 0xFFFF;

const _GAME_FRAC_BITS = 16;
const _GAME_FRAC_MASK = (1 << _GAME_FRAC_BITS) - 1;

const GAME_VAR_RANDOM_SEED = 0x3C;
const GAME_VAR_SCREEN_NUM = 0x67;
const GAME_VAR_LAST_KEYCHAR = 0xDA;
const GAME_VAR_HERO_POS_UP_DOWN = 0xE5;
const GAME_VAR_MUSIC_SYNC = 0xF4;
const GAME_VAR_SCROLL_Y = 0xF9;
const GAME_VAR_HERO_ACTION = 0xFA;
const GAME_VAR_HERO_POS_JUMP_DOWN = 0xFB;
const GAME_VAR_HERO_POS_LEFT_RIGHT = 0xFC;
const GAME_VAR_HERO_POS_MASK = 0xFD;
const GAME_VAR_HERO_ACTION_POS_MASK = 0xFE;
const GAME_VAR_PAUSE_SLICES = 0xFF;

const GAME_QUAD_STRIP_MAX_VERTICES = 70;

const GAME_PAULA_FREQ: i32 = 7159092;

const font = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x10, 0x00, 0x28, 0x28, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x24, 0x7E, 0x24, 0x24, 0x7E, 0x24, 0x00, 0x08, 0x3E, 0x48, 0x3C, 0x12, 0x7C, 0x10, 0x00, 0x42, 0xA4, 0x48, 0x10, 0x24, 0x4A, 0x84, 0x00, 0x60, 0x90, 0x90, 0x70, 0x8A, 0x84, 0x7A, 0x00, 0x08, 0x08, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x08, 0x10, 0x10, 0x10, 0x08, 0x06, 0x00, 0xC0, 0x20, 0x10, 0x10, 0x10, 0x20, 0xC0, 0x00, 0x00, 0x44, 0x28, 0x10, 0x28, 0x44, 0x00, 0x00, 0x00, 0x10, 0x10, 0x7C, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x10, 0x20, 0x00, 0x00, 0x00, 0x7C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x28, 0x10, 0x00, 0x00, 0x04, 0x08, 0x10, 0x20, 0x40, 0x00, 0x00, 0x78, 0x84, 0x8C, 0x94, 0xA4, 0xC4, 0x78, 0x00, 0x10, 0x30, 0x50, 0x10, 0x10, 0x10, 0x7C, 0x00, 0x78, 0x84, 0x04, 0x08, 0x30, 0x40, 0xFC, 0x00, 0x78, 0x84, 0x04, 0x38, 0x04, 0x84, 0x78, 0x00, 0x08, 0x18, 0x28, 0x48, 0xFC, 0x08, 0x08, 0x00, 0xFC, 0x80, 0xF8, 0x04, 0x04, 0x84, 0x78, 0x00, 0x38, 0x40, 0x80, 0xF8, 0x84, 0x84, 0x78, 0x00, 0xFC, 0x04, 0x04, 0x08, 0x10, 0x20, 0x40, 0x00, 0x78, 0x84, 0x84, 0x78, 0x84, 0x84, 0x78, 0x00, 0x78, 0x84, 0x84, 0x7C, 0x04, 0x08, 0x70, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x10, 0x10, 0x60, 0x04, 0x08, 0x10, 0x20, 0x10, 0x08, 0x04, 0x00, 0x00, 0x00, 0xFE, 0x00, 0x00, 0xFE, 0x00, 0x00, 0x20, 0x10, 0x08, 0x04, 0x08, 0x10, 0x20, 0x00, 0x7C, 0x82, 0x02, 0x0C, 0x10, 0x00, 0x10, 0x00, 0x30, 0x18, 0x0C, 0x0C, 0x0C, 0x18, 0x30, 0x00, 0x78, 0x84, 0x84, 0xFC, 0x84, 0x84, 0x84, 0x00, 0xF8, 0x84, 0x84, 0xF8, 0x84, 0x84, 0xF8, 0x00, 0x78, 0x84, 0x80, 0x80, 0x80, 0x84, 0x78, 0x00, 0xF8, 0x84, 0x84, 0x84, 0x84, 0x84, 0xF8, 0x00, 0x7C, 0x40, 0x40, 0x78, 0x40, 0x40, 0x7C, 0x00, 0xFC, 0x80, 0x80, 0xF0, 0x80, 0x80, 0x80, 0x00, 0x7C, 0x80, 0x80, 0x8C, 0x84, 0x84, 0x7C, 0x00, 0x84, 0x84, 0x84, 0xFC, 0x84, 0x84, 0x84, 0x00, 0x7C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x7C, 0x00, 0x04, 0x04, 0x04, 0x04, 0x84, 0x84, 0x78, 0x00, 0x8C, 0x90, 0xA0, 0xE0, 0x90, 0x88, 0x84, 0x00, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0xFC, 0x00, 0x82, 0xC6, 0xAA, 0x92, 0x82, 0x82, 0x82, 0x00, 0x84, 0xC4, 0xA4, 0x94, 0x8C, 0x84, 0x84, 0x00, 0x78, 0x84, 0x84, 0x84, 0x84, 0x84, 0x78, 0x00, 0xF8, 0x84, 0x84, 0xF8, 0x80, 0x80, 0x80, 0x00, 0x78, 0x84, 0x84, 0x84, 0x84, 0x8C, 0x7C, 0x03, 0xF8, 0x84, 0x84, 0xF8, 0x90, 0x88, 0x84, 0x00, 0x78, 0x84, 0x80, 0x78, 0x04, 0x84, 0x78, 0x00, 0x7C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x78, 0x00, 0x84, 0x84, 0x84, 0x84, 0x84, 0x48, 0x30, 0x00, 0x82, 0x82, 0x82, 0x82, 0x92, 0xAA, 0xC6, 0x00, 0x82, 0x44, 0x28, 0x10, 0x28, 0x44, 0x82, 0x00, 0x82, 0x44, 0x28, 0x10, 0x10, 0x10, 0x10, 0x00, 0xFC, 0x04, 0x08, 0x10, 0x20, 0x40, 0xFC, 0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFE, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x00, 0x00, 0x38, 0x04, 0x3C, 0x44, 0x3C, 0x00, 0x40, 0x40, 0x78, 0x44, 0x44, 0x44, 0x78, 0x00, 0x00, 0x00, 0x3C, 0x40, 0x40, 0x40, 0x3C, 0x00, 0x04, 0x04, 0x3C, 0x44, 0x44, 0x44, 0x3C, 0x00, 0x00, 0x00, 0x38, 0x44, 0x7C, 0x40, 0x3C, 0x00, 0x38, 0x44, 0x40, 0x60, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x3C, 0x44, 0x44, 0x3C, 0x04, 0x78, 0x40, 0x40, 0x58, 0x64, 0x44, 0x44, 0x44, 0x00, 0x10, 0x00, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x02, 0x00, 0x02, 0x02, 0x02, 0x02, 0x42, 0x3C, 0x40, 0x40, 0x46, 0x48, 0x70, 0x48, 0x46, 0x00, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00, 0xEC, 0x92, 0x92, 0x92, 0x92, 0x00, 0x00, 0x00, 0x78, 0x44, 0x44, 0x44, 0x44, 0x00, 0x00, 0x00, 0x38, 0x44, 0x44, 0x44, 0x38, 0x00, 0x00, 0x00, 0x78, 0x44, 0x44, 0x78, 0x40, 0x40, 0x00, 0x00, 0x3C, 0x44, 0x44, 0x3C, 0x04, 0x04, 0x00, 0x00, 0x4C, 0x70, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x3C, 0x40, 0x38, 0x04, 0x78, 0x00, 0x10, 0x10, 0x3C, 0x10, 0x10, 0x10, 0x0C, 0x00, 0x00, 0x00, 0x44, 0x44, 0x44, 0x44, 0x78, 0x00, 0x00, 0x00, 0x44, 0x44, 0x44, 0x28, 0x10, 0x00, 0x00, 0x00, 0x82, 0x82, 0x92, 0xAA, 0xC6, 0x00, 0x00, 0x00, 0x44, 0x28, 0x10, 0x28, 0x44, 0x00, 0x00, 0x00, 0x42, 0x22, 0x24, 0x18, 0x08, 0x30, 0x00, 0x00, 0x7C, 0x08, 0x10, 0x20, 0x7C, 0x00, 0x60, 0x90, 0x20, 0x40, 0xF0, 0x00, 0x00, 0x00, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0x00, 0x38, 0x44, 0xBA, 0xA2, 0xBA, 0x44, 0x38, 0x00, 0x38, 0x44, 0x82, 0x82, 0x44, 0x28, 0xEE, 0x00, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA };

const restart_pos = [36 * 2]i16{ 16008, 0, 16001, 0, 16002, 10, 16002, 12, 16002, 14, 16003, 20, 16003, 24, 16003, 26, 16004, 30, 16004, 31, 16004, 32, 16004, 33, 16004, 34, 16004, 35, 16004, 36, 16004, 37, 16004, 38, 16004, 39, 16004, 40, 16004, 41, 16004, 42, 16004, 43, 16004, 44, 16004, 45, 16004, 46, 16004, 47, 16004, 48, 16004, 49, 16006, 64, 16006, 65, 16006, 66, 16006, 67, 16006, 68, 16005, 50, 16006, 60, 16007, 0 };

const strings_table_fr = [_]GameStrEntry{
    .{ .id = 0x001, .str = "P E A N U T  3000" },
    .{ .id = 0x002, .str = "Copyright  } 1990 Peanut Computer, Inc.\nAll rights reserved.\n\nCDOS Version 5.01" },
    .{ .id = 0x003, .str = "2" },
    .{ .id = 0x004, .str = "3" },
    .{ .id = 0x005, .str = "." },
    .{ .id = 0x006, .str = "A" },
    .{ .id = 0x007, .str = "@" },
    .{ .id = 0x008, .str = "PEANUT 3000" },
    .{ .id = 0x00A, .str = "R" },
    .{ .id = 0x00B, .str = "U" },
    .{ .id = 0x00C, .str = "N" },
    .{ .id = 0x00D, .str = "P" },
    .{ .id = 0x00E, .str = "R" },
    .{ .id = 0x00F, .str = "O" },
    .{ .id = 0x010, .str = "J" },
    .{ .id = 0x011, .str = "E" },
    .{ .id = 0x012, .str = "C" },
    .{ .id = 0x013, .str = "T" },
    .{ .id = 0x014, .str = "Shield 9A.5f Ok" },
    .{ .id = 0x015, .str = "Flux % 5.0177 Ok" },
    .{ .id = 0x016, .str = "CDI Vector ok" },
    .{ .id = 0x017, .str = " %%%ddd ok" },
    .{ .id = 0x018, .str = "Race-Track ok" },
    .{ .id = 0x019, .str = "SYNCHROTRON" },
    .{ .id = 0x01A, .str = "E: 23%\ng: .005\n\nRK: 77.2L\n\nopt: g+\n\n Shield:\n1: OFF\n2: ON\n3: ON\n\nP~: 1\n" },
    .{ .id = 0x01B, .str = "ON" },
    .{ .id = 0x01C, .str = "-" },
    .{ .id = 0x021, .str = "|" },
    .{ .id = 0x022, .str = "--- Etude theorique ---" },
    .{ .id = 0x023, .str = " L'EXPERIENCE DEBUTERA DANS    SECONDES." },
    .{ .id = 0x024, .str = "20" },
    .{ .id = 0x025, .str = "19" },
    .{ .id = 0x026, .str = "18" },
    .{ .id = 0x027, .str = "4" },
    .{ .id = 0x028, .str = "3" },
    .{ .id = 0x029, .str = "2" },
    .{ .id = 0x02A, .str = "1" },
    .{ .id = 0x02B, .str = "0" },
    .{ .id = 0x02C, .str = "L E T ' S   G O" },
    .{ .id = 0x031, .str = "- Phase 0:\nINJECTION des particules\ndans le synchrotron" },
    .{ .id = 0x032, .str = "- Phase 1:\nACCELERATION des particules." },
    .{ .id = 0x033, .str = "- Phase 2:\nEJECTION des particules\nsur le bouclier." },
    .{ .id = 0x034, .str = "A  N  A  L  Y  S  E" },
    .{ .id = 0x035, .str = "- RESULTAT:\nProbabilites de creer de:\n ANTI-MATIERE: 91.V %\n NEUTRINO 27:  0.04 %\n NEUTRINO 424: 18 %\n" },
    .{ .id = 0x036, .str = "Verification par la pratique O/N ?" },
    .{ .id = 0x037, .str = "SUR ?" },
    .{ .id = 0x038, .str = "MODIFICATION DES PARAMETRES\nRELATIFS A L'ACCELERATEUR\nDE PARTICULES (SYNCHROTRON)." },
    .{ .id = 0x039, .str = "SIMULATION DE L'EXPERIENCE ?" },
    .{ .id = 0x03C, .str = "t---t" },
    .{ .id = 0x03D, .str = "000 ~" },
    .{ .id = 0x03E, .str = ".20x14dd" },
    .{ .id = 0x03F, .str = "gj5r5r" },
    .{ .id = 0x040, .str = "tilgor 25%" },
    .{ .id = 0x041, .str = "12% 33% checked" },
    .{ .id = 0x042, .str = "D=4.2158005584" },
    .{ .id = 0x043, .str = "d=10.00001" },
    .{ .id = 0x044, .str = "+" },
    .{ .id = 0x045, .str = "*" },
    .{ .id = 0x046, .str = "% 304" },
    .{ .id = 0x047, .str = "gurgle 21" },
    .{ .id = 0x048, .str = "{{{{" },
    .{ .id = 0x049, .str = "Delphine Software" },
    .{ .id = 0x04A, .str = "By Eric Chahi" },
    .{ .id = 0x04B, .str = "5" },
    .{ .id = 0x04C, .str = "17" },
    .{ .id = 0x12C, .str = "0" },
    .{ .id = 0x12D, .str = "1" },
    .{ .id = 0x12E, .str = "2" },
    .{ .id = 0x12F, .str = "3" },
    .{ .id = 0x130, .str = "4" },
    .{ .id = 0x131, .str = "5" },
    .{ .id = 0x132, .str = "6" },
    .{ .id = 0x133, .str = "7" },
    .{ .id = 0x134, .str = "8" },
    .{ .id = 0x135, .str = "9" },
    .{ .id = 0x136, .str = "A" },
    .{ .id = 0x137, .str = "B" },
    .{ .id = 0x138, .str = "C" },
    .{ .id = 0x139, .str = "D" },
    .{ .id = 0x13A, .str = "E" },
    .{ .id = 0x13B, .str = "F" },
    .{ .id = 0x13C, .str = "       CODE D'ACCES:" },
    .{ .id = 0x13D, .str = "PRESSEZ LE BOUTON POUR CONTINUER" },
    .{ .id = 0x13E, .str = "   ENTRER LE CODE D'ACCES" },
    .{ .id = 0x13F, .str = "MOT DE PASSE INVALIDE !" },
    .{ .id = 0x140, .str = "ANNULER" },
    .{ .id = 0x141, .str = "     INSEREZ LA DISQUETTE ?\n\n\n\n\n\n\n\n\nPRESSEZ UNE TOUCHE POUR CONTINUER" },
    .{ .id = 0x142, .str = "SELECTIONNER LES SYMBOLES CORRESPONDANTS\nA LA POSITION\nDE LA ROUE DE PROTECTION" },
    .{ .id = 0x143, .str = "CHARGEMENT..." },
    .{ .id = 0x144, .str = "             ERREUR" },
    .{ .id = 0x15E, .str = "LDKD" },
    .{ .id = 0x15F, .str = "HTDC" },
    .{ .id = 0x160, .str = "CLLD" },
    .{ .id = 0x161, .str = "FXLC" },
    .{ .id = 0x162, .str = "KRFK" },
    .{ .id = 0x163, .str = "XDDJ" },
    .{ .id = 0x164, .str = "LBKG" },
    .{ .id = 0x165, .str = "KLFB" },
    .{ .id = 0x166, .str = "TTCT" },
    .{ .id = 0x167, .str = "DDRX" },
    .{ .id = 0x168, .str = "TBHK" },
    .{ .id = 0x169, .str = "BRTD" },
    .{ .id = 0x16A, .str = "CKJL" },
    .{ .id = 0x16B, .str = "LFCK" },
    .{ .id = 0x16C, .str = "BFLX" },
    .{ .id = 0x16D, .str = "XJRT" },
    .{ .id = 0x16E, .str = "HRTB" },
    .{ .id = 0x16F, .str = "HBHK" },
    .{ .id = 0x170, .str = "JCGB" },
    .{ .id = 0x171, .str = "HHFL" },
    .{ .id = 0x172, .str = "TFBB" },
    .{ .id = 0x173, .str = "TXHF" },
    .{ .id = 0x174, .str = "JHJL" },
    .{ .id = 0x181, .str = "PAR" },
    .{ .id = 0x182, .str = "ERIC CHAHI" },
    .{ .id = 0x183, .str = "          MUSIQUES ET BRUITAGES" },
    .{ .id = 0x184, .str = "DE" },
    .{ .id = 0x185, .str = "JEAN-FRANCOIS FREITAS" },
    .{ .id = 0x186, .str = "VERSION IBM PC" },
    .{ .id = 0x187, .str = "      PAR" },
    .{ .id = 0x188, .str = " DANIEL MORAIS" },
    .{ .id = 0x18B, .str = "PUIS PRESSER LE BOUTON" },
    .{ .id = 0x18C, .str = "POSITIONNER LE JOYSTICK EN HAUT A GAUCHE" },
    .{ .id = 0x18D, .str = " POSITIONNER LE JOYSTICK AU CENTRE" },
    .{ .id = 0x18E, .str = " POSITIONNER LE JOYSTICK EN BAS A DROITE" },
    .{ .id = 0x258, .str = "       Conception ..... Eric Chahi" },
    .{ .id = 0x259, .str = "    Programmation ..... Eric Chahi" },
    .{ .id = 0x25A, .str = "     Graphismes ....... Eric Chahi" },
    .{ .id = 0x25B, .str = "Musique de ...... Jean-francois Freitas" },
    .{ .id = 0x25C, .str = "              Bruitages" },
    .{ .id = 0x25D, .str = "        Jean-Francois Freitas\n             Eric Chahi" },
    .{ .id = 0x263, .str = "               Merci a" },
    .{ .id = 0x264, .str = "           Jesus Martinez\n\n          Daniel Morais\n\n        Frederic Savoir\n\n      Cecile Chahi\n\n    Philippe Delamarre\n\n  Philippe Ulrich\n\nSebastien Berthet\n\nPierre Gousseau" },
    .{ .id = 0x265, .str = "Now Go Back To Another Earth" },
    .{ .id = 0x190, .str = "Bonsoir professeur." },
    .{ .id = 0x191, .str = "Je vois que Monsieur a pris\nsa Ferrari." },
    .{ .id = 0x192, .str = "IDENTIFICATION" },
    .{ .id = 0x193, .str = "Monsieur est en parfaite sante." },
    .{ .id = 0x194, .str = "O" },
    .{ .id = 0x193, .str = "AU BOULOT !!!\n" },
    .{ .id = 0xFFFF, .str = "" },
};

const strings_table_eng = [_]GameStrEntry{
    .{ .id = 0x001, .str = "P E A N U T  3000" },
    .{ .id = 0x002, .str = "Copyright  } 1990 Peanut Computer, Inc.\nAll rights reserved.\n\nCDOS Version 5.01" },
    .{ .id = 0x003, .str = "2" },
    .{ .id = 0x004, .str = "3" },
    .{ .id = 0x005, .str = "." },
    .{ .id = 0x006, .str = "A" },
    .{ .id = 0x007, .str = "@" },
    .{ .id = 0x008, .str = "PEANUT 3000" },
    .{ .id = 0x00A, .str = "R" },
    .{ .id = 0x00B, .str = "U" },
    .{ .id = 0x00C, .str = "N" },
    .{ .id = 0x00D, .str = "P" },
    .{ .id = 0x00E, .str = "R" },
    .{ .id = 0x00F, .str = "O" },
    .{ .id = 0x010, .str = "J" },
    .{ .id = 0x011, .str = "E" },
    .{ .id = 0x012, .str = "C" },
    .{ .id = 0x013, .str = "T" },
    .{ .id = 0x014, .str = "Shield 9A.5f Ok" },
    .{ .id = 0x015, .str = "Flux % 5.0177 Ok" },
    .{ .id = 0x016, .str = "CDI Vector ok" },
    .{ .id = 0x017, .str = " %%%ddd ok" },
    .{ .id = 0x018, .str = "Race-Track ok" },
    .{ .id = 0x019, .str = "SYNCHROTRON" },
    .{ .id = 0x01A, .str = "E: 23%\ng: .005\n\nRK: 77.2L\n\nopt: g+\n\n Shield:\n1: OFF\n2: ON\n3: ON\n\nP~: 1\n" },
    .{ .id = 0x01B, .str = "ON" },
    .{ .id = 0x01C, .str = "-" },
    .{ .id = 0x021, .str = "|" },
    .{ .id = 0x022, .str = "--- Theoretical study ---" },
    .{ .id = 0x023, .str = " THE EXPERIMENT WILL BEGIN IN    SECONDS" },
    .{ .id = 0x024, .str = "  20" },
    .{ .id = 0x025, .str = "  19" },
    .{ .id = 0x026, .str = "  18" },
    .{ .id = 0x027, .str = "  4" },
    .{ .id = 0x028, .str = "  3" },
    .{ .id = 0x029, .str = "  2" },
    .{ .id = 0x02A, .str = "  1" },
    .{ .id = 0x02B, .str = "  0" },
    .{ .id = 0x02C, .str = "L E T ' S   G O" },
    .{ .id = 0x031, .str = "- Phase 0:\nINJECTION of particles\ninto synchrotron" },
    .{ .id = 0x032, .str = "- Phase 1:\nParticle ACCELERATION." },
    .{ .id = 0x033, .str = "- Phase 2:\nEJECTION of particles\non the shield." },
    .{ .id = 0x034, .str = "A  N  A  L  Y  S  I  S" },
    .{ .id = 0x035, .str = "- RESULT:\nProbability of creating:\n ANTIMATTER: 91.V %\n NEUTRINO 27:  0.04 %\n NEUTRINO 424: 18 %\n" },
    .{ .id = 0x036, .str = "   Practical verification Y/N ?" },
    .{ .id = 0x037, .str = "SURE ?" },
    .{ .id = 0x038, .str = "MODIFICATION OF PARAMETERS\nRELATING TO PARTICLE\nACCELERATOR (SYNCHROTRON)." },
    .{ .id = 0x039, .str = "       RUN EXPERIMENT ?" },
    .{ .id = 0x03C, .str = "t---t" },
    .{ .id = 0x03D, .str = "000 ~" },
    .{ .id = 0x03E, .str = ".20x14dd" },
    .{ .id = 0x03F, .str = "gj5r5r" },
    .{ .id = 0x040, .str = "tilgor 25%" },
    .{ .id = 0x041, .str = "12% 33% checked" },
    .{ .id = 0x042, .str = "D=4.2158005584" },
    .{ .id = 0x043, .str = "d=10.00001" },
    .{ .id = 0x044, .str = "+" },
    .{ .id = 0x045, .str = "*" },
    .{ .id = 0x046, .str = "% 304" },
    .{ .id = 0x047, .str = "gurgle 21" },
    .{ .id = 0x048, .str = "{{{{" },
    .{ .id = 0x049, .str = "Delphine Software" },
    .{ .id = 0x04A, .str = "By Eric Chahi" },
    .{ .id = 0x04B, .str = "  5" },
    .{ .id = 0x04C, .str = "  17" },
    .{ .id = 0x12C, .str = "0" },
    .{ .id = 0x12D, .str = "1" },
    .{ .id = 0x12E, .str = "2" },
    .{ .id = 0x12F, .str = "3" },
    .{ .id = 0x130, .str = "4" },
    .{ .id = 0x131, .str = "5" },
    .{ .id = 0x132, .str = "6" },
    .{ .id = 0x133, .str = "7" },
    .{ .id = 0x134, .str = "8" },
    .{ .id = 0x135, .str = "9" },
    .{ .id = 0x136, .str = "A" },
    .{ .id = 0x137, .str = "B" },
    .{ .id = 0x138, .str = "C" },
    .{ .id = 0x139, .str = "D" },
    .{ .id = 0x13A, .str = "E" },
    .{ .id = 0x13B, .str = "F" },
    .{ .id = 0x13C, .str = "        ACCESS CODE:" },
    .{ .id = 0x13D, .str = "PRESS BUTTON OR RETURN TO CONTINUE" },
    .{ .id = 0x13E, .str = "   ENTER ACCESS CODE" },
    .{ .id = 0x13F, .str = "   INVALID PASSWORD !" },
    .{ .id = 0x140, .str = "ANNULER" },
    .{ .id = 0x141, .str = "      INSERT DISK ?\n\n\n\n\n\n\n\n\nPRESS ANY KEY TO CONTINUE" },
    .{ .id = 0x142, .str = " SELECT SYMBOLS CORRESPONDING TO\n THE POSITION\n ON THE CODE WHEEL" },
    .{ .id = 0x143, .str = "    LOADING..." },
    .{ .id = 0x144, .str = "              ERROR" },
    .{ .id = 0x15E, .str = "LDKD" },
    .{ .id = 0x15F, .str = "HTDC" },
    .{ .id = 0x160, .str = "CLLD" },
    .{ .id = 0x161, .str = "FXLC" },
    .{ .id = 0x162, .str = "KRFK" },
    .{ .id = 0x163, .str = "XDDJ" },
    .{ .id = 0x164, .str = "LBKG" },
    .{ .id = 0x165, .str = "KLFB" },
    .{ .id = 0x166, .str = "TTCT" },
    .{ .id = 0x167, .str = "DDRX" },
    .{ .id = 0x168, .str = "TBHK" },
    .{ .id = 0x169, .str = "BRTD" },
    .{ .id = 0x16A, .str = "CKJL" },
    .{ .id = 0x16B, .str = "LFCK" },
    .{ .id = 0x16C, .str = "BFLX" },
    .{ .id = 0x16D, .str = "XJRT" },
    .{ .id = 0x16E, .str = "HRTB" },
    .{ .id = 0x16F, .str = "HBHK" },
    .{ .id = 0x170, .str = "JCGB" },
    .{ .id = 0x171, .str = "HHFL" },
    .{ .id = 0x172, .str = "TFBB" },
    .{ .id = 0x173, .str = "TXHF" },
    .{ .id = 0x174, .str = "JHJL" },
    .{ .id = 0x181, .str = " BY" },
    .{ .id = 0x182, .str = "ERIC CHAHI" },
    .{ .id = 0x183, .str = "         MUSIC AND SOUND EFFECTS" },
    .{ .id = 0x184, .str = " " },
    .{ .id = 0x185, .str = "JEAN-FRANCOIS FREITAS" },
    .{ .id = 0x186, .str = "IBM PC VERSION" },
    .{ .id = 0x187, .str = "      BY" },
    .{ .id = 0x188, .str = " DANIEL MORAIS" },
    .{ .id = 0x18B, .str = "       THEN PRESS FIRE" },
    .{ .id = 0x18C, .str = " PUT THE PADDLE ON THE UPPER LEFT CORNER" },
    .{ .id = 0x18D, .str = "PUT THE PADDLE IN CENTRAL POSITION" },
    .{ .id = 0x18E, .str = "PUT THE PADDLE ON THE LOWER RIGHT CORNER" },
    .{ .id = 0x258, .str = "      Designed by ..... Eric Chahi" },
    .{ .id = 0x259, .str = "    Programmed by...... Eric Chahi" },
    .{ .id = 0x25A, .str = "      Artwork ......... Eric Chahi" },
    .{ .id = 0x25B, .str = "Music by ........ Jean-francois Freitas" },
    .{ .id = 0x25C, .str = "            Sound effects" },
    .{ .id = 0x25D, .str = "        Jean-Francois Freitas\n             Eric Chahi" },
    .{ .id = 0x263, .str = "              Thanks To" },
    .{ .id = 0x264, .str = "           Jesus Martinez\n\n          Daniel Morais\n\n        Frederic Savoir\n\n      Cecile Chahi\n\n    Philippe Delamarre\n\n  Philippe Ulrich\n\nSebastien Berthet\n\nPierre Gousseau" },
    .{ .id = 0x265, .str = "Now Go Out Of This World" },
    .{ .id = 0x190, .str = "Good evening professor." },
    .{ .id = 0x191, .str = "I see you have driven here in your\nFerrari." },
    .{ .id = 0x192, .str = "IDENTIFICATION" },
    .{ .id = 0x193, .str = "Monsieur est en parfaite sante." },
    .{ .id = 0x194, .str = "Y\n" },
    .{ .id = 0x193, .str = "AU BOULOT !!!\n" },
    .{ .id = 0xFFFF, .str = "" },
};

const strings_table_demo = [_]GameStrEntry{
    .{ .id = 0x1F4, .str = "Over Two Years in the Making" },
    .{ .id = 0x1F5, .str = "   A New, State\nof the Art, Polygon\n  Graphics System" },
    .{ .id = 0x1F6, .str = "   Comes to the\nComputer With Full\n Screen Graphics" },
    .{ .id = 0x1F7, .str = "While conducting a nuclear fission\nexperiment at your local\nparticle accelerator ..." },
    .{ .id = 0x1F8, .str = "Nature decides to put a little\n    extra spin on the ball" },
    .{ .id = 0x1F9, .str = "And sends you ..." },
    .{ .id = 0x1FA, .str = "     Out of this World\nA Cinematic Action Adventure\n from Interplay Productions\n                    \n       By Eric CHAHI      \n\n  IBM version : D.MORAIS\n" },
    .{ .id = 0xFFFF, .str = "" },
};

const mem_list_parts = [_][4]u8{
    .{ 0x14, 0x15, 0x16, 0x00 }, // 16000 - protection screens
    .{ 0x17, 0x18, 0x19, 0x00 }, // 16001 - introduction
    .{ 0x1A, 0x1B, 0x1C, 0x11 }, // 16002 - water
    .{ 0x1D, 0x1E, 0x1F, 0x11 }, // 16003 - jail
    .{ 0x20, 0x21, 0x22, 0x11 }, // 16004 - 'cite'
    .{ 0x23, 0x24, 0x25, 0x00 }, // 16005 - 'arene'
    .{ 0x26, 0x27, 0x28, 0x11 }, // 16006 - 'luxe'
    .{ 0x29, 0x2A, 0x2B, 0x11 }, // 16007 - 'final'
    .{ 0x7D, 0x7E, 0x7F, 0x00 }, // 16008 - password screen
    .{ 0x7D, 0x7E, 0x7F, 0x00 }, // 16009 - password screen
};

const period_table = [_]u16{ 1076, 1016, 960, 906, 856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453, 428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226, 214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113 };

const GfxDim = struct { width: i32, height: i32 };

const GfxRect = struct { x: i32, y: i32, width: i32, height: i32 };

const GfxDisplayInfo = struct {
    const GfxDisplayInfoFrame = struct {
        dim: GfxDim, // framebuffer dimensions in pixels
        buffer: []u8,
        bytes_per_pixel: usize, // 1 or 4
    };
    frame: GfxDisplayInfoFrame,
    screen: GfxRect,
    palette: []u8,
    portrait: bool,
};

const GameMemEntry = struct {
    status: GameResStatus, // 0x0
    type: GameResType, // 0x1, Resource::ResType
    buf_ptr: []u8, // 0x2
    rank_num: u8, // 0x6
    bank_num: u8, // 0x7
    bank_pos: u32, // 0x8
    packed_size: u32, // 0xC
    unpacked_size: u32, // 0x12
};

pub const GamePart = enum(u16) {
    copy_protection = 16000,
    intro = 16001,
    water = 16002,
    prison = 16003,
    cite = 16004,
    arene = 16005,
    luxe = 16006,
    final = 16007,
    password = 16008,
};

const GameDataType = enum(u2) { dos, amiga, atari };

pub const GameLang = enum(u1) { fr, us };

const GameGfxFormat = enum(u2) {
    clut,
    rgb555,
    rgb,
    rgba,
};

const GameInput = enum {
    left,
    right,
    up,
    down,
    action,
    back,
    code,
    pause,
};

const GameResType = enum(u8) {
    sound,
    music,
    bitmap, // full screen 4bpp video buffer, size=200*320/2
    palette, // palette (1024=vga + 1024=ega), size=2048
    bytecode,
    shape,
    bank, // common part shapes (bank2.mat)
};

const GameResStatus = enum(u8) {
    null,
    loaded,
    toload,
    uninit = 0xff,
};

const GameAudioSfxInstrument = struct {
    data: []u8,
    volume: u16 = 0,
};

const GameAudioSfxPattern = struct {
    note_1: u16 = 0,
    note_2: u16 = 0,
    sample_start: u16 = 0,
    sample_buffer: ?[]u8 = null,
    sample_len: u16 = 0,
    loop_pos: u16 = 0,
    loop_len: u16 = 0,
    sample_volume: u16 = 0,
};

const GameAudioSfxModule = struct {
    data: []const u8,
    cur_pos: u16 = 0,
    cur_order: u8 = 0,
    num_order: u8 = 0,
    order_table: []u8,
    samples: [15]GameAudioSfxInstrument,
};

const GameFrac = struct {
    inc: u32 = 0,
    offset: u64 = 0,
};

const GameAudioSfxChannel = struct {
    sample_data: []u8,
    sample_len: u16 = 0,
    sample_loop_pos: u16 = 0,
    sample_loop_len: u16 = 0,
    volume: u16 = 0,
    pos: GameFrac,
};

const GameAudioSfxPlayer = struct {
    delay: u16 = 0,
    res_num: u16 = 0,
    sfx_mod: GameAudioSfxModule,
    playing: bool = false,
    rate: i32 = 0,
    samples_left: i32 = 0,
    channels: [GAME_SFX_NUM_CHANNELS]GameAudioSfxChannel,
};

const GameAudioCallback = ?*const fn ([]const f32) void;

const GamePc = struct {
    data: []u8,
    pc: u16,
};

const GameAudioChannel = struct {
    data: ?[]const u8,
    pos: GameFrac,
    len: u32 = 0,
    loop_len: u32 = 0,
    loop_pos: u32 = 0,
    volume: i32 = 0,
};

const GameAudioDesc = struct {
    callback: GameAudioCallback,
    sample_rate: i32,
};

const GameInputDir = packed struct {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
};

const GameBanks = struct {
    bank0D: []const u8,
    bank01: []const u8,
    bank02: []const u8,
    bank05: []const u8,
    bank06: []const u8,
    bank08: ?[]const u8 = null,

    fn get(self: GameBanks, i: usize) ?[]const u8 {
        switch (i + 1) {
            0x1 => return self.bank01,
            0x2 => return self.bank02,
            0x5 => return self.bank05,
            0x6 => return self.bank06,
            0x8 => return self.bank08,
            0xD => return self.bank0D,
            else => return null,
        }
        unreachable;
    }
};

const GameData = struct {
    mem_list: []const u8,
    banks: GameBanks,
    demo3_joy: []const u8, // contains content of demo3.joy file if present
};

const GameRes = struct {
    mem_list: [GAME_ENTRIES_COUNT_20TH]GameMemEntry,
    num_mem_list: u16,
    mem: [GAME_MEM_BLOCK_SIZE]u8,
    current_part: GamePart,
    next_part: ?GamePart,
    script_bak: usize,
    script_cur: usize,
    vid_cur: usize,
    use_seg_video2: bool,
    seg_video_pal: []u8,
    seg_code: []u8,
    seg_code_size: u16,
    seg_video1: []u8,
    seg_video2: []u8,
    has_password_screen: bool,
    data_type: GameDataType,
    data: GameData,
    lang: GameLang,
};

// configuration parameters for game_init()
const GameDesc = struct {
    part_num: GamePart, // indicates the part number where the fame starts
    use_ega: bool, // true to use EGA palette, false to use VGA palette
    lang: GameLang, // language to use
    enable_protection: bool,
    audio: GameAudioDesc,
    //TODO: debug = game_debug_t,
    data: GameData,
};

const GamePoint = struct { x: i16, y: i16 };

const GameQuadStrip = struct {
    num_vertices: u8,
    vertices: [GAME_QUAD_STRIP_MAX_VERTICES]GamePoint,
};

const GameFramebuffer = struct {
    buffer: [GAME_WIDTH * GAME_HEIGHT]u8,
};

const GameStrEntry = struct {
    id: u16,
    str: []const u8,
};

pub const Game = struct {
    const Gfx = struct {
        fb: [GAME_WIDTH * GAME_HEIGHT]u8, // frame buffer: this where is stored the image with indexed color
        fbs: [4]GameFramebuffer,
        palette: [256]u32, // palette containing 16 RGBA colors
        draw_page: u2,
        fix_up_palette: bool, // redraw all primitives on setPal script call
    };

    const Audio = struct {
        sample_buffer: [GAME_MAX_AUDIO_SAMPLES]f32,
        samples: [GAME_MIX_BUF_SIZE]i16,
        channels: [GAME_MIX_CHANNELS]GameAudioChannel,
        sfx_player: GameAudioSfxPlayer,
        callback: GameAudioCallback,
    };

    const Video = struct {
        next_pal: u8,
        current_pal: u8,
        buffers: [3]u2,
        p_data: GamePc,
        data_buf: []u8,
        use_ega: bool,
    };

    const Vm = struct {
        const Task = struct {
            pc: u16,
            next_pc: u16,
            state: u8,
            next_state: u8,
        };
        vars: [256]i16,
        stack_calls: [64]u16,

        tasks: [GAME_NUM_TASKS]Task,
        ptr: GamePc,
        stack_ptr: u8,
        paused: bool,
        screen_num: i32,
        start_time: u32,
        time_stamp: u32,
        current_task: u8,
    };

    const Input = struct {
        const DemoJoy = struct {
            keymask: u8,
            counter: u8,
            buf_ptr: []const u8,
            buf_pos: isize,
        };
        dir_mask: GameInputDir,
        action: bool, // run,shoot
        code: bool,
        pause: bool,
        quit: bool,
        back: bool,
        last_char: u8,
        demo_joy: DemoJoy,
    };

    valid: bool,
    enable_protection: bool,
    // TODO: debug:game_debug_t,
    res: GameRes,
    strings_table: []const GameStrEntry,
    part_num: GamePart,
    elapsed: u32,
    sleep: u32,

    gfx: Gfx,

    audio: Audio,
    video: Video,

    vm: Vm,

    input: Input,

    title: []const u8, // title of the game
};

pub fn displayInfo(game: ?*Game) glue.DisplayInfo {
    return .{
        .fb = .{
            .dim = .{
                .width = GAME_WIDTH,
                .height = GAME_HEIGHT,
            },
            .buffer = if (game) |self| .{ .Palette8 = &self.gfx.fb } else null,
        },
        .view = .{
            .x = 0,
            .y = 0,
            .width = GAME_WIDTH,
            .height = GAME_HEIGHT,
        },
        .palette = if (game) |self| &self.gfx.palette else null,
        .orientation = .Landscape,
    };
}

pub fn game_init(game: *Game, desc: GameDesc) !void {
    //assert(game and desc);
    //if (desc.debug.callback.func) { GAME_ASSERT(desc.debug.stopped); }
    game.valid = true;
    game.enable_protection = desc.enable_protection;
    // game.debug = desc.debug;
    game.part_num = desc.part_num;
    game.res.lang = desc.lang;
    // game.audio.callback = desc.audio.callback;
    gameAudioInit(game, desc.audio.callback);
    game.video.use_ega = desc.use_ega;

    game.res.data = desc.data;
    if (game.res.data.demo3_joy.len > 0 and game.res.data_type == .dos) {
        demo3_joy_read(game, game.res.data.demo3_joy);
    }

    // g_debugMask = GAME_DBG_INFO | GAME_DBG_VIDEO | GAME_DBG_SND | GAME_DBG_SCRIPT | GAME_DBG_BANK;
    game_res_detect_version(game);
    game_video_init(game);
    game.res.has_password_screen = true;
    game.res.script_bak = 0;
    game.res.script_cur = 0;
    game.res.vid_cur = GAME_MEM_BLOCK_SIZE - (GAME_WIDTH * GAME_HEIGHT / 2); // 4bpp bitmap
    try game_res_read_entries(game);

    game_gfx_set_work_page_ptr(game, 2);

    // TODO: game.vm.vars[GAME_VAR_RANDOM_SEED] = time(0);
    if (!game.enable_protection) {
        game.vm.vars[0xBC] = 0x10;
        game.vm.vars[0xC6] = 0x80;
        game.vm.vars[0xF2] = if (game.res.data_type == .amiga or game.res.data_type == .atari) 6000 else 4000;
        game.vm.vars[0xDC] = 33;
    }

    if (game.res.data_type == .dos) {
        game.vm.vars[0xE4] = 20;
    }

    game.strings_table = if (game.res.lang == .fr) &strings_table_fr else &strings_table_eng;

    if (game.enable_protection and (game.res.data_type != .dos or game.res.has_password_screen)) {
        game.part_num = .copy_protection;
    }

    const num = @intFromEnum(game.part_num);
    if (num < 36) {
        game_vm_restart_at(game, @enumFromInt(restart_pos[num * 2]), restart_pos[num * 2 + 1]);
    } else {
        game_vm_restart_at(game, @enumFromInt(num), -1);
    }
    // game.title = game_res_get_game_title(game);
}

pub fn game_exec(game: *Game, ms: u32) !void {
    //GAME_ASSERT(game && game.valid);
    game.elapsed += ms;

    if (game.sleep > 0) {
        if (ms > game.sleep) {
            game.sleep = 0;
        } else {
            game.sleep -= ms;
        }
        return;
    }

    var stopped = false;
    while (!stopped) {
        // TODO: debug
        // if (null == game.debug.callback.func) {
        //     // run without _debug hook
        //     stopped = game_vm_run(game);
        // } else {
        // run with _debug hook
        // stopped = *game.debug.stopped;
        if (!stopped) {
            stopped = stopped or try game_vm_run(game);
            // game.debug.callback.func(game.debug.callback.user_data, game.vm.tasks[game.vm.current_task].pc);
        } else {
            game.sleep = 0;
        }
        // }
    }

    //  audio
    const num_frames = audio.saudio_expect();
    if (num_frames > 0) {
        const num_samples = num_frames * audio.saudio_channels();
        gameAudioUpdate(game, num_samples);
    }

    //game.sleep += 20; // wait 20 ms (50 Hz)
}

fn game_vm_restart_at(game: *Game, part: GamePart, pos: i16) void {
    gameAudioStopAll(game);
    if (game.res.data_type == .dos and part == .copy_protection) {
        // VAR(0x54) indicates if the "Out of this World" title screen should be presented
        //
        //   0084: jmpIf(VAR(0x54) < 128, @00C4)
        //   ..
        //   008D: setPalette(num=0)
        //   0090: updateResources(res=18)
        //   ...
        //   00C4: setPalette(num=23)
        //   00CA: updateResources(res=71)

        // Use "Another World" title screen if language is set to French
        game.vm.vars[0x54] = if (game.res.lang == .fr) 0x1 else 0x81;
    }
    game_res_setup_part(game, @intFromEnum(part));
    for (0..GAME_NUM_TASKS) |i| {
        game.vm.tasks[i].pc = _GAME_INACTIVE_TASK;
        game.vm.tasks[i].next_pc = _GAME_INACTIVE_TASK;
        game.vm.tasks[i].state = 0;
        game.vm.tasks[i].next_state = 0;
    }
    game.vm.tasks[0].pc = 0;
    game.vm.screen_num = -1;
    if (pos >= 0) {
        game.vm.vars[0] = pos;
    }
    game.vm.start_time = game.elapsed;
    game.vm.time_stamp = game.elapsed;
    if (part == .water) {
        if (demo3_joy_start(game)) {
            @memset(game.vm.vars[0..256], 0);
        }
    }
}

fn game_vm_setup_tasks(game: *Game) void {
    if (game.res.next_part) |part| {
        game_vm_restart_at(game, part, -1);
        game.res.next_part = null;
    }
    for (0..GAME_NUM_TASKS) |i| {
        game.vm.tasks[i].state = game.vm.tasks[i].next_state;
        const n = game.vm.tasks[i].next_pc;
        if (n != _GAME_INACTIVE_TASK) {
            game.vm.tasks[i].pc = if (n == _GAME_INACTIVE_TASK - 1) _GAME_INACTIVE_TASK else n;
            game.vm.tasks[i].next_pc = _GAME_INACTIVE_TASK;
        }
    }
}

fn game_vm_execute_task(game: *Game) !void {
    const opcode = fetch_byte(&game.vm.ptr);
    if ((opcode & 0x80) != 0) {
        const off = ((@as(u16, opcode) << 8) | fetch_byte(&game.vm.ptr)) << 1;
        game.res.use_seg_video2 = false;
        var pt: GamePoint = .{ .x = fetch_byte(&game.vm.ptr), .y = fetch_byte(&game.vm.ptr) };
        const h = pt.y - 199;
        if (h > 0) {
            pt.y = 199;
            pt.x += h;
        }
        std.log.debug("vid_opcd_0x80 : opcode=0x{X} off=0x{X} x={} y={}", .{ opcode, off, pt.x, pt.y });
        game_video_set_data_buffer(game, game.res.seg_video1, off);
        game_video_draw_shape(game, 0xFF, 64, pt);
    } else if ((opcode & 0x40) == 0x40) {
        var pt: GamePoint = undefined;
        const offsetHi = fetch_byte(&game.vm.ptr);
        const off = ((@as(u16, offsetHi) << 8) | fetch_byte(&game.vm.ptr)) << 1;
        pt.x = fetch_byte(&game.vm.ptr);
        game.res.use_seg_video2 = false;
        if ((opcode & 0x20) == 0) {
            if ((opcode & 0x10) == 0) {
                pt.x = (pt.x << 8) | fetch_byte(&game.vm.ptr);
            } else {
                pt.x = game.vm.vars[@intCast(pt.x)];
            }
        } else {
            if ((opcode & 0x10) != 0) {
                pt.x += 0x100;
            }
        }
        pt.y = fetch_byte(&game.vm.ptr);
        if ((opcode & 8) == 0) {
            if ((opcode & 4) == 0) {
                pt.y = (pt.y << 8) | fetch_byte(&game.vm.ptr);
            } else {
                pt.y = game.vm.vars[@intCast(pt.y)];
            }
        }
        var zoom: u16 = 64;
        if ((opcode & 2) == 0) {
            if ((opcode & 1) != 0) {
                zoom = @intCast(game.vm.vars[fetch_byte(&game.vm.ptr)]);
            }
        } else {
            if ((opcode & 1) != 0) {
                game.res.use_seg_video2 = true;
            } else {
                zoom = fetch_byte(&game.vm.ptr);
            }
        }
        std.log.debug("vid_opcd_0x40 : off=0x{X} x={} y={}", .{ off, pt.x, pt.y });
        game_video_set_data_buffer(game, if (game.res.use_seg_video2) game.res.seg_video2 else game.res.seg_video1, off);
        game_video_draw_shape(game, 0xFF, zoom, pt);
    } else if (opcode > 0x1A) {
        std.log.err("Script::executeTask() ec=0xFFF invalid opcode=0x{X}", .{opcode});
        return error.InvalidOpcode;
    } else {
        op_table[opcode](game);
    }
}

fn game_vm_run(game: *Game) !bool {
    var i = game.vm.current_task;
    if (!game.input.quit and game.vm.tasks[i].state == 0) {
        const n = game.vm.tasks[i].pc;
        if (n != _GAME_INACTIVE_TASK) {
            // execute 1 step of 1 task
            game.vm.ptr = .{ .data = game.res.seg_code, .pc = n };
            game.vm.paused = false;
            // std.log.debug("Script::runTasks() i=0x{X} n=0x{X}", .{ i, n });
            try game_vm_execute_task(game);
            game.vm.tasks[i].pc = game.vm.ptr.pc;
            // std.log.debug("Script::runTasks() i=0x{X} pos=0x{X}", .{ i, game.vm.tasks[i].pc });
            if (!game.vm.paused and game.vm.tasks[i].pc != _GAME_INACTIVE_TASK) {
                return false;
            }
        }
    }

    var result = false;

    while (true) {
        // go to next active thread
        i = (i + 1) % GAME_NUM_TASKS;
        if (i == 0) {
            result = true;
            game_vm_setup_tasks(game);
            game_vm_update_input(game);
        }

        if (game.vm.tasks[i].pc != _GAME_INACTIVE_TASK) {
            game.vm.stack_ptr = 0;
            game.vm.current_task = i;
            break;
        }
    }

    return result;
}

fn game_vm_update_input(game: *Game) void {
    if (game.res.current_part == .password) {
        const c = game.input.last_char;
        if (c == 8 or c == 0 or (c >= 'a' and c <= 'z')) {
            game.vm.vars[GAME_VAR_LAST_KEYCHAR] = c & ~@as(u8, @intCast(0x20));
            game.input.last_char = 0;
        }
    }
    var lr: i16 = 0;
    var m: i16 = 0;
    var ud: i16 = 0;
    var jd: i16 = 0;
    if (game.input.dir_mask.right) {
        lr = 1;
        m |= 1;
    }
    if (game.input.dir_mask.left) {
        lr = -1;
        m |= 2;
    }
    if (game.input.dir_mask.down) {
        ud = 1;
        jd = 1;
        m |= 4; // crouch
    }
    if (game.input.dir_mask.up) {
        ud = -1;
        jd = -1;
        m |= 8; // jump
    }
    if (!(game.res.data_type == .amiga or game.res.data_type == .atari)) {
        game.vm.vars[GAME_VAR_HERO_POS_UP_DOWN] = ud;
    }
    game.vm.vars[GAME_VAR_HERO_POS_JUMP_DOWN] = jd;
    game.vm.vars[GAME_VAR_HERO_POS_LEFT_RIGHT] = lr;
    game.vm.vars[GAME_VAR_HERO_POS_MASK] = m;
    var action: i16 = 0;
    if (game.input.action) {
        action = 1;
        m |= 0x80;
    }
    game.vm.vars[GAME_VAR_HERO_ACTION] = action;
    game.vm.vars[GAME_VAR_HERO_ACTION_POS_MASK] = m;
    if (game.res.current_part == .water) {
        const mask = demo3_joy_update(game);
        if (mask != 0) {
            game.vm.vars[GAME_VAR_HERO_ACTION_POS_MASK] = mask;
            game.vm.vars[GAME_VAR_HERO_POS_MASK] = mask & 15;
            game.vm.vars[GAME_VAR_HERO_POS_LEFT_RIGHT] = 0;
            // TODO: change bit mask
            if ((mask & 1) != 0) {
                game.vm.vars[GAME_VAR_HERO_POS_LEFT_RIGHT] = 1;
            }
            if ((mask & 2) != 0) {
                game.vm.vars[GAME_VAR_HERO_POS_LEFT_RIGHT] = -1;
            }
            game.vm.vars[GAME_VAR_HERO_POS_JUMP_DOWN] = 0;
            if ((mask & 4) != 0) {
                game.vm.vars[GAME_VAR_HERO_POS_JUMP_DOWN] = 1;
            }
            if ((mask & 8) != 0) {
                game.vm.vars[GAME_VAR_HERO_POS_JUMP_DOWN] = -1;
            }
            game.vm.vars[GAME_VAR_HERO_ACTION] = (mask >> 7);
        }
    }
}

fn game_res_invalidate_all(game: *Game) void {
    for (0..game.res.num_mem_list) |i| {
        game.res.mem_list[i].status = .null;
    }
    game.res.script_cur = 0;
    game.video.current_pal = 0xFF;
}

fn game_res_read_bank(game: *Game, me: *const GameMemEntry, dst_buf: []u8) bool {
    if (me.bank_num > 0xd)
        return false;

    if (game.res.data.banks.get(me.bank_num - 1)) |bank| {
        if (me.packed_size != me.unpacked_size) {
            return byte_killer_unpack(dst_buf[0..me.unpacked_size], bank[me.bank_pos..][0..me.packed_size]);
        }

        return true;
    }
    return false;
}

fn game_res_load(game: *Game) void {
    while (true) {
        var me_found: ?*GameMemEntry = null;

        // get resource with max rank_num
        var maxNum: u8 = 0;
        var resourceNum: usize = 0;
        for (0..game.res.num_mem_list) |i| {
            const it = &game.res.mem_list[i];
            if (it.status == .toload and maxNum <= it.rank_num) {
                maxNum = it.rank_num;
                me_found = it;
                resourceNum = i;
            }
        }
        if (me_found) |me| {
            var memPtr: []u8 = undefined;
            if (me.type == .bitmap) {
                memPtr = game.res.mem[game.res.vid_cur..];
            } else {
                memPtr = game.res.mem[game.res.script_cur..];
                const avail: usize = (game.res.vid_cur - game.res.script_cur);
                if (me.unpacked_size > avail) {
                    std.log.warn("Resource::load() not enough memory, available={}", .{avail});
                    me.status = .null;
                    continue;
                }
            }
            if (me.bank_num == 0) {
                std.log.warn("Resource::load() ec=0xF00 (me.bankNum == 0)", .{});
                me.status = .null;
            } else {
                std.log.debug("Resource::load() bufPos=0x{X} size={} type={} pos=0x{X} bankNum={}", .{ game.res.mem.len - memPtr.len, me.packed_size, me.type, me.bank_pos, me.bank_num });
                if (game_res_read_bank(game, me, memPtr)) {
                    if (me.type == .bitmap) {
                        game_video_copy_bitmap_ptr(game, game.res.mem[game.res.vid_cur..]);
                        me.status = .null;
                    } else {
                        me.buf_ptr = memPtr;
                        me.status = .loaded;
                        game.res.script_cur += me.unpacked_size;
                    }
                } else {
                    if (game.res.data_type == .dos and me.bank_num == 12 and me.type == .bank) {
                        // DOS demo version does not have the bank for this resource
                        // this should be safe to ignore as the resource does not appear to be used by the game code
                        me.status = .null;
                        continue;
                    }
                    std.log.err("Unable to read resource {} from bank {}", .{ resourceNum, me.bank_num });
                }
            }
        } else break;
    }
}

fn game_res_setup_part(game: *Game, ptrId: usize) void {
    if (@as(GamePart, @enumFromInt(ptrId)) != game.res.current_part) {
        var ipal: u8 = 0;
        var icod: u8 = 0;
        var ivd1: u8 = 0;
        var ivd2: u8 = 0;
        if (ptrId >= 16000 and ptrId <= 16009) {
            const part = ptrId - 16000;
            ipal = mem_list_parts[part][0];
            icod = mem_list_parts[part][1];
            ivd1 = mem_list_parts[part][2];
            ivd2 = mem_list_parts[part][3];
        } else {
            std.log.err("Resource::setupPart() ec=0xF07 invalid part", .{});
        }
        game_res_invalidate_all(game);
        game.res.mem_list[ipal].status = .toload;
        game.res.mem_list[icod].status = .toload;
        game.res.mem_list[ivd1].status = .toload;
        if (ivd2 != 0) {
            game.res.mem_list[ivd2].status = .toload;
        }
        game_res_load(game);
        game.res.seg_video_pal = game.res.mem_list[ipal].buf_ptr;
        game.res.seg_code = game.res.mem_list[icod].buf_ptr;
        game.res.seg_code_size = @intCast(game.res.mem_list[icod].unpacked_size);
        game.res.seg_video1 = game.res.mem_list[ivd1].buf_ptr;
        if (ivd2 != 0) {
            game.res.seg_video2 = game.res.mem_list[ivd2].buf_ptr;
        }
        game.res.current_part = @enumFromInt(ptrId);
    }
    game.res.script_bak = game.res.script_cur;
}

fn game_res_detect_version(game: *Game) void {
    if (game.res.data.mem_list.len > 0) {
        game.res.data_type = .dos;
        std.log.debug("Using DOS data files", .{});
    } else unreachable;
    // TODO:
    // } else {
    //     const amiga_mem_entry_t* entries = detect_amiga_atari(game);
    //     if(entries) {
    //         if (entries == _mem_list_atari_en) {
    //             game.res.data_type = DT_ATARI;
    //             _debug(GAME_DBG_INFO, "Using Atari data files");
    //         } else {
    //             game.res.data_type = DT_AMIGA;
    //             _debug(GAME_DBG_INFO, "Using Amiga data files");
    //         }
    //         game.res.num_mem_list = _GAME_ENTRIES_COUNT;
    //         for (int i = 0; i < _GAME_ENTRIES_COUNT; ++i) {
    //             game.res.mem_list[i].type = entries[i].type;
    //             game.res.mem_list[i].bank_num = entries[i].bank;
    //             game.res.mem_list[i].bank_pos = entries[i].offset;
    //             game.res.mem_list[i].packed_size = entries[i].packed_size;
    //             game.res.mem_list[i].unpacked_size = entries[i].unpacked_size;
    //         }
    //         game.res.mem_list[_GAME_ENTRIES_COUNT].status = 0xFF;
    //     }
    // }
}

fn game_res_update(game: *Game, num: u16) void {
    if (num > 16000) {
        game.res.next_part = @enumFromInt(num);
        return;
    }

    var me = &game.res.mem_list[num];
    if (me.status == .null) {
        me.status = .toload;
        game_res_load(game);
    }
}

fn game_video_init(game: *Game) void {
    game.video.next_pal = 0xFF;
    game.video.current_pal = 0xFF;
    game.video.buffers[2] = game_video_get_page_ptr(game, 1);
    game.video.buffers[1] = game_video_get_page_ptr(game, 2);
    game_video_set_work_page_ptr(game, 0xfe);
}

fn game_video_get_page_ptr(game: *Game, page: u8) u2 {
    if (page <= 3) {
        return @truncate(page);
    }

    switch (page) {
        0xFF => return game.video.buffers[2],
        0xFE => return game.video.buffers[1],
        else => {
            std.log.warn("Video::getPagePtr() p != [0,1,2,3,0xFF,0xFE] == 0x{X}", .{page});
            return 0; // XXX check
        },
    }
}

fn game_video_set_work_page_ptr(game: *Game, page: u8) void {
    std.log.debug("Video::setWorkPagePtr({})", .{page});
    game.video.buffers[0] = game_video_get_page_ptr(game, page);
}

fn decode_amiga(src: []const u8, dst: []u8) void {
    const plane_size = GAME_HEIGHT * GAME_WIDTH / 8;
    var s: usize = 0;
    var d: usize = 0;
    for (0..GAME_HEIGHT) |_| {
        var x: usize = 0;
        while (x < GAME_WIDTH) : (x += 8) {
            inline for (0..8) |b| {
                const mask = 1 << (7 - b);
                var color: u8 = 0;
                inline for (0..4) |p| {
                    if ((src[s + p * plane_size] & mask) != 0) {
                        color |= 1 << p;
                    }
                }
                dst[d] = color;
                d += 1;
            }
            s += 1;
        }
    }
}

fn game_video_scale_bitmap(game: *Game, src: []const u8, fmt: GameGfxFormat) void {
    game_gfx_draw_bitmap(game, game.video.buffers[0], src, GAME_WIDTH, GAME_HEIGHT, fmt);
}

fn game_video_copy_bitmap_ptr(game: *Game, src: []const u8) void {
    // _ = game;
    if (game.res.data_type == .dos or game.res.data_type == .amiga) {
        var temp_bitmap: [GAME_WIDTH * GAME_HEIGHT]u8 = undefined;
        decode_amiga(src, &temp_bitmap);
        game_video_scale_bitmap(game, temp_bitmap[0..], .clut);
    } else if (game.res.data_type == .atari) {
        unreachable;
        // TODO:
        // var temp_bitmap: [GAME_WIDTH * GAME_HEIGHT]u8 = undefined;
        // decode_atari(src, temp_bitmap);
        // game_video_scale_bitmap(game, temp_bitmap, .clut);
    } else { // .BMP
        unreachable;
        // var w: i32 = undefined;
        // var h: i32 = undefined;
        // var buf = decode_bitmap(src, &w, &h);
        // if (buf.len > 0) {
        //     game_gfx_draw_bitmap(game, game.video.buffers[0], buf, w, h, .rgb);
        //     free(buf);
        // }
    }
}

fn game_video_read_palette_ega(buf: []const u8, num: u8, pal: [16]u32) void {
    _ = buf;
    _ = num;
    _ = pal;
    unreachable;
}

fn game_video_read_palette_amiga(buf: []const u8, num: u8, pal: *[16]u32) void {
    var p = buf[@as(usize, @intCast(num)) * 16 * @sizeOf(u16) ..];
    for (0..16) |i| {
        const color = std.mem.readInt(u16, p[i * 2 ..][0..2], .big);
        var r: u32 = (color >> 8) & 0xF;
        var g: u32 = (color >> 4) & 0xF;
        var b: u32 = color & 0xF;
        r = (r << 4) | r;
        g = (g << 4) | g;
        b = (b << 4) | b;
        pal[i] = 0xFF000000 | r | (g << 8) | (b << 16);
    }
}

fn game_video_change_pal(game: *Game, pal_num: u8) void {
    if (pal_num < 32 and pal_num != game.video.current_pal) {
        var pal: [16]u32 = [1]u32{0} ** 16;
        if (game.res.data_type == .dos and game.video.use_ega) {
            game_video_read_palette_ega(game.res.seg_video_pal, pal_num, pal);
        } else {
            game_video_read_palette_amiga(game.res.seg_video_pal, pal_num, &pal);
        }
        game_gfx_set_palette(game, pal);
        game.video.current_pal = pal_num;
    }
}

fn game_video_fill_page(game: *Game, page: u8, color: u8) void {
    std.log.debug("Video::fillPage({}, {})", .{ page, color });
    game_gfx_clear_buffer(game, game_video_get_page_ptr(game, page), color);
}

fn game_video_copy_page(game: *Game, s: u8, dst: u8, vscroll: i16) void {
    var src = s;
    std.log.debug("Video::copyPage({}, {})", .{ src, dst });
    if (src < 0xFE) {
        src = src & 0xBF; //~0x40
    }
    if (src >= 0xFE or (src & 0x80) == 0) { // no vscroll
        game_gfx_copy_buffer(game, game_video_get_page_ptr(game, dst), game_video_get_page_ptr(game, src), 0);
    } else {
        const sl = game_video_get_page_ptr(game, src & 3);
        const dl = game_video_get_page_ptr(game, dst);
        if (sl != dl and vscroll >= -199 and vscroll <= 199) {
            game_gfx_copy_buffer(game, dl, sl, vscroll);
        }
    }
}

fn game_video_set_data_buffer(game: *Game, dataBuf: []u8, offset: u16) void {
    game.video.data_buf = dataBuf;
    game.video.p_data = .{ .data = dataBuf, .pc = offset };
}

fn game_video_draw_shape_parts(game: *Game, zoom: u16, pgc: GamePoint) void {
    const pt = GamePoint{
        .x = pgc.x - @as(i16, @intCast(fetch_byte(&game.video.p_data) * zoom / 64)),
        .y = pgc.y - @as(i16, @intCast(fetch_byte(&game.video.p_data) * zoom / 64)),
    };
    const n: usize = @intCast(fetch_byte(&game.video.p_data));
    std.log.debug("Video::drawShapeParts n={}", .{n});
    for (0..n) |_| {
        var offset = fetch_word(&game.video.p_data);
        const po = GamePoint{
            .x = @intCast(@as(i32, @intCast(pt.x)) + @divTrunc(@as(i32, @intCast(fetch_byte(&game.video.p_data))) * zoom, 64)),
            .y = @intCast(@as(i32, @intCast(pt.y)) + @divTrunc(@as(i32, @intCast(fetch_byte(&game.video.p_data))) * zoom, 64)),
        };
        var color: u16 = 0xFF;
        if ((offset & 0x8000) != 0) {
            color = fetch_byte(&game.video.p_data);
            _ = fetch_byte(&game.video.p_data);
            color &= 0x7F;
        }
        offset <<= 1;
        const bak = game.video.p_data.pc;
        game.video.p_data = .{ .data = game.video.data_buf, .pc = offset };
        game_video_draw_shape(game, @truncate(color), zoom, po);
        game.video.p_data.pc = bak;
    }
}

fn game_video_draw_shape(game: *Game, c: u8, zoom: u16, pt: GamePoint) void {
    var color = c;
    var i = fetch_byte(&game.video.p_data);
    if (i >= 0xC0) {
        if ((color & 0x80) != 0) {
            color = i & 0x3F;
        }
        game_video_fill_polygon(game, color, zoom, pt);
    } else {
        i &= 0x3F;
        if (i == 1) {
            std.log.warn("Video::drawShape() ec=0xF80 (i != 2)", .{});
        } else if (i == 2) {
            game_video_draw_shape_parts(game, zoom, pt);
        } else {
            std.log.warn("Video::drawShape() ec=0xFBB (i != 2)", .{});
        }
    }
}

fn game_video_fill_polygon(game: *Game, color: u16, zoom: u16, pt: GamePoint) void {
    var pc = game.video.p_data;

    const bbw: u16 = pc.data[pc.pc] * zoom / 64;
    const bbh: u16 = pc.data[pc.pc + 1] * zoom / 64;
    pc.pc += 2;

    const x1: i16 = @intCast(pt.x - @as(i16, @intCast(bbw / 2)));
    const x2: i16 = @intCast(pt.x + @as(i16, @intCast(bbw / 2)));
    const y1: i16 = @intCast(pt.y - @as(i16, @intCast(bbh / 2)));
    const y2: i16 = @intCast(pt.y + @as(i16, @intCast(bbh / 2)));

    if (x1 > 319 or x2 < 0 or y1 > 199 or y2 < 0)
        return;

    var qs: GameQuadStrip = undefined;
    qs.num_vertices = pc.data[pc.pc];
    pc.pc += 1;
    if ((qs.num_vertices & 1) != 0) {
        std.log.warn("Unexpected number of vertices {}", .{qs.num_vertices});
        return;
    }
    //GAME_ASSERT(qs.num_vertices < GAME_QUAD_STRIP_MAX_VERTICES);

    for (0..qs.num_vertices) |i| {
        qs.vertices[i] = .{
            .x = @intCast(@as(i32, x1) + @as(i32, pc.data[pc.pc] * zoom / 64)),
            .y = @intCast(@as(i32, y1) + @as(i32, pc.data[pc.pc + 1] * zoom / 64)),
        };
        pc.pc += 2;
    }

    if (qs.num_vertices == 4 and bbw == 0 and bbh <= 1) {
        game_gfx_draw_point_page(game, game.video.buffers[0], @truncate(color), pt);
    } else {
        game_gfx_draw_quad_strip(game, game.video.buffers[0], @truncate(color), &qs);
    }
}

fn swap(x: anytype, y: anytype) void {
    const tmp = y.*;
    y.* = x.*;
    x.* = tmp;
}

fn game_video_update_display(game: *Game, page: u8) void {
    std.log.debug("Video::updateDisplay({})", .{page});
    if (page != 0xFE) {
        if (page == 0xFF) {
            swap(&game.video.buffers[1], &game.video.buffers[2]);
        } else {
            game.video.buffers[1] = game_video_get_page_ptr(game, page);
        }
    }
    if (game.video.next_pal != 0xFF) {
        game_video_change_pal(game, game.video.next_pal);
        game.video.next_pal = 0xFF;
    }
    game_gfx_draw_buffer(game, game.video.buffers[1]);
}

fn game_video_draw_string(game: *Game, color: u8, xx: u16, yy: u16, strId: u16) void {
    var x = xx;
    var y = yy;
    const escapedChars = false;
    var str = find_string(game.strings_table, strId);
    if (str.len == 0 and game.res.data_type == .dos) {
        str = find_string(&strings_table_demo, strId);
    }
    if (str.len == 0) {
        std.log.warn("Unknown string id {}", .{strId});
        return;
    }
    std.log.debug("drawString({}, {}, {}, '{s}')", .{ color, x, y, str });
    const len = str.len;
    for (0..len) |i| {
        if (str[i] == '\n' or str[i] == '\r') {
            y += 8;
            x = xx;
        } else if (str[i] == '\\' and escapedChars) {
            i += 1;
            if (i < len) {
                switch (str[i]) {
                    'n' => {
                        y += 8;
                        x = xx;
                    },
                }
            }
        } else {
            const pt: GamePoint = .{ .x = @as(i16, @bitCast(x * 8)), .y = @as(i16, @bitCast(y)) };
            game_gfx_draw_string_char(game, game.video.buffers[0], color, str[i], pt);
            x += 1;
        }
    }
}

fn demo3_joy_start(game: *Game) bool {
    if (game.input.demo_joy.buf_ptr.len > 0) {
        game.input.demo_joy.keymask = game.input.demo_joy.buf_ptr[0];
        game.input.demo_joy.counter = game.input.demo_joy.buf_ptr[1];
        game.input.demo_joy.buf_pos = 2;
        return true;
    }
    return false;
}

fn demo3_joy_read(game: *Game, buf_ptr: []const u8) void {
    game.input.demo_joy.buf_ptr = buf_ptr;
    game.input.demo_joy.buf_pos = -1;
}

fn demo3_joy_update(game: *Game) u8 {
    if (game.input.demo_joy.buf_pos >= 0 and game.input.demo_joy.buf_pos < game.input.demo_joy.buf_ptr.len) {
        if (game.input.demo_joy.counter == 0) {
            game.input.demo_joy.keymask = game.input.demo_joy.buf_ptr[@intCast(game.input.demo_joy.buf_pos)];
            game.input.demo_joy.buf_pos += 1;
            game.input.demo_joy.counter = game.input.demo_joy.buf_ptr[@intCast(game.input.demo_joy.buf_pos)];
            game.input.demo_joy.buf_pos += 1;
        } else {
            game.input.demo_joy.counter -= 1;
        }
        return game.input.demo_joy.keymask;
    }
    return 0;
}

fn find_string(strings_table: []const GameStrEntry, id: u16) []const u8 {
    for (strings_table) |se| {
        if (se.id == 0xFFFF) break;
        if (se.id == id) return se.str;
    }
    return "";
}

fn frac_reset(frac: *GameFrac, n: i32, d: i32) void {
    // TODO: check this
    frac.inc = @truncate(@as(u64, @bitCast(@divTrunc((@as(i64, n) << _GAME_FRAC_BITS), d))));
    frac.offset = 0;
}

fn frac_get_int(frac: GameFrac) u32 {
    return @truncate(frac.offset >> _GAME_FRAC_BITS);
}

fn frac_get_frac(frac: GameFrac) u32 {
    return @truncate(frac.offset & _GAME_FRAC_MASK);
}

fn frac_interpolate(frac: GameFrac, sample1: i32, sample2: i32) i32 {
    const fp = frac_get_frac(frac);
    return @truncate((@as(i64, @intCast(sample1)) * (_GAME_FRAC_MASK - fp) + @as(i64, @intCast(sample2)) * fp) >> _GAME_FRAC_BITS);
}

fn game_gfx_set_palette(game: *Game, colors: [16]u32) void {
    assert(colors.len <= 16);
    @memcpy(game.gfx.palette[0..16], colors[0..16]);
}

fn game_gfx_get_page_ptr(game: *Game, page: u2) *[GAME_WIDTH * GAME_HEIGHT]u8 {
    return &game.gfx.fbs[page].buffer;
}

fn game_gfx_set_work_page_ptr(game: *Game, page: u2) void {
    game.gfx.draw_page = page;
}

fn game_gfx_clear_buffer(game: *Game, page: u2, color: u8) void {
    @memset(game_gfx_get_page_ptr(game, page), color);
}

fn game_gfx_copy_buffer(game: *Game, dst: u2, src: u2, vscroll: i32) void {
    if (vscroll == 0) {
        @memcpy(game_gfx_get_page_ptr(game, dst), game_gfx_get_page_ptr(game, src));
    } else if (vscroll >= -199 and vscroll <= 199) {
        const dy = vscroll;
        if (dy < 0) {
            const size: usize = @as(usize, @intCast(GAME_HEIGHT + dy)) * GAME_WIDTH;
            @memcpy(game_gfx_get_page_ptr(game, dst)[0..size], game_gfx_get_page_ptr(game, src)[@as(usize, @intCast(-dy * GAME_WIDTH))..][0..size]);
        } else {
            const size: usize = @as(usize, @intCast(GAME_HEIGHT - dy)) * GAME_WIDTH;
            @memcpy(game_gfx_get_page_ptr(game, dst)[@as(usize, @intCast(dy * GAME_WIDTH))..][0..size], game_gfx_get_page_ptr(game, src)[0..size]);
        }
    }
}

fn game_gfx_draw_buffer(game: *Game, num: u2) void {
    const src = game_gfx_get_page_ptr(game, num);
    @memcpy(game.gfx.fb[0..], src[0 .. GAME_WIDTH * GAME_HEIGHT]);
}

fn game_gfx_draw_char(game: *Game, c: u8, x: u16, y: u16, color: u8) void {
    if ((x <= GAME_WIDTH - 8) and (y <= GAME_HEIGHT - 8)) {
        const ft = font[(@as(usize, @intCast(c - 0x20))) * 8 ..];
        const offset = (x + y * GAME_WIDTH);
        for (0..8) |j| {
            const ch = ft[j];
            inline for (0..8) |i| {
                if ((ch & (1 << (7 - i))) != 0) {
                    game.gfx.fbs[game.gfx.draw_page].buffer[offset + j * GAME_WIDTH + i] = color;
                }
            }
        }
    }
}

fn game_gfx_draw_string_char(game: *Game, page: u2, color: u8, c: u8, pt: GamePoint) void {
    game_gfx_set_work_page_ptr(game, page);
    game_gfx_draw_char(game, c, @bitCast(pt.x), @bitCast(pt.y), color);
}

fn game_gfx_draw_point(game: *Game, x: i16, y: i16, color: u8) void {
    const offset = @as(i32, @intCast(y)) * GAME_WIDTH + (@as(i32, @intCast(x)));
    game.gfx.fbs[game.gfx.draw_page].buffer[@intCast(offset)] = switch (color) {
        _GFX_COL_ALPHA => game.gfx.fbs[game.gfx.draw_page].buffer[@intCast(offset)] | 8,
        _GFX_COL_PAGE => game.gfx.fbs[0].buffer[@intCast(offset)],
        else => color,
    };
}

fn game_gfx_draw_point_page(game: *Game, page: u2, color: u8, pt: GamePoint) void {
    game_gfx_set_work_page_ptr(game, page);
    game_gfx_draw_point(game, pt.x, pt.y, color);
}

fn calc_step(p1: GamePoint, p2: GamePoint, dy: *u16) u32 {
    dy.* = @intCast(p2.y - p1.y);
    const delta: u16 = if (dy.* <= 1) 1 else dy.*;
    // TODO: check this
    return @bitCast(@as(i32, @intCast(p2.x - p1.x)) * @as(i32, @intCast(0x4000 / delta)) << 2);
}

fn draw_line_p(game: *Game, x1: i16, x2: i16, y: i16, _: u8) void {
    if (game.gfx.draw_page == 0) {
        return;
    }
    const xmax = @as(i32, @intCast(@max(x1, x2)));
    const xmin = @as(i32, @intCast(@min(x1, x2)));
    const w: i32 = xmax - xmin + 1;
    const offset = (@as(i32, @intCast(y)) * GAME_WIDTH + xmin);
    std.mem.copyForwards(u8, game.gfx.fbs[game.gfx.draw_page].buffer[@intCast(offset)..][0..@intCast(w)], game.gfx.fbs[0].buffer[@intCast(offset)..][0..@intCast(w)]);
}

fn draw_line_n(game: *Game, x1: i16, x2: i16, y: i16, color: u8) void {
    const xmax = @as(i32, @intCast(@max(x1, x2)));
    const xmin = @as(i32, @intCast(@min(x1, x2)));
    const w: i32 = xmax - xmin + 1;
    const offset = (@as(i32, @intCast(y)) * GAME_WIDTH + xmin);
    @memset(game.gfx.fbs[game.gfx.draw_page].buffer[@intCast(offset)..@intCast(offset + w)], color);
}

fn draw_line_trans(game: *Game, x1: i16, x2: i16, y: i16, _: u8) void {
    const xmax = @max(x1, x2);
    const xmin = @min(x1, x2);
    const w: usize = @intCast(xmax - xmin + 1);
    const offset: usize = (@as(usize, @intCast(y)) * GAME_WIDTH + @as(usize, @intCast(xmin)));
    for (0..w) |i| {
        game.gfx.fbs[game.gfx.draw_page].buffer[offset + i] |= 8;
    }
}

fn game_gfx_draw_bitmap(game: *Game, page: u2, data: []const u8, w: u16, h: u16, fmt: GameGfxFormat) void {
    if (fmt == .clut and GAME_WIDTH == w and GAME_HEIGHT == h) {
        @memcpy(game_gfx_get_page_ptr(game, page)[0 .. w * h], data);
        return;
    }
    unreachable;
}

fn game_gfx_draw_polygon(game: *Game, color: u8, quad_strip: *const GameQuadStrip) void {
    const qs = quad_strip;

    var i: usize = 0;
    var j: usize = qs.num_vertices - 1;

    var x2: i16 = qs.vertices[i].x;
    var x1: i16 = qs.vertices[j].x;
    var hliney: i16 = @min(qs.vertices[i].y, qs.vertices[j].y);

    i += 1;
    j -= 1;

    const draw_func = switch (color) {
        _GFX_COL_PAGE => &draw_line_p,
        _GFX_COL_ALPHA => &draw_line_trans,
        else => &draw_line_n,
    };

    var cpt1: u32 = @as(u32, @intCast(@as(u16, @bitCast(x1)))) << 16;
    var cpt2: u32 = @as(u32, @intCast(@as(u16, @bitCast(x2)))) << 16;

    var num_vertices = qs.num_vertices;
    while (true) {
        num_vertices -= 2;
        if (num_vertices == 0) {
            return;
        }
        var h: u16 = undefined;
        const step1 = calc_step(qs.vertices[j + 1], qs.vertices[j], &h);
        const step2 = calc_step(qs.vertices[i - 1], qs.vertices[i], &h);

        i += 1;
        j -= 1;

        cpt1 = (cpt1 & 0xFFFF0000) | 0x7FFF;
        cpt2 = (cpt2 & 0xFFFF0000) | 0x8000;

        if (h == 0) {
            cpt1 +%= step1;
            cpt2 +%= step2;
        } else {
            for (0..h) |_| {
                if (hliney >= 0) {
                    x1 = @bitCast(@as(u16, @truncate(cpt1 >> 16)));
                    x2 = @bitCast(@as(u16, @truncate(cpt2 >> 16)));
                    if (x1 < GAME_WIDTH and x2 >= 0) {
                        if (x1 < 0) x1 = 0;
                        if (x2 >= GAME_WIDTH) x2 = GAME_WIDTH - 1;
                        draw_func(game, x1, x2, hliney, color);
                    }
                }
                cpt1 +%= step1;
                cpt2 +%= step2;
                hliney += 1;
                if (hliney >= GAME_HEIGHT) return;
            }
        }
    }
}

fn game_gfx_draw_quad_strip(game: *Game, buffer: u2, color: u8, qs: *const GameQuadStrip) void {
    game_gfx_set_work_page_ptr(game, buffer);
    game_gfx_draw_polygon(game, color, qs);
}

fn game_res_read_entries(game: *Game) !void {
    switch (game.res.data_type) {
        // TODO:
        // case DT_AMIGA:
        // case DT_ATARI:
        // 	GAME_ASSERT(game.res.num_mem_list>0);
        // 	return;
        .dos => {
            game.res.has_password_screen = false; // DOS demo versions do not have the resources
            var stream = std.io.fixedBufferStream(game.res.data.mem_list);
            var reader = stream.reader();
            while (true) {
                //GAME_ASSERT(game.res.num_mem_list < _ARRAYSIZE(game.res.mem_list));
                var me = &game.res.mem_list[game.res.num_mem_list];
                me.status = @enumFromInt(try reader.readByte());
                if (me.status == .uninit) {
                    game.res.has_password_screen = game.res.data.banks.bank08 != null;
                    return;
                }
                me.type = @enumFromInt(try reader.readByte());
                me.buf_ptr = &[0]u8{};
                _ = try reader.readInt(u32, .big);
                me.rank_num = try reader.readByte();
                me.bank_num = try reader.readByte();
                me.bank_pos = try reader.readInt(u32, .big);
                me.packed_size = try reader.readInt(u32, .big);
                me.unpacked_size = try reader.readInt(u32, .big);
                game.res.num_mem_list += 1;
            }
        },
        else => unreachable,
    }
}

fn game_res_invalidate(game: *Game) void {
    for (&game.res.mem_list) |*me| {
        if (@intFromEnum(me.type) <= 2 or @intFromEnum(me.type) > 6) {
            me.*.status = .null;
        }
    }
    game.res.script_cur = game.res.script_bak;
    game.video.current_pal = 0xFF;
}

fn mix_i16(sample1: i32, sample2: i32) i16 {
    const sample: i32 = sample1 + sample2;
    return @truncate(if (sample < -32768) -32768 else (if (sample > 32767) 32767 else sample));
}

fn to_raw_i16(a: i32) i16 {
    return @truncate(((a << 8) | a) - 32768);
}

fn to_i16(a: i32) i16 {
    if (a <= -128) {
        return -32768;
    }
    if (a >= 127) {
        return 32767;
    }
    return @intCast(@as(i16, @truncate(a)));
}

fn read_be_uint16(buf: []const u8) u16 {
    return std.mem.readInt(u16, buf[0..2], .big);
}

fn gameAudioInit(game: *Game, callback: GameAudioCallback) void {
    game.audio.callback = callback;
}

fn gameAudioSfxStart(game: *Game) void {
    std.log.debug("SfxPlayer::start()", .{});
    game.audio.sfx_player.sfx_mod.cur_pos = 0;
}

fn gameAudioSfxSetEventsDelay(game: *Game, delay: u16) void {
    std.log.debug("SfxPlayer::setEventsDelay({})", .{delay});
    game.audio.sfx_player.delay = delay;
}

fn gameAudioStopSound(game: *Game, channel: u8) void {
    std.log.debug("Mixer::stopChannel({})", .{channel});
    game.audio.channels[channel].data = null;
}

fn gamePlaySfxMusic(game: *Game) void {
    gameAudioSfxPlay(game, GAME_MIX_FREQ);
}

fn gameAudioSfxPlay(game: *Game, rate: i32) void {
    var player = &game.audio.sfx_player;
    player.playing = true;
    player.rate = rate;
    player.samples_left = 0;
}

fn gameAudioInitRaw(chan: *GameAudioChannel, data: []const u8, freq: i32, volume: i32, mixingFreq: i32) void {
    chan.data = data[8..];
    frac_reset(&chan.pos, freq, mixingFreq);

    const len = std.mem.readInt(u16, data[0..2], .big) * 2;
    chan.loop_len = std.mem.readInt(u16, data[2..4], .big) * 2;
    chan.loop_pos = if (chan.loop_len > 0) len else 0;
    chan.len = len;

    chan.volume = volume;
}

fn gameAudioSfxPrepareInstruments(game: *Game, buf: []const u8) void {
    var p = buf;
    var player = &game.audio.sfx_player;
    for (&player.sfx_mod.samples, 0..) |*ins, i| {
        const res_num = std.mem.readInt(u16, p[0..2], .big);
        p = p[2..];
        if (res_num != 0) {
            ins.volume = std.mem.readInt(u16, p[0..2], .big);
            const me = &game.res.mem_list[res_num];
            if (me.status == .loaded and me.type == .sound) {
                ins.data = me.buf_ptr;
                std.log.debug("Loaded instrument 0x{X:0>2} n={} volume={}", .{ res_num, i, ins.volume });
            } else {
                std.log.err("Error loading instrument 0x{X:0>2}", .{res_num});
            }
        }
        p = p[2..]; // skip volume
    }
}

fn gameAudioSfxLoadModule(game: *Game, resNum: u16, delay: u16, pos: u8) void {
    std.log.debug("SfxPlayer::loadSfxModule(0x{X:0>2}, {}, {})", .{ resNum, delay, pos });
    var player = &game.audio.sfx_player;
    var me = &game.res.mem_list[resNum];
    if (me.status == .loaded and me.type == .music) {
        //@memset(&player.sfx_mod, 0, sizeof(game_audio_sfx_module_t));
        player.sfx_mod.cur_order = pos;
        player.sfx_mod.num_order = me.buf_ptr[0x3F];
        std.log.debug("SfxPlayer::loadSfxModule() curOrder = 0x{X} numOrder = 0x{X}", .{ player.sfx_mod.cur_order, player.sfx_mod.num_order });
        player.sfx_mod.order_table = me.buf_ptr[0x40..];
        if (delay == 0) {
            player.delay = std.mem.readInt(u16, me.buf_ptr[0..2], .big);
        } else {
            player.delay = delay;
        }
        player.sfx_mod.data = me.buf_ptr[0xC0..];
        std.log.debug("SfxPlayer::loadSfxModule() eventDelay = {} ms", .{player.delay});
        gameAudioSfxPrepareInstruments(game, me.buf_ptr[2..]);
    } else {
        std.log.warn("SfxPlayer::loadSfxModule() ec=0xF8", .{});
    }
}

fn getSoundFreq(period: u8) i32 {
    return @divTrunc(GAME_PAULA_FREQ, @as(i32, @intCast(period_table[period] * 2)));
}

fn gameAudioPlaySoundRaw(game: *Game, channel: u8, data: []const u8, freq: i32, volume: u8) void {
    const chan = &game.audio.channels[channel];
    gameAudioInitRaw(chan, data, freq, volume, GAME_MIX_FREQ);
}

fn gameAudioStopSfxMusic(game: *Game) void {
    std.log.debug("SfxPlayer::stop()", .{});
    game.audio.sfx_player.playing = false;
}

fn gameAudioStopAll(game: *Game) void {
    for (0..GAME_MIX_CHANNELS) |i| {
        gameAudioStopSound(game, @intCast(i));
    }
    gameAudioStopSfxMusic(game);
}

fn gameAudioMixRaw(chan: *GameAudioChannel, sample: *i16) void {
    if (chan.data) |data| {
        var pos = frac_get_int(chan.pos);
        chan.pos.offset += chan.pos.inc;
        if (chan.loop_len != 0) {
            if (pos >= chan.loop_pos + chan.loop_len) {
                pos = chan.loop_pos;
                chan.pos.offset = (chan.loop_pos << _GAME_FRAC_BITS) + chan.pos.inc;
            }
        } else {
            if (pos >= chan.len) {
                chan.data = null;
                return;
            }
        }
        sample.* = mix_i16(sample.*, @divTrunc(to_raw_i16(data[pos] ^ 0x80) * chan.volume, 64));
    }
}

fn gameAudioMixChannels(game: *Game, samples: []i16, count: i32) void {
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
        var i: usize = 0;
        while (i < count) : (i += 2) {
            for (0..GAME_MIX_CHANNELS) |j| {
                gameAudioMixRaw(&game.audio.channels[j], &samples[i]);
            }
            samples[i + 1] = samples[i];
        }
    }
}

fn gameAudioSfxHandlePattern(game: *Game, channel: u8, data: []const u8) void {
    var player = &game.audio.sfx_player;
    var pat = std.mem.zeroes(GameAudioSfxPattern);
    pat.note_1 = read_be_uint16(data);
    pat.note_2 = read_be_uint16(data[2..]);
    if (pat.note_1 != 0xFFFD) {
        const sample: u16 = (pat.note_2 & 0xF000) >> 12;
        if (sample != 0) {
            const ptr = player.sfx_mod.samples[sample - 1].data;
            if (ptr.len > 0) {
                std.log.debug("SfxPlayer::handlePattern() preparing sample {}", .{sample});
                pat.sample_volume = player.sfx_mod.samples[sample - 1].volume;
                pat.sample_start = 8;
                pat.sample_buffer = ptr;
                pat.sample_len = read_be_uint16(ptr) *% 2;
                const loopLen: u16 = read_be_uint16(ptr[2..]) * 2;
                if (loopLen != 0) {
                    pat.loop_pos = pat.sample_len;
                    pat.loop_len = loopLen;
                } else {
                    pat.loop_pos = 0;
                    pat.loop_len = 0;
                }
                var m: i16 = @bitCast(pat.sample_volume);
                const effect: u8 = @truncate((@as(u16, @intCast(pat.note_2)) & 0x0F00) >> 8);
                if (effect == 5) { // volume up
                    const volume: u8 = @truncate(pat.note_2 & 0xFF);
                    m += volume;
                    if (m > 0x3F) {
                        m = 0x3F;
                    }
                } else if (effect == 6) { // volume down
                    const volume: u8 = @truncate(pat.note_2 & 0xFF);
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
        std.log.debug("SfxPlayer::handlePattern() _syncVar = 0x{X}", .{pat.note_2});
        game.vm.vars[GAME_VAR_MUSIC_SYNC] = @bitCast(pat.note_2);
    } else if (pat.note_1 == 0xFFFE) {
        player.channels[channel].sample_len = 0;
    } else if (pat.note_1 != 0 and pat.sample_buffer != null) {
        //GAME_ASSERT(pat.note_1 >= 0x37 and pat.note_1 < 0x1000);
        // convert Amiga period value to hz
        const freq: i32 = @divTrunc(GAME_PAULA_FREQ, (pat.note_1 * 2));
        std.log.debug("SfxPlayer::handlePattern() adding sample freq = 0x{X}", .{freq});
        var ch = &player.channels[channel];
        ch.sample_data = pat.sample_buffer.?[pat.sample_start..];
        ch.sample_len = pat.sample_len;
        ch.sample_loop_pos = pat.loop_pos;
        ch.sample_loop_len = pat.loop_len;
        ch.volume = pat.sample_volume;
        ch.pos.offset = 0;
        ch.pos.inc = @bitCast(@divTrunc((freq << _GAME_FRAC_BITS), player.rate));
    }
}

fn gameAudioSfxHandleEvents(game: *Game) void {
    var player = &game.audio.sfx_player;
    var order: usize = player.sfx_mod.order_table[player.sfx_mod.cur_order];
    var patternData = player.sfx_mod.data[player.sfx_mod.cur_pos + order * 1024 ..];
    for (0..4) |ch| {
        gameAudioSfxHandlePattern(game, @truncate(ch), patternData);
        patternData = patternData[4..];
    }
    player.sfx_mod.cur_pos += 4 * 4;
    std.log.debug("SfxPlayer::handleEvents() order = 0x{X} curPos = 0x{X}", .{ order, player.sfx_mod.cur_pos });
    if (player.sfx_mod.cur_pos >= 1024) {
        player.sfx_mod.cur_pos = 0;
        order = player.sfx_mod.cur_order +% 1;
        if (order == player.sfx_mod.num_order) {
            player.playing = false;
        }
        player.sfx_mod.cur_order = @truncate(order);
    }
}

fn gameAudioSfxMixChannel(s: *i16, ch: *GameAudioSfxChannel) void {
    if (ch.sample_len == 0) {
        return;
    }
    const pos1: i32 = @bitCast(@as(u32, @truncate(ch.pos.offset >> _GAME_FRAC_BITS)));
    ch.pos.offset += ch.pos.inc;
    var pos2: i32 = pos1 + 1;
    if (ch.sample_loop_len != 0) {
        if (pos1 >= ch.sample_loop_pos + ch.sample_loop_len - 1) {
            pos2 = ch.sample_loop_pos;
            ch.pos.offset = @as(u64, @intCast(pos2)) << _GAME_FRAC_BITS;
        }
    } else {
        if (pos1 >= ch.sample_len - 1) {
            ch.sample_len = 0;
            return;
        }
    }
    var sample: i32 = frac_interpolate(ch.pos, @as(i8, @bitCast(ch.sample_data[@intCast(pos1)])), @as(i8, @bitCast(ch.sample_data[@intCast(pos2)])));
    sample = s.* +% to_i16(@divTrunc(sample * ch.volume, 64));
    s.* = (if (sample < -32768) -32768 else (if (sample > 32767) 32767 else @truncate(sample)));
}

fn gameAudioSfxMixSamples(game: *Game, buffer: []i16) void {
    var buf = buffer;
    var player = &game.audio.sfx_player;
    while (buf.len > 1) {
        if (player.samples_left == 0) {
            gameAudioSfxHandleEvents(game);
            const samplesPerTick = @divTrunc(player.rate * @divTrunc(@as(i32, @intCast(player.delay)) * 60 * 1000, GAME_PAULA_FREQ), 1000);
            player.samples_left = samplesPerTick;
        }
        var count = player.samples_left;
        if (count > @as(i32, @intCast(buf.len / 2))) {
            count = @intCast(buf.len / 2);
        }
        player.samples_left -= count;
        for (0..@intCast(count)) |_| {
            gameAudioSfxMixChannel(&buf[0], &player.channels[0]);
            gameAudioSfxMixChannel(&buf[0], &player.channels[3]);
            gameAudioSfxMixChannel(&buf[1], &player.channels[1]);
            gameAudioSfxMixChannel(&buf[1], &player.channels[2]);
            buf = buf[2..];
        }
    }
}

fn gameAudioSfxReadSamples(game: *Game, buf: []i16, len: isize) void {
    const player = &game.audio.sfx_player;
    if (player.delay != 0) {
        gameAudioSfxMixSamples(game, buf[0..@intCast(@divTrunc(len, 2))]);
    }
}

fn gameAudioUpdate(game: *Game, num_samples: i32) void {
    // GAME_ASSERT(num_samples < GAME_MIX_BUF_SIZE);
    // GAME_ASSERT(num_samples < GAME_MAX_AUDIO_SAMPLES);
    @memset(&game.audio.samples, 0);
    gameAudioMixChannels(game, &game.audio.samples, num_samples);
    gameAudioSfxReadSamples(game, &game.audio.samples, num_samples);
    for (0..@intCast(num_samples)) |i| {
        game.audio.sample_buffer[i] = ((@as(f32, @floatFromInt(game.audio.samples[i])) + 32768) / 32768) - 1;
    }
    if (game.audio.callback) |cb| {
        cb(&game.audio.sample_buffer);
    }
}

fn sndPlaySound(game: *Game, resNum: u16, frequency: u8, volume: u8, channel: u8) void {
    var vol = volume;
    var freq = frequency;
    var chan = channel;
    std.log.debug("snd_playSound(0x{X:0>2}, {}, {}, {})", .{ resNum, freq, vol, chan });
    if (vol == 0) {
        gameAudioStopSound(game, chan);
        return;
    }
    if (vol > 63) {
        vol = 63;
    }
    if (freq > 39) {
        freq = 39;
    }
    chan &= 3;
    const me = &game.res.mem_list[resNum];
    if (me.status == .loaded) {
        gameAudioPlaySoundRaw(game, chan, me.buf_ptr, getSoundFreq(freq), vol);
    }
}

const UnpackContext = struct {
    size: isize,
    crc: u32,
    bits: u32,
    dst_buf: []u8,
    dst_i: isize,
    src_buf: []const u8,
    src_i: isize,
};

fn next_bit(uc: *UnpackContext) bool {
    var carry = (uc.bits & 1) != 0;
    uc.bits >>= 1;
    if (uc.bits == 0) { // getnextlwd
        uc.bits = std.mem.readInt(u32, uc.src_buf[@intCast(uc.src_i)..][0..4], .big);
        uc.src_i -= 4;
        uc.crc ^= uc.bits;
        carry = (uc.bits & 1) != 0;
        uc.bits = (1 << 31) | (uc.bits >> 1);
    }
    return carry;
}

fn get_bits(uc: *UnpackContext, count: isize) i32 { // rdd1bits
    var bits: i32 = 0;
    for (0..@intCast(count)) |_| {
        bits <<= 1;
        if (next_bit(uc)) {
            bits |= 1;
        }
    }
    return bits;
}

fn copy_literal(uc: *UnpackContext, bits_count: isize, len: i32) void { // getd3chr
    var count: isize = @intCast(get_bits(uc, bits_count) + len + 1);
    uc.size -= count;
    if (uc.size < 0) {
        count += uc.size;
        uc.size = 0;
    }
    for (0..@intCast(count)) |i| {
        uc.dst_buf[@as(usize, @intCast(uc.dst_i)) - i] = @intCast(get_bits(uc, 8));
    }
    uc.dst_i -= count;
}

fn copy_reference(uc: *UnpackContext, bits_count: isize, count: isize) void { // copyd3bytes
    var c = count;
    uc.size -= c;
    if (uc.size < 0) {
        c += uc.size;
        uc.size = 0;
    }
    const offset: usize = @intCast(get_bits(uc, bits_count));
    for (0..@intCast(c)) |i| {
        uc.dst_buf[@as(usize, @intCast(uc.dst_i)) - i] = uc.dst_buf[@as(usize, @intCast(uc.dst_i)) - i + offset];
    }
    uc.dst_i -= c;
}

fn byte_killer_unpack(dst: []u8, src: []const u8) bool {
    var uc = UnpackContext{
        .src_buf = src,
        .src_i = @intCast(src.len - 8),
        .size = std.mem.readInt(u32, src[src.len - 4 ..][0..4], .big),
        .dst_buf = dst,
        .dst_i = 0,
        .crc = 0,
        .bits = 0,
    };
    if (uc.size > dst.len) {
        std.log.warn("Unexpected unpack size {}, buffer size {}", .{ uc.size, dst.len });
        return false;
    }
    uc.dst_i = uc.size - 1;
    uc.crc = std.mem.readInt(u32, src[@intCast(uc.src_i)..][0..4], .big);
    uc.src_i -= 4;
    uc.bits = std.mem.readInt(u32, src[@intCast(uc.src_i)..][0..4], .big);
    uc.src_i -= 4;
    uc.crc ^= uc.bits;
    while (uc.size > 0) {
        if (!next_bit(&uc)) {
            if (!next_bit(&uc)) {
                copy_literal(&uc, 3, 0);
            } else {
                copy_reference(&uc, 8, 2);
            }
        } else {
            const code = get_bits(&uc, 2);
            switch (code) {
                3 => copy_literal(&uc, 8, 8),
                2 => copy_reference(&uc, 12, @intCast(get_bits(&uc, 8) + 1)),
                1 => copy_reference(&uc, 10, 4),
                0 => copy_reference(&uc, 9, 3),
                else => unreachable,
            }
        }
    }
    assert(uc.size == 0);
    return uc.crc == 0;
}

fn fetch_byte(pc: *GamePc) u8 {
    const res = pc.data[pc.pc];
    pc.pc += 1;
    return res;
}

fn fetch_word(pc: *GamePc) u16 {
    const res = std.mem.readInt(u16, pc.data[pc.pc..][0..2], .big);
    pc.pc += 2;
    return res;
}

fn op_mov_const(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const n = fetch_word(&game.vm.ptr);
    std.log.debug("Script::op_movConst(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(n);
}

fn op_mov(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const j = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_mov(0x{X}, 0x{X})", .{ i, j });
    game.vm.vars[i] = game.vm.vars[j];
}

fn op_add(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const j = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_add(0x{X}, 0x{X})", .{ i, j });
    game.vm.vars[i] +%= game.vm.vars[j];
}

fn op_add_const(game: *Game) void {
    if (game.res.data_type == .dos or game.res.data_type == .amiga or game.res.data_type == .atari) {
        if (game.res.current_part == .luxe and game.vm.ptr.pc == 0x6D48) {
            std.log.warn("Script::op_addConst() workaround for infinite looping gun sound", .{});
            // The script 0x27 slot 0x17 doesn't stop the gun sound from looping.
            // This is a bug in the original game code, confirmed by Eric Chahi and
            // addressed with the anniversary editions.
            // For older releases (DOS, Amiga), we play the 'stop' sound like it is
            // done in other part of the game code.
            //
            //  6D43: jmp(0x6CE5)
            //  6D46: break
            //  6D47: VAR(0x06) -= 50
            //
            sndPlaySound(game, 0x5B, 1, 64, 1);
        }
    }
    const i = fetch_byte(&game.vm.ptr);
    const n: i16 = @bitCast(fetch_word(&game.vm.ptr));
    std.log.debug("Script::op_addConst(0x{X}, {})", .{ i, n });
    game.vm.vars[i] += n;
}

fn op_call(game: *Game) void {
    const off = fetch_word(&game.vm.ptr);
    std.log.debug("Script::op_call(0x{X})", .{off});
    if (game.vm.stack_ptr == 0x40) {
        std.log.err("Script::op_call() ec=0x8F stack overflow", .{});
    }
    game.vm.stack_calls[game.vm.stack_ptr] = game.vm.ptr.pc;
    game.vm.stack_ptr += 1;
    game.vm.ptr.pc = off;
}

fn op_ret(game: *Game) void {
    std.log.debug("Script::op_ret()", .{});
    if (game.vm.stack_ptr == 0) {
        std.log.err("Script::op_ret() ec=0x8F stack underflow", .{});
    }
    game.vm.stack_ptr -= 1;
    game.vm.ptr.pc = game.vm.stack_calls[game.vm.stack_ptr];
}

fn op_yield_task(game: *Game) void {
    std.log.debug("Script::op_yieldTask()", .{});
    game.vm.paused = true;
}

fn op_jmp(game: *Game) void {
    const off = fetch_word(&game.vm.ptr);
    std.log.debug("Script::op_jmp(0x{X})", .{off});
    game.vm.ptr.pc = off;
}

fn op_install_task(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const n = fetch_word(&game.vm.ptr);
    std.log.debug("Script::op_installTask(0x{X}, 0x{X})", .{ i, n });
    //GAME_ASSERT(i < GAME_NUM_TASKS);
    game.vm.tasks[i].next_pc = n;
}

fn op_jmp_if_var(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_jmpIfVar(0x{X})", .{i});
    game.vm.vars[i] -= 1;
    if (game.vm.vars[i] != 0) {
        op_jmp(game);
    } else {
        _ = fetch_word(&game.vm.ptr);
    }
}

fn fixup_palette_change_screen(game: *Game, part: GamePart, screen: i32) void {
    var pal: ?u8 = null;
    switch (part) {
        .cite => if (screen == 0x47) { // bitmap resource #68
            pal = 8;
        },
        .luxe => if (screen == 0x4A) { // bitmap resources #144, #145
            pal = 1;
        },
        else => {},
    }
    if (pal) |p| {
        std.log.debug("Setting palette {} for part {} screen {}", .{ p, part, screen });
        game_video_change_pal(game, p);
    }
}

fn op_cond_jmp(game: *Game) void {
    const op = fetch_byte(&game.vm.ptr);
    const variable = fetch_byte(&game.vm.ptr);
    const b = game.vm.vars[variable];
    var a: i16 = undefined;
    if ((op & 0x80) != 0) {
        a = game.vm.vars[fetch_byte(&game.vm.ptr)];
    } else if ((op & 0x40) != 0) {
        a = @bitCast(fetch_word(&game.vm.ptr));
    } else {
        a = @intCast(fetch_byte(&game.vm.ptr));
    }
    std.log.debug("Script::op_condJmp({}, 0x{X}, 0x{X}) var=0x{X}", .{ op, b, a, variable });
    var expr = false;
    switch (op & 7) {
        0 => {
            expr = (b == a);
            if (!game.enable_protection) {
                if (game.res.current_part == .copy_protection) {
                    //
                    // 0CB8: jmpIf(VAR(0x29) == VAR(0x1E), @0CD3)
                    // ...
                    //
                    if (variable == 0x29 and (op & 0x80) != 0) {
                        // 4 symbols
                        game.vm.vars[0x29] = game.vm.vars[0x1E];
                        game.vm.vars[0x2A] = game.vm.vars[0x1F];
                        game.vm.vars[0x2B] = game.vm.vars[0x20];
                        game.vm.vars[0x2C] = game.vm.vars[0x21];
                        // counters
                        game.vm.vars[0x32] = 6;
                        game.vm.vars[0x64] = 20;
                        std.log.warn("Script::op_condJmp() bypassing protection", .{});
                        expr = true;
                    }
                }
            }
        },
        1 => expr = (b != a),
        2 => expr = (b > a),
        3 => expr = (b >= a),
        4 => expr = (b < a),
        5 => expr = (b <= a),
        else => std.log.warn("Script::op_condJmp() invalid condition {}", .{op & 7}),
    }
    if (expr) {
        op_jmp(game);
        if (variable == GAME_VAR_SCREEN_NUM and game.vm.screen_num != game.vm.vars[GAME_VAR_SCREEN_NUM]) {
            fixup_palette_change_screen(game, game.res.current_part, game.vm.vars[GAME_VAR_SCREEN_NUM]);
            game.vm.screen_num = game.vm.vars[GAME_VAR_SCREEN_NUM];
        }
    } else {
        _ = fetch_word(&game.vm.ptr);
    }
}

fn op_set_palette(game: *Game) void {
    const i = fetch_word(&game.vm.ptr);
    std.log.debug("Script::op_changePalette({})", .{i});
    const num = i >> 8;
    if (game.gfx.fix_up_palette) {
        if (game.res.current_part == .intro) {
            if (num == 10 or num == 16) {
                return;
            }
        }
        game.video.next_pal = @intCast(num);
    } else {
        game.video.next_pal = @intCast(num);
    }
}

fn op_change_tasks_state(game: *Game) void {
    const start = fetch_byte(&game.vm.ptr);
    const end = fetch_byte(&game.vm.ptr);
    if (end < start) {
        std.log.warn("Script::op_changeTasksState() ec=0x880 (end < start)", .{});
        return;
    }
    const state = fetch_byte(&game.vm.ptr);

    std.log.debug("Script::op_changeTasksState({}, {}, {})", .{ start, end, state });

    if (state == 2) {
        for (start..end + 1) |i| {
            game.vm.tasks[i].next_pc = _GAME_INACTIVE_TASK - 1;
        }
    } else if (state < 2) {
        for (start..end + 1) |i| {
            game.vm.tasks[i].next_state = state;
        }
    }
}

fn op_selectPage(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_selectPage({})", .{i});
    game_video_set_work_page_ptr(game, i);
}

fn op_fill_page(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const color = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_fillPage({}, {})", .{ i, color });
    game_video_fill_page(game, i, color);
}

fn op_copy_page(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const j = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_copyPage({}, {})", .{ i, j });
    game_video_copy_page(game, i, j, game.vm.vars[GAME_VAR_SCROLL_Y]);
}

fn inp_handle_special_keys(game: *Game) void {
    if (game.input.pause) {
        if (game.res.current_part != .copy_protection and game.res.current_part != .intro) {
            game.input.pause = false;
        }
        game.input.pause = false;
    }
    if (game.input.back) {
        game.input.back = false;
    }
    if (game.input.code) {
        game.input.code = false;
        if (game.res.has_password_screen) {
            if (game.res.current_part != .password and game.res.current_part != .copy_protection) {
                game.res.next_part = .password;
            }
        }
    }
}

fn op_update_display(game: *Game) void {
    const page = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_updateDisplay({})", .{page});
    inp_handle_special_keys(game);

    if (game.enable_protection) {
        // entered protection symbols match the expected values
        if (game.res.current_part == .copy_protection and game.vm.vars[0x67] == 1) {
            game.vm.vars[0xDC] = 33;
        }
    }

    const frame_hz: i32 = 50;
    if (game.vm.vars[GAME_VAR_PAUSE_SLICES] != 0) {
        const delay: i32 = @as(i32, @intCast(game.elapsed)) - @as(i32, @intCast(game.vm.time_stamp));
        const pause = @divTrunc(@as(i32, @intCast(game.vm.vars[GAME_VAR_PAUSE_SLICES])) * 1000, frame_hz) - delay;
        if (pause > 0) {
            game.sleep += @as(u32, @intCast(pause));
        }
    }
    game.vm.time_stamp = game.elapsed;
    game.vm.vars[0xF7] = 0;

    game_video_update_display(game, page);
}

fn op_remove_task(game: *Game) void {
    std.log.debug("Script::op_removeTask()", .{});
    game.vm.ptr.pc = 0xFFFF;
    game.vm.paused = true;
}

fn op_draw_string(game: *Game) void {
    const strId = fetch_word(&game.vm.ptr);
    const x: u16 = fetch_byte(&game.vm.ptr);
    const y: u16 = fetch_byte(&game.vm.ptr);
    const col: u16 = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_drawString(0x{X}, {}, {}, {})", .{ strId, x, y, col });
    game_video_draw_string(game, @truncate(col), x, y, strId);
}

fn op_sub(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const j = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_sub(0x{X}, 0x{X})", .{ i, j });
    game.vm.vars[i] -= game.vm.vars[j];
}

fn op_and(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const n: u16 = fetch_word(&game.vm.ptr);
    std.log.debug("Script::op_and(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(@as(u16, @bitCast(game.vm.vars[i])) & n);
}

fn op_or(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const n = fetch_word(&game.vm.ptr);
    std.log.debug("Script::op_or(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(@as(u16, @intCast(game.vm.vars[i])) | n);
}

fn op_shl(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const n: u4 = @intCast(fetch_word(&game.vm.ptr));
    std.log.debug("Script::op_shl(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(@as(u16, @intCast(game.vm.vars[i])) << n);
}

fn op_shr(game: *Game) void {
    const i = fetch_byte(&game.vm.ptr);
    const n: u4 = @intCast(fetch_word(&game.vm.ptr));
    std.log.debug("Script::op_shr(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(@as(u16, @intCast(game.vm.vars[i])) >> n);
}

fn op_play_sound(game: *Game) void {
    const res_num = fetch_word(&game.vm.ptr);
    const freq = fetch_byte(&game.vm.ptr);
    const vol = fetch_byte(&game.vm.ptr);
    const channel = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_playSound(0x{X}, {}, {}, {})", .{ res_num, freq, vol, channel });
    sndPlaySound(game, res_num, freq, vol, channel);
}

fn op_update_resources(game: *Game) void {
    const num = fetch_word(&game.vm.ptr);
    std.log.debug("Script::op_updateResources({})", .{num});
    if (num == 0) {
        gameAudioStopAll(game);
        game_res_invalidate(game);
    } else {
        game_res_update(game, num);
    }
}

fn snd_play_music(game: *Game, resNum: u16, delay: u16, pos: u8) void {
    std.log.debug("snd_playMusic(0x{X}, {}, {})", .{ resNum, delay, pos });
    // DT_AMIGA, DT_ATARI, DT_DOS
    if (resNum != 0) {
        gameAudioSfxLoadModule(game, resNum, delay, pos);
        gameAudioSfxStart(game);
        gamePlaySfxMusic(game);
    } else if (delay != 0) {
        gameAudioSfxSetEventsDelay(game, delay);
    } else {
        gameAudioStopSfxMusic(game);
    }
}

fn op_play_music(game: *Game) void {
    const res_num = fetch_word(&game.vm.ptr);
    const delay = fetch_word(&game.vm.ptr);
    const pos = fetch_byte(&game.vm.ptr);
    std.log.debug("Script::op_playMusic(0x{X}, {}, {})", .{ res_num, delay, pos });
    snd_play_music(game, res_num, delay, pos);
}

const OpFunc = *const fn (*Game) void;
const op_table = [_]OpFunc{
    // 0x00
    &op_mov_const,
    &op_mov,
    &op_add,
    &op_add_const,
    // 0x04
    &op_call,
    &op_ret,
    &op_yield_task,
    &op_jmp,
    // 0x08
    &op_install_task,
    &op_jmp_if_var,
    &op_cond_jmp,
    &op_set_palette,
    // 0x0C
    &op_change_tasks_state,
    &op_selectPage,
    &op_fill_page,
    &op_copy_page,
    // 0x10
    &op_update_display,
    &op_remove_task,
    &op_draw_string,
    &op_sub,
    // 0x14
    &op_and,
    &op_or,
    &op_shl,
    &op_shr,
    // 0x18
    &op_play_sound,
    &op_update_resources,
    &op_play_music,
};
