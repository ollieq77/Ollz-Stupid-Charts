
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

var bfShader:CustomShader;
var dadShader:CustomShader;
var gfShader:CustomShader;

var shaderTweens:Map<String, FlxTween> = [];
var worldTweens:Map<String, FlxTween> = [];
var iconTweens:Map<String, FlxTween> = [];

var originalColours:Map<String, FlxColor> = [];
var originalIconColours:Map<String, Null<FlxColor>> = [];

function create()
{
    bfShader = new CustomShader("twoColour");
    dadShader = new CustomShader("twoColour");
    gfShader = new CustomShader("twoColour");

    for (shader in [bfShader, dadShader, gfShader])
        shader.intensity = 0.0;
}

function setupCharacterShader(character:Dynamic, shader:CustomShader)
{
    if (character == null)
        return;

    var colour:FlxColor = character.iconColor == null
        ? FlxColor.WHITE
        : character.iconColor;

    shader.replacementColor = [
        ((colour >> 16) & 0xFF) / 255.0,
        ((colour >> 8) & 0xFF) / 255.0,
        (colour & 0xFF) / 255.0
    ];

    character.shader = shader;
}

function postCreate()
{
    setupCharacterShader(boyfriend, bfShader);
    setupCharacterShader(dad, dadShader);
    setupCharacterShader(gf, gfShader);
}

function getEase(name:String, type:String)
{
    if (name == "linear")
        return FlxEase.linear;

    var easeName = name + (type == "linear" ? "" : type);
    var result = Reflect.field(FlxEase, easeName);

    return result ?? FlxEase.linear;
}

function onEvent(e)
{
    if (e == null || e.event == null)
        return;

    if (e.event.name != "Bad Apple Moment")
        return;

    var params:Array = e.event.params;

    if (params == null || params.length < 4)
        return;

    var active:Bool = params[0];
    var tweenSteps:Int = params[1];
    var easeName:String = params[2];
    var tweenType:String = params[3];

    var duration:Float = Conductor.stepCrochet / 1000 * tweenSteps;
    var ease = getEase(easeName, tweenType);

    var characters = [
        {key: "boyfriend", character: boyfriend, shader: bfShader},
        {key: "dad", character: dad, shader: dadShader},
        {key: "gf", character: gf, shader: gfShader}
    ];

    // Character shaders
    for (entry in characters)
    {
        var character = entry.character;
        var shader = entry.shader;
        var key:String = entry.key;

        if (character == null || shader == null)
            continue;

        if (shaderTweens.exists(key))
        {
            shaderTweens.get(key).cancel();
            shaderTweens.remove(key);
        }

        var iconColour:FlxColor = character.iconColor == null
            ? FlxColor.WHITE
            : character.iconColor;

        shader.replacementColor = [
            ((iconColour >> 16) & 0xFF) / 255.0,
            ((iconColour >> 8) & 0xFF) / 255.0,
            (iconColour & 0xFF) / 255.0
        ];

        var targetIntensity:Float = active ? 1.0 : 0.0;

        if (duration <= 0)
        {
            shader.intensity = targetIntensity;
        }
        else
        {
            shaderTweens.set(key, FlxTween.num(
                shader.intensity,
                targetIntensity,
                duration,
                {ease: ease},
                function(value:Float)
                {
                    shader.intensity = value;
                },
                function(_)
                {
                    shaderTweens.remove(key);
                }
            ));
        }
    }

    // Stage sprites
    for (name in stage.stageSprites.keys())
    {
        var sprite = stage.stageSprites.get(name);

        if (sprite == null
            || sprite == boyfriend
            || sprite == dad
            || sprite == gf)
            continue;

        if (!originalColours.exists(name))
            originalColours.set(name, sprite.color);

        if (worldTweens.exists(name))
        {
            worldTweens.get(name).cancel();
            worldTweens.remove(name);
        }

        var start:FlxColor = sprite.color;
        var targetColour:FlxColor = active
            ? FlxColor.BLACK
            : originalColours.get(name);

        if (duration <= 0)
        {
            sprite.color = targetColour;
        }
        else
        {
            worldTweens.set(name, FlxTween.num(
                0.0,
                1.0,
                duration,
                {ease: ease},
                function(value:Float)
                {
                    sprite.color = FlxColor.interpolate(
                        start, targetColour, value
                    );
                },
                function(_)
                {
                    worldTweens.remove(name);
                }
            ));
        }
    }

    // Health icon colours
    for (entry in characters)
    {
        var character = entry.character;
        var key:String = entry.key;

        if (character == null)
            continue;

        if (!originalIconColours.exists(key))
            originalIconColours.set(key, character.iconColor);

        if (iconTweens.exists(key))
        {
            iconTweens.get(key).cancel();
            iconTweens.remove(key);
        }

        var original = originalIconColours.get(key);

        var start:FlxColor = character.iconColor == null
            ? FlxColor.WHITE
            : character.iconColor;

        var target:FlxColor = active
            ? FlxColor.BLACK
            : (original == null ? FlxColor.WHITE : original);

        if (duration <= 0)
        {
            character.iconColor = active ? FlxColor.BLACK : original;
        }
        else
        {
            iconTweens.set(key, FlxTween.num(
                0.0,
                1.0,
                duration,
                {ease: ease},
                function(value:Float)
                {
                    character.iconColor = FlxColor.interpolate(
                        start, target, value
                    );
                },
                function(_)
                {
                    if (!active)
                        character.iconColor = original;

                    iconTweens.remove(key);
                }
            ));
        }
    }
}
