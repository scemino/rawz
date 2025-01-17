const std = @import("std");
pub const GameLang = enum(u1) { fr, us };

strings_table: []const GameStrEntry,
lang: GameLang,
const Self = @This();

pub fn init(lang: GameLang) Self {
    return .{
        .strings_table = if (lang == .fr) &strings_table_fr else &strings_table_eng,
        .lang = lang,
    };
}

pub fn find(self: Self, id: u16) []const u8 {
    for (self.strings_table) |se| {
        if (se.id == id) return se.str;
    }
    for (strings_table_demo) |se| {
        if (se.id == id) return se.str;
    }
    std.log.warn("Unknown string id {}", .{id});
    return "";
}

const GameStrEntry = struct {
    id: u16,
    str: []const u8,
};

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
};

const strings_table_demo = [_]GameStrEntry{
    .{ .id = 0x1F4, .str = "Over Two Years in the Making" },
    .{ .id = 0x1F5, .str = "   A New, State\nof the Art, Polygon\n  Graphics System" },
    .{ .id = 0x1F6, .str = "   Comes to the\nComputer With Full\n Screen Graphics" },
    .{ .id = 0x1F7, .str = "While conducting a nuclear fission\nexperiment at your local\nparticle accelerator ..." },
    .{ .id = 0x1F8, .str = "Nature decides to put a little\n    extra spin on the ball" },
    .{ .id = 0x1F9, .str = "And sends you ..." },
    .{ .id = 0x1FA, .str = "     Out of this World\nA Cinematic Action Adventure\n from Interplay Productions\n                    \n       By Eric CHAHI      \n\n  IBM version : D.MORAIS\n" },
};
