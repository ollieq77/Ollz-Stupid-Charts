
import flixel.tweens.FlxTween;
public var disableGhosts:Bool = false;

var songName:FlxText;
var newScoreTxt:FunkinText;
var timeTxt:FlxText;

// Cached strings
var lastScoreStr:String = "";
var lastTimeStr:String = "";
var totalTimeStr:String = "0:00";

var iconBaseOffsetY:Float = 0;

// Ghost tracking
var data:Map<Int, {lastNote:{time:Float, id:Int}}> = [];
var ghosts:Array<Character> = [];

function formatNumber(n:Int):String {
    var neg = n < 0;
    var s = Std.string(if (neg) -n else n);
    var out = "";
    var len = s.length;

    for (i in 0...len) {
        var idx = len - 1 - i;
        out = s.charAt(idx) + out;

        if ((i + 1) % 3 == 0 && idx != 0) {
            out = "," + out;
        }
    }

    return (if (neg) "-" else "") + out;
}

function formatTime(ms:Float):String {
    var t:Int = Math.floor(Math.max(0, ms) / 1000);
    return Std.int(t / 60) + ":" + StringTools.lpad(Std.string(t % 60), "0", 2);
}

function setupIcon(icon:HealthIcon) {
    var isPlayer = icon.isPlayer;

    icon.bump = function() {
        var health = isPlayer
            ? (2 - healthBar.percent / 50)
            : (healthBar.percent / 50);

        icon.scale.set(1 + (1 - health / 2), icon.defaultScale);
    };

    icon.updateBump = function() {
        var lerp = Flags.ICON_LERP;

        icon.scale.set(
            CoolUtil.fpsLerp(icon.scale.x, icon.defaultScale, lerp),
            CoolUtil.fpsLerp(icon.scale.y, icon.defaultScale, lerp)
        );

        icon.updateHitbox();
        icon.y = healthBar.y - icon.height / 2
            - (icon.scale.x - 1) * 25;
    };
}

function postCreate() {
    // Initialise per-strum-line note history
    for (sl in strumLines.members) {
        data[strumLines.members.indexOf(sl)] = {
            lastNote: {
                time: -9999,
                id: -1
            }
        };
    }

    songName = new FlxText(0, 50, FlxG.width, curSong);
    songName.setFormat(
        Paths.font("vcr.ttf"), 24, FlxColor.WHITE, "center"
    );
    songName.cameras = [camHUD];
    add(songName);

    newScoreTxt = new FunkinText(
        0, scoreTxt.y, FlxG.width, "Score: 0"
    );
    newScoreTxt.setFormat(
        Paths.font("vcr.ttf"), 24, FlxColor.WHITE, "center"
    );
    newScoreTxt.cameras = [camHUD];
    add(newScoreTxt);

    timeTxt = new FlxText(
        0, songName.y + 50, FlxG.width, "0:00 - 0:00"
    );
    timeTxt.setFormat(
        Paths.font("vcr.ttf"), 32, FlxColor.WHITE, "center"
    );
    timeTxt.cameras = [camHUD];
    add(timeTxt);

    remove(scoreTxt);
    remove(accuracyTxt);
    remove(missesTxt);

    setupIcon(iconP1);
    setupIcon(iconP2);
}

function onSongStart() {
    totalTimeStr = formatTime(inst.length);
}

function onNoteHit(event:NoteHitEvent) {
    if (event.note.isSustainNote) {
        event.preventAnim();
        event.character.lastHit = Conductor.songPosition;

        event.preventStrumGlow();
        event.note.strumLine.members[event.direction].lastHit =
            Conductor.songPosition;

        return;
    }

    // Detect quick notes on different directions of the same strum line
    var lineID = strumLines.members.indexOf(event.note.strumLine);
    var target = data[lineID];

    if (target == null) return;

    var doDouble =
        (event.note.strumTime - target.lastNote.time) <= 2
        && event.note.noteData != target.lastNote.id;

    target.lastNote.time = event.note.strumTime;
    target.lastNote.id = event.note.noteData;

    if (doDouble && !disableGhosts) {
        for (character in event.characters) {
            if (character.visible) {
                doGhostAnim(character, event);
            }
        }
    }
}

function doGhostAnim(char:Character, event:NoteHitEvent) {
    // Random offset around the character
    var offsetX:Float = FlxG.random.float(-12, 12);
    var offsetY:Float = FlxG.random.float(-12, 12);

    var trail:Character = new Character(
        char.x + offsetX,
        char.y + offsetY,
        char.curCharacter,
        char.isPlayer
    );

    trail.color = char.iconColor;
    trail.alpha = char.alpha * 0.85;
    trail.scale.set(char.scale.x, char.scale.y);
    trail.flipX = char.flipX;
    trail.visible = char.visible;

    insert(members.indexOf(char), trail);

    trail.playAnim(char.getAnimName(), false, 'LOCK');

    // Fade out without moving
    FlxTween.tween(trail, {alpha: 0}, 0.3, {
        onComplete: function(_) {
            trail.kill();
            remove(trail, true);
            ghosts.remove(trail);
        }
    });

    trail.holdTime = 9999999;

    ghosts.push(trail);
    return trail;
}


function onPlayerHit(event:NoteHitEvent) {
    event.showRating = false;
}

function update(elapsed:Float) {
    var accuracyText =
        CoolUtil.quantize(Math.max(0, accuracy * 100), 100) + "%";

    var scoreStr = "Score: " + formatNumber(songScore)
        + " / Combo Breaks: " + formatNumber(misses)
        + " / Accuracy: " + accuracyText;

    if (scoreStr != lastScoreStr) {
        lastScoreStr = scoreStr;
        newScoreTxt.text = scoreStr;
    }

    var timeStr =
        formatTime(Conductor.songPosition) + " - " + totalTimeStr;

    if (timeStr != lastTimeStr) {
        lastTimeStr = timeStr;
        timeTxt.text = timeStr;
    }

    // Remove ghosts after their animations finish
    for (ghost in ghosts.copy()) {
        if (ghost.animation.curAnim != null
            && ghost.animation.curAnim.finished) {
            ghost.kill();
            remove(ghost, true);
            ghosts.remove(ghost);
        }
    }
}

function onStrumCreation(event:StrumCreationEvent) {
    event.cancelAnimation();
}
