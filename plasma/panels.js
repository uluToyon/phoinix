// panels.js — the desktop's panel layout, built from scratch.
//
// Template: stage4.sh substitutes the @…@ placeholders and feeds this to
// plasmashell's scripting interface. Do not run it directly.
//
// Why rebuilt rather than patched: a fresh install starts with Plasma's own
// default panel, and repairing that into ulu's layout would mean guessing
// what state it is in. Removing every panel and building the intended ones
// is deterministic and gives the same result on a rebuilt machine as here.
//
// Screens are matched by GEOMETRY, never by index. Plasma numbers its
// screens in detection order, which is not stable across boots; stage 4
// resolves each connector (DP-1, HDMI-A-1, …) to its geometry via
// kscreen-doctor and passes it in here, so a panel always lands on the
// physical monitor it belongs to.

function screenFor(x, y, w, h) {
    for (var i = 0; i < screenCount; i++) {
        var g = screenGeometry(i);
        if (g.x === x && g.y === y && g.width === w && g.height === h) {
            return i;
        }
    }
    return -1;
}

var MAIN = screenFor(@MAIN_GEOM@);   // main monitor, ultrawide
var TV   = screenFor(@TV_GEOM@);     // television
var SIDE = [
    { screen: screenFor(@SIDE1_GEOM@), thickness: @SIDE1_THICKNESS@ },
    { screen: screenFor(@SIDE2_GEOM@), thickness: @SIDE2_THICKNESS@ }
];

var log = "";
if (MAIN < 0) { print("ERROR: main monitor not found — nothing changed"); }

// ------------------------------------------------------------------ helpers
function copyConfig(s, d, path) {
    s.currentConfigGroup = path;
    d.currentConfigGroup = path;
    var keys = s.configKeys;
    for (var i = 0; i < keys.length; i++) {
        d.writeConfig(keys[i], s.readConfig(keys[i]));
    }
    // Re-select: reading keys may have moved the cursor.
    s.currentConfigGroup = path;
    var groups = s.configGroups;
    for (var j = 0; j < groups.length; j++) {
        copyConfig(s, d, path.concat([groups[j]]));
    }
}

function fullWidth(panel, screen) {
    var g = screenGeometry(screen);
    panel.minimumLength = g.width;
    panel.maximumLength = g.width;
}

// ------------------------------------------------------------- clean slate
panels().forEach(function (p) { p.remove(); });

// ------------------------------------------------------------- main panel
var main = new Panel("org.kde.panel");
main.screen     = MAIN;
main.location   = "bottom";
main.height     = @MAIN_HEIGHT@;
main.floating   = false;
main.alignment  = "center";
main.lengthMode = "fill";
fullWidth(main, MAIN);

// Order matters — this is the left-to-right order in the panel.
["org.kde.plasma.kickoff",
 "org.kde.plasma.pager",
 "org.kde.plasma.icontasks",
 "org.kde.plasma.marginsseparator",
 "org.kde.plasma.systemtray",
 "org.kde.plasma.digitalclock",
 "org.kde.plasma.showdesktop"].forEach(function (type) {
    main.addWidget(type);
});

// Pinned launchers. Setting this explicitly also retires the applet's
// built-in default, which pins Discover — a package we never install, so it
// shows up as a broken generic icon.
main.widgets().forEach(function (w) {
    if (w.type.indexOf("icontasks") !== -1) {
        w.currentConfigGroup = ["General"];
        w.writeConfig("launchers", @LAUNCHERS@);
        w.reloadConfig();
        log += "main: launchers set\n";
    }
});

// ------------------------------------------------------------- TV = clone
// ulu's requirement: the TV mirrors the main panel, and later changes to the
// main panel must reach it too. Cloning from the live main panel — instead
// of listing its contents twice — is what keeps them from drifting apart.
if (TV >= 0) {
    var tv = new Panel("org.kde.panel");
    tv.screen     = TV;
    tv.location   = main.location;
    tv.height     = main.height;
    tv.floating   = main.floating;
    tv.alignment  = main.alignment;
    tv.lengthMode = main.lengthMode;
    fullWidth(tv, TV);   // its own width, not the ultrawide's

    main.widgets().forEach(function (w) {
        var nw = tv.addWidget(w.type);
        copyConfig(w, nw, []);
        nw.reloadConfig();
    });
    log += "tv: cloned " + main.widgets().length + " widgets\n";
} else {
    log += "tv: monitor not connected — skipped\n";
}

// ------------------------------------------------------------ side panels
// Clock-only strips on the remaining monitors: a spacer pushes the clock to
// the right edge.
SIDE.forEach(function (s, n) {
    if (s.screen < 0) { log += "side " + n + ": monitor not connected — skipped\n"; return; }
    var p = new Panel("org.kde.panel");
    p.screen   = s.screen;
    p.location = "bottom";
    p.height   = s.thickness;
    p.floating = false;
    p.addWidget("org.kde.plasma.panelspacer");
    p.addWidget("org.kde.plasma.digitalclock");
    log += "side " + n + ": panel on screen " + s.screen + " (h=" + s.thickness + ")\n";
});

print(log);
