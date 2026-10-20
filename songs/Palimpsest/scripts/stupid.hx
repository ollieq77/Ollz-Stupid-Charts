
var bumpDirection = 1;

var camBumpMode = 0; // 0 = off

var bumpModes = [
    // Mode 0: off
    { loopSteps: 1, hits: [] },

    // Mode 1: main pattern
    {
        loopSteps: 32,
        hits: [
            [0,  "bop",  1],
            [6,  "bop",  1],
            [8,  "bump", 1],
            [18, "bop",  1],
            [20, "bop",  1],
            [24, "bump", 1],
            [26, "bop",  1],
            [30, "bump", 1]
        ]
    },

    // Mode 2: gentler pattern
    {
        loopSteps: 4,
        hits: [
            [0,  "bop",  2],
        ]
    },

    {
        loopSteps: 8,
        hits: [
            [0,  "bop",  2],
            [4,  "bop",  1],
            [4,  "bump",  1],
        ]
    },

    {
        loopSteps: 16,
        hits: [
            [0,  "bop",  2],
            [4,  "bop",  1],
            [4,  "bump",  1],

            [10,  "bop",  2],
            [12,  "bop",  1],
            [12,  "bump",  1],
        ]
    }
];

function setBumpMode(m) {
    // Accepts either a number or a string from HScript
    var parsed = Std.parseInt(Std.string(m));

    if (parsed == null || parsed < 0 || parsed >= bumpModes.length)
        return;

    camBumpMode = parsed;
}

function bump(strength:Float) {
    var duration = 120 / Conductor.bpm;

    FlxTween.cancelTweensOf(camGame);
    camGame.angle = 5 * strength * bumpDirection;

    FlxTween.tween(camGame, {angle: 0}, duration, {
        ease: FlxEase.expoOut
    });

    for (strumLine in strumLines.members) {
        var count = strumLine.members.length;

        for (j in 0...count) {
            var strum = strumLine.members[j];
            if (strum == null) continue;

            // Remember the original resting Y position
            if (!strum.extra.exists("baseY"))
                strum.extra.set("baseY", strum.y);

            var baseY = strum.extra.get("baseY");

            FlxTween.cancelTweensOf(strum);

            var progress = (count <= 1) ? 0 : j / (count - 1);

            strum.y = baseY
                + (-40 + 80 * progress)
                * strength
                * bumpDirection;

            FlxTween.tween(strum, {y: baseY}, duration, {
                ease: FlxEase.expoOut
            });
        }
    }

    bumpDirection *= -1;
}

function postCreate() {
    camHUD.alpha = 0;
    camGame.visible = false;
}

function onSongStart() {
    FlxTween.tween(
        camHUD,
        {alpha: 1},
        (Conductor.crochet / 1000) * 30
    );
}

function beatHit(curBeat:Int) {
    if (curBeat == 31) {
        camHUD.alpha = 0;
    }

    if (curBeat == 32) {
        camHUD.alpha = 1;
        camGame.visible = true;
    }
}

function stepHit(curStep:Int) {
    var mode = bumpModes[camBumpMode];
    if (mode == null) return;

    var s = curStep % mode.loopSteps;

    for (hit in mode.hits) {
        if (hit[0] != s) continue;

        if (hit[1] == "bop") {
            executeEvent({
                name: "Camera Bop",
                time: 0,
                params: [hit[2]]
            });
        }
        else if (hit[1] == "bump") {
            bump(hit[2]);
        }
    }
}
