#!/usr/bin/env python3
"""重新生成 scenes/characters/player.tscn(动画 + 碰撞 + 相机)。

手写 .tscn 里的 80 个 AtlasTexture 不现实,所以场景由这个脚本生成。
改动画只要改下面的表,然后:

    python tools/gen_player_scene.py

## 两个素材

1. `Basic Charakter Spritesheet.png` (192x192) = 4x4 格、每格 48x48。
   行 = 朝向:0 down / 1 up / 2 left / 3 right。列 = 帧:0,1 待机;2,3 走路。

2. `Basic Charakter Actions.png` (96x576) = **2 列 x 12 行**、每格 48x48。
   一个动作 4 帧,排成 **2x2 的小块**:块 b 占第 2b、2b+1 行,每行 2 帧。
   => 一共 6 个动作块。

   ⚠️ 以前这里搞错了:把一行当成一个动作的 4 帧,于是去取 x=96/144 ——
   而图集只有 96 像素宽,x>=96 直接在图外,动画后两帧是空的。
   这是「工具动作看起来不对」的真正原因(见 docs/DECISIONS.md#action-blocks)。

   6 个块的朝向是**交替**的(实测:偶数块朝上下,奇数块朝左右),所以是
   「3 个动作 x 2 个朝向组」:

       块 0/1 = 动作 A(上下 / 左右)      块 2/3 = 动作 B(上下 / 左右)
       块 4/5 = 动作 C(上下 / 左右)

   哪块是哪个工具没有官方说明:靠**调色板**判的(见 docs/DECISIONS.md#tools-sheet)。
   块 4/5 手里那个东西是纯金属灰(84,89,89 / 107,116,112 / 129,139,131 / 157,168,154),
   和 Tools.png 里唯一的纯金属工具同色 => 洒水壶。剩下两个是「金属头 + 木柄」的工具。

   想改:只动 TOOL_ACTION 这张表。
"""
import os

SHEET = ('b2lkv8u83ldqq', 'res://game_source/Characters/Basic Charakter Spritesheet.png')
ACTIONS = ('bq6aybu6fhqi4', 'res://game_source/Characters/Basic Charakter Actions.png')

DIRS = ['front', 'back', 'left', 'right']
ROW = {'front': 0, 'back': 1, 'left': 2, 'right': 3}

SIMPLE = [
    ('idle', SHEET, [0, 48], 3.0),
    ('walk', SHEET, [96, 144], 5.0),
]

## 工具号(1..4) -> {「上下朝」用的动作块, 「左右朝」用的动作块}
TOOL_ACTION = {
    1: (0, 1),   # 锄头
    2: (4, 5),   # 洒水壶(纯金属)
    3: (2, 3),   # 种子
    4: (0, 1),   # 收获:图集里没有第 4 个动作,借用锄头那套
}
USE_SPEED = 7.0

CAMERA_POSITION = (0, -6)


def block_frames(block):
    """动作块的 4 帧 = 2x2,行优先。"""
    frames = []
    for row in (block * 2, block * 2 + 1):
        for col in (0, 1):
            frames.append((col * 48, row * 48))
    return frames


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ext = []
    for i, (uid, path) in enumerate([SHEET, ACTIONS], start=1):
        ext.append('[ext_resource type="Texture2D" uid="uid://%s" path="%s" id="%d_tex"]' % (uid, path, i))
    ext.append('[ext_resource type="Script" path="res://scripts/player/player.gd" id="1_player"]')
    ext.append('[ext_resource type="Script" path="res://scripts/state_machine/node_finite_state_machine.gd" id="2_fsm"]')
    ext.append('[ext_resource type="Script" path="res://scripts/player/idle_state.gd" id="3_idle"]')
    ext.append('[ext_resource type="Script" path="res://scripts/player/walk_state.gd" id="4_walk"]')
    ext.append('[ext_resource type="Script" path="res://scripts/player/use_state.gd" id="5_use"]')

    atlas_blocks = []
    anims = []
    counter = [0]

    def add_anim(name, src_id, frames, speed):
        ids = []
        for (x, y) in frames:
            counter[0] += 1
            aid = 'AtlasTexture_%s_%d' % (name, counter[0])
            atlas_blocks.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = Rect2(%d, %d, 48, 48)\n' % (aid, src_id, x, y))
            ids.append(aid)
        body = ",\n".join(['{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % f for f in ids])
        anims.append('{\n"frames": [\n%s\n],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (body, name, speed))

    for kind, (_, _path), xs, speed in SIMPLE:
        for d in DIRS:
            add_anim('%s_%s' % (kind, d), '1_tex', [(x, ROW[d] * 48) for x in xs], speed)

    for tool in sorted(TOOL_ACTION):
        vertical, horizontal = TOOL_ACTION[tool]
        for d in DIRS:
            block = vertical if d in ('front', 'back') else horizontal
            add_anim('use_%d_%s' % (tool, d), '2_tex', block_frames(block), USE_SPEED)

    sprite_frames = ('[sub_resource type="SpriteFrames" id="SpriteFrames_player"]\nanimations = ['
                     + ", ".join(anims) + ']\n')
    circle = '[sub_resource type="CircleShape2D" id="CircleShape2D_body"]\nradius = 5.0\n'
    load_steps = 1 + len(ext) + len(atlas_blocks) + 2

    doc = ['[gd_scene load_steps=%d format=3 uid="uid://04ftqh3rmnjo"]\n' % load_steps]
    doc.append("\n" + "\n".join(ext) + "\n")
    doc.append("\n" + "\n".join(atlas_blocks))
    doc.append("\n" + sprite_frames)
    doc.append("\n" + circle)
    doc.append('\n[node name="player" type="CharacterBody2D"]\nscript = ExtResource("1_player")\n')
    doc.append('\n[node name="Camera2D" type="Camera2D" parent="."]\nposition = Vector2(%d, %d)\n'
               'position_smoothing_enabled = true\nposition_smoothing_speed = 8.0\n' % CAMERA_POSITION)
    doc.append('\n[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\n'
               'sprite_frames = SubResource("SpriteFrames_player")\nanimation = &"idle_front"\nautoplay = "idle_front"\n')
    doc.append('\n[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\n'
               'position = Vector2(0, 6)\nshape = SubResource("CircleShape2D_body")\n')
    doc.append('\n[node name="StateMachine" type="Node" parent="." node_paths=PackedStringArray("initial_state")]\n'
               'script = ExtResource("2_fsm")\ninitial_state = NodePath("idle")\n')
    for state, script in [('idle', '3_idle'), ('walk', '4_walk'), ('use', '5_use')]:
        doc.append('\n[node name="%s" type="Node" parent="StateMachine" node_paths=PackedStringArray("player")]\n'
                   'script = ExtResource("%s")\nplayer = NodePath("../..")\n' % (state, script))

    out = os.path.join(root, 'scenes/characters/player.tscn')
    with open(out, 'w', newline='\n') as f:
        f.write("".join(doc))
    print("player.tscn: %d animations, %d atlas textures, load_steps=%d" % (len(anims), len(atlas_blocks), load_steps))


if __name__ == "__main__":
    main()
