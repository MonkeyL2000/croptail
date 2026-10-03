#!/usr/bin/env python3
"""重新生成 scenes/characters/player.tscn(动画 + 碰撞 + 相机)。

手写 .tscn 里的 80 个 AtlasTexture 不现实,所以场景由这个脚本生成。
改动画只要改下面的表,然后:

    python tools/gen_player_scene.py

## 两个素材

1. `Basic Charakter Spritesheet.png` (192x192) = 4x4 格、每格 48x48。
   行 = 朝向:0 down / 1 up / 2 left / 3 right。列 = 帧:0,1 待机;2,3 走路。

2. `Basic Charakter Actions.png` (96x576) = **2 列 x 12 行**、每格 48x48。

   真实版式(2026-10 实测,踩过两次坑):**2 列 = 一个动作的两帧**;
   12 行 = **3 个动作 x 4 个朝向**,每 4 行一组,组内顺序和立绘表一样
   (行 0/1/2/3 = 前 / 后 / 左 / 右)。

   ⚠️ 坑 1:曾把一行当成一个动作的 4 帧,去取 x=96/144 —— 图集只有 96 宽,
   x>=96 在图外,动画后两帧是空的。
   ⚠️ 坑 2:曾把「行 2b、2b+1 两行 = 一个动作的 4 帧」当成一个块,于是
   `use_*_left` / `use_*_right` 拿到同一块 = 同一个动画,而且里面
   左一帧、右一帧交替(**看起来朝两边挥**)——就是用户报的那个 bug。

   怎么确认版式的(可复现,不是猜):
   - 块内的行两两比对,`d(帧0, mirror(帧2)) == 0.00` => 这两行是**互为镜像的一对**,
     也就是两个朝向,不是同一朝向的两帧。行 2/3、6/7、10/11 都是精确镜像对。
   - 行 0/1/4/5/8/9 的头是左右对称、居中且带两个耳朵状凸起 => 前/后视图;
     行 2/3/6/7/10/11 的头明显偏一侧、窄 => 左/右视图。
   - 前/后靠**脸上那几颗肤色像素**分(立绘表里 front 头部有 (232,181,172) x8,back 是 0):
     行 0/4/8 有 5~8 颗 => front,行 1/5/9 是 0 颗 => back。
   - 组内顺序据此 = 前 / 后 / 左 / 右,与立绘表 ROW 一致。
     左/右两行本身是精确镜像(立绘表也是 0.00),**左右谁在前是画师的约定**,跟立绘表取同一约定;
     若哪天发现左右反了,交换 DIR_ROW 里的 left/right 即可。

   哪个动作是哪个工具(靠手里那件东西的像素):

       动作 A(行 0-3)  金属 92px / 木 56px,长柄 + 箍,从**头顶**抡到地面 => 锄头
       动作 B(行 4-7)  金属 134px / 木 55px,从**体侧**扫到地面       => 镰刀,给收割
       动作 C(行 8-11) 纯金属 432px / **木 0px**,大件、在身前低位倾倒 => 洒水壶

   立绘表的左/右两行也是精确镜像,所以左右只是约定 —— 靠上面这几条像素证据定版式,
   不靠「看起来像」。想改:只动 TOOL_ACTION 这张表。
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

## 工具号(1..4) -> 动作用哪 4 行(组的**起始行**)
TOOL_ACTION = {
    1: 0,   # 锄头        -> 行 0..3
    2: 8,   # 洒水壶      -> 行 8..11(纯金属,在身前低位)
    3: 4,   # 种子:B 从体侧扫下,最接近播种的手部动作(图集没有专门播种动作)
    4: 4,   # 收割:B(镰刀那套,从体侧扫到地面)
    5: 0,   # 斧头:A 过顶挥砍 —— 砍树就是这个动作。素材包免费版没有「砍」的专用动作
    6: 0,   # 镐头:同上。挥舞轨迹和锄头一样,三个动作里最接近的是它
}
## 朝向 -> 组内第几行
DIR_ROW = {'front': 0, 'back': 1, 'left': 2, 'right': 3}
USE_SPEED = 7.0

CAMERA_POSITION = (0, -6)


def row_frames(row):
    """一行的 2 帧 —— 一个朝向的整个动作。"""
    return [(0, row * 48), (48, row * 48)]


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
        base = TOOL_ACTION[tool]
        for d in DIRS:
            add_anim('use_%d_%s' % (tool, d), '2_tex', row_frames(base + DIR_ROW[d]), USE_SPEED)

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
