import bpy
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
ASSETS.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / "blender_source"
SOURCE.mkdir(parents=True, exist_ok=True)
TEXTURES = ASSETS / "textures"


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)


def mat(name, color, roughness=0.8, emission=0, texture=None):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    bsdf = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    if texture:
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        stem = TEXTURES / texture
        color_node = nodes.new("ShaderNodeTexImage")
        color_node.image = bpy.data.images.load(str(stem) + "_diff_1k.jpg", check_existing=True)
        links.new(color_node.outputs["Color"], bsdf.inputs["Base Color"])
        normal_node = nodes.new("ShaderNodeTexImage")
        normal_node.image = bpy.data.images.load(str(stem) + "_nor_gl_1k.jpg", check_existing=True)
        normal_node.image.colorspace_settings.name = "Non-Color"
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.inputs["Strength"].default_value = 0.55
        links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
        rough_path = Path(str(stem) + "_rough_1k.jpg")
        if rough_path.exists():
            rough_node = nodes.new("ShaderNodeTexImage")
            rough_node.image = bpy.data.images.load(str(rough_path), check_existing=True)
            rough_node.image.colorspace_settings.name = "Non-Color"
            links.new(rough_node.outputs["Color"], bsdf.inputs["Roughness"])
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return material


def cube(name, loc, scale, material, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    # Tile photographs by real-world size instead of stretching one image over a wall.
    uv_layer = obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        normal = polygon.normal
        for loop_index in polygon.loop_indices:
            vertex = obj.data.vertices[obj.data.loops[loop_index].vertex_index].co
            if abs(normal.z) > 0.5:
                u, v = vertex.x / 2.0, vertex.y / 2.0
            elif abs(normal.x) > 0.5:
                u, v = vertex.y / 2.0, vertex.z / 2.0
            else:
                u, v = vertex.x / 2.0, vertex.z / 2.0
            uv_layer.data[loop_index].uv = (u, v)
    if bevel:
        mod = obj.modifiers.new("Soft edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def cylinder(name, loc, radius, depth, material, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def sphere(name, loc, radius, material, segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return obj


def joint(name, loc):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.empty_display_size = 0.08
    return obj


def parent_keep(child, parent):
    world = child.matrix_world.copy()
    child.parent = parent
    child.matrix_world = world


def label(name, body, loc, size, material):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = 0.006
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.data.materials.append(material)
    obj.rotation_euler = (math.pi / 2, 0, 0)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)


clear()
wood = mat("warm cedar", (0.34, 0.24, 0.14), roughness=0.8)
wood_light = mat("aged cedar planks", (0.57, 0.43, 0.29), roughness=0.86, texture="wood_floor_worn")
tile = mat("stone tile", (0.36, 0.44, 0.42), roughness=0.45, texture="floor_tiles_04")
plaster = mat("warm plaster", (0.82, 0.75, 0.57))
washi = plaster.node_tree.nodes.new("ShaderNodeTexImage")
washi.image = bpy.data.images.load(str(TEXTURES / "washi_plaster.png"), check_existing=True)
plaster.node_tree.links.new(washi.outputs["Color"], next(node for node in plaster.node_tree.nodes if node.type == "BSDF_PRINCIPLED").inputs["Base Color"])
red = mat("women entrance curtain", (0.71, 0.20, 0.25))
blue = mat("men entrance curtain", (0.15, 0.36, 0.57))
cream = mat("paper lantern", (1.0, 0.79, 0.47), emission=0.45)
black = mat("ink", (0.07, 0.08, 0.09))
green = mat("foliage", (0.19, 0.39, 0.25))
gold = mat("brass", (0.83, 0.56, 0.2), roughness=0.35)
linen = mat("clean linen", (0.86, 0.83, 0.72), roughness=0.95)
glass = mat("mirror glass", (0.63, 0.75, 0.78), roughness=0.08)
charcoal = mat("dark slate", (0.13, 0.16, 0.17), roughness=0.65)
warm_recess = mat("warm cove lighting", (1.0, 0.72, 0.37), roughness=1.0, emission=1.3)

cube("stone floor", (0, 0, -0.15), (20, 24, 0.3), tile)
cube("dark floor joints", (0, 0, 0.002), (19.9, 23.7, 0.015), charcoal)
for x in range(-9, 10, 2):
    cube(f"floor plank {x}", (x, 0, 0.026), (1.985, 23.7, 0.03), wood_light)
for x in (-10, 10):
    cube(f"side wall {x}", (x, 0, 2.05), (0.3, 24, 4.1), plaster)
    cube(f"side baseboard {x}", (x * 0.982, 0, 0.18), (0.12, 24, 0.36), wood)
    for y in range(-10, 12, 4):
        cube(f"wall pillar {x} {y}", (x * 0.981, y, 2.05), (0.18, 0.22, 4.1), wood_light, 0.025)
    cube(f"side picture rail {x}", (x * 0.981, 0, 3.14), (0.13, 24, 0.1), wood)
cube("front wall", (0, -12, 2.05), (20, 0.3, 4.1), plaster)
for x, width in ((-8.5, 3), (0, 6), (8.5, 3)):
    cube(f"rear wall {x}", (x, 11.7, 2.05), (width, 0.35, 4.1), plaster)
for x in (-7, -3, 3, 7):
    cube(f"door post {x}", (x, 11.5, 1.4), (0.22, 0.5, 2.8), wood)
cube("rear beam", (0, 11.5, 3.92), (20, 0.5, 0.28), wood_light, 0.025)

# A taller ceiling, timber coffers and warm coves make the room feel like a ryokan lounge.
for y in range(-10, 12, 4):
    cube(f"coffer crossbeam {y}", (0, y, 3.96), (19.6, 0.24, 0.24), wood_light, 0.025)
for x in (-8.4, -4.2, 0, 4.2, 8.4):
    cube(f"coffer long beam {x}", (x, 0, 3.99), (0.16, 23.3, 0.18), wood_light, 0.02)
for x in (-8.8, 8.8):
    cube(f"cove side {x}", (x, 0, 3.85), (0.11, 22.6, 0.035), warm_recess)
for y in (-9.5, 8.8):
    cube(f"cove end {y}", (0, y, 3.85), (17.5, 0.11, 0.035), warm_recess)
for x, y in ((-4.5, -5), (0, -5), (4.5, -5), (-4.5, 3.5), (0, 3.5), (4.5, 3.5)):
    cylinder("pendant cord", (x, y, 3.48), 0.015, 0.65, charcoal, 12)
    cylinder("washi pendant", (x, y, 2.98), 0.26, 0.52, cream, 32)
    cylinder("pendant rim", (x, y, 2.72), 0.27, 0.025, wood, 32)

# The curtains mark the destination; the room beyond them is deliberately empty.
for center, fabric, title in ((-5, blue, "MEN"), (5, red, "WOMEN")):
    for i in range(4):
        cube(f"{title} curtain panel {i}", (center - 1.45 + i * 0.95, 11.35, 1.87),
             (0.88, 0.07, 1.7), fabric, 0.03)
    cube(f"{title} sign", (center, 11.2, 2.7), (3.4, 0.08, 0.5), wood, 0.04)
    label(f"{title} letters", title, (center - 1.15, 11.1, 2.57), 0.32, cream)
    cube(f"{title} door mat", (center, 9.7, 0.04), (3.5, 2.4, 0.08), fabric)

cube("reception counter", (4.4, -4.0, 0.56), (3.6, 1.05, 1.12), wood, 0.08)
cube("reception counter top", (4.4, -4.0, 1.17), (3.9, 1.24, 0.11), wood_light, 0.06)
for x in (2.9, 3.5, 5.3, 5.9):
    cube(f"counter joinery {x}", (x, -4.55, 0.59), (0.055, 0.08, 1.02), gold)
cube("service bell base", (5.7, -4.0, 1.27), (0.34, 0.34, 0.05), gold, 0.02)
sphere("service bell", (5.7, -4.0, 1.41), 0.17, gold, 20, 12)
cube("welcome sign", (4.4, -4.57, 0.67), (2.2, 0.06, 0.42), black, 0.02)
label("welcome letters", "ONSEN", (3.53, -4.63, 0.60), 0.27, cream)

for x, y, width in ((-6.8, 7.0, 2.4), (6.8, 6.0, 2.4)):
    cube(f"privacy screen {x}", (x, y, 1.05), (width, 0.22, 2.1), wood, 0.04)
    cube(f"privacy screen inset {x}", (x, y - 0.13, 1.1), (width - 0.25, 0.04, 1.5), plaster)
    for offset in (-0.35, 0.35):
        cube(f"screen lattice {x} {offset}", (x + offset * width, y - 0.18, 1.1), (0.055, 0.05, 1.5), wood)
    for height in (0.7, 1.45):
        cube(f"screen crossbar {x} {height}", (x, y - 0.18, height), (width - 0.25, 0.05, 0.05), wood)

# Detailed lounge chairs and table are instanced as CC0 glTF assets in Godot.

# Benches, towels, a changing mirror and woven baskets make the lobby read as a bathhouse.
for x, y in ((-7.8, -1.8), (7.8, -1.8)):
    cube("waiting bench seat", (x, y, 0.55), (2.5, 0.6, 0.15), wood_light, 0.05)
    for dx in (-1.0, 1.0):
        cube("waiting bench leg", (x + dx, y, 0.28), (0.13, 0.45, 0.5), wood)
    for i in range(3):
        cube("folded towel", (x - 0.7 + 0.55 * i, y, 0.69 + 0.04 * i),
             (0.45, 0.35, 0.07), linen, 0.02)
cube("mirror frame", (-8.9, 2.0, 1.55), (0.1, 1.9, 2.4), wood, 0.04)
cube("mirror pane", (-8.83, 2.0, 1.55), (0.02, 1.67, 2.13), glass)
cube("mirror stool", (-7.5, 2.0, 0.48), (0.8, 0.8, 0.96), wood_light, 0.07)
for x, y in ((-6.7, 6.7), (6.7, 6.7)):
    cylinder("towel basket", (x, y, 0.42), 0.48, 0.83, wood, 16)
    cube("basket towel", (x, y, 0.87), (0.55, 0.55, 0.12), linen, 0.04)
for x, y in ((-7.6, -2.0), (7.6, -2.0), (-7.6, 8.8), (7.6, 8.8)):
    cube("lantern stand", (x, y, 0.79), (0.09, 0.09, 1.58), charcoal, 0.01)
    cube("washi floor lantern", (x, y, 1.67), (0.54, 0.54, 0.65), cream, 0.025)
    cube("lantern cap", (x, y, 2.02), (0.6, 0.6, 0.08), wood, 0.015)

bpy.ops.object.light_add(type="AREA", location=(0, -2, 10))
bpy.context.object.name = "lobby warm light"
bpy.context.object.data.energy = 1400
bpy.context.object.data.shape = "DISK"
bpy.context.object.data.size = 12
bpy.ops.object.camera_add(location=(0, -18, 18))
bpy.context.object.rotation_euler = (math.radians(47), 0, 0)
bpy.context.scene.camera = bpy.context.object
bpy.context.scene.render.engine = "BLENDER_EEVEE"
bpy.context.scene.render.resolution_x = 1200
bpy.context.scene.render.resolution_y = 900
bpy.context.scene.render.resolution_percentage = 100
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "onsen_lobby.blend"))
bpy.ops.export_scene.gltf(filepath=str(ASSETS / "onsen_lobby.glb"), export_format="GLB", export_cameras=False, export_lights=False)


def character(name, robe_color, hair_color):
    clear()
    skin = mat("warm skin", (0.67, 0.43, 0.31), roughness=0.8)
    robe = mat("cotton robe", robe_color, roughness=0.94)
    hair = mat("hair", hair_color, roughness=0.82)
    sash = mat("obi", (0.83, 0.70, 0.50), roughness=0.91)
    dark = mat("eyes and sandals", (0.06, 0.07, 0.08))
    lip = mat("lip", (0.49, 0.22, 0.20))
    root = joint("body_root", (0, 0, 0))
    torso = cylinder("robe torso", (0, 0, 1.09), 0.36, 1.12, robe, 20)
    torso.scale.x = 1.1
    parent_keep(torso, root)
    parent_keep(cube("obi belt", (0, 0, 1.1), (0.81, 0.56, 0.18), sash, 0.045), root)
    parent_keep(cube("robe collar left", (-0.13, -0.29, 1.56), (0.13, 0.08, 0.4), sash, 0.02), root)
    parent_keep(cube("robe collar right", (0.13, -0.29, 1.56), (0.13, 0.08, 0.4), sash, 0.02), root)
    parent_keep(cylinder("neck", (0, 0, 1.72), 0.12, 0.20, skin, 16), root)
    head_joint = joint("head_joint", (0, 0, 1.76))
    parent_keep(head_joint, root)
    face = sphere("face", (0, -0.035, 1.9), 0.22, skin, 24, 16)
    face.scale.y = 0.9
    face.scale.z = 1.12
    parent_keep(face, head_joint)
    for x in (-0.12, 0.12):
        parent_keep(sphere("eye", (x * 0.68, -0.233, 1.95), 0.017, dark, 12, 8), head_joint)
        parent_keep(sphere("ear", (x * 1.85, 0.0, 1.89), 0.052, skin, 12, 8), head_joint)
    nose = sphere("nose", (0, -0.245, 1.87), 0.04, skin, 12, 8)
    nose.scale.y = 1.55
    parent_keep(nose, head_joint)
    mouth = cube("mouth", (0, -0.236, 1.77), (0.08, 0.012, 0.012), lip)
    parent_keep(mouth, head_joint)
    cap = sphere("hair cap", (0, 0.065, 2.06), 0.235, hair, 24, 16)
    cap.scale.y = 0.94
    parent_keep(cap, head_joint)
    if name == "player":
        for x in (-0.20, 0.20):
            lock = sphere("wig side lock", (x, 0.02, 1.86), 0.095, hair, 16, 10)
            lock.scale.z = 2.0
            parent_keep(lock, head_joint)
        back = sphere("wig back hair", (0, 0.16, 1.82), 0.19, hair, 18, 12)
        back.scale.z = 1.3
        parent_keep(back, head_joint)
    else:
        cap_mat = mat("staff headband", (0.11, 0.18, 0.23))
        parent_keep(cylinder("staff cap", (0, 0, 2.17), 0.23, 0.08, cap_mat, 20), head_joint)
    for side, x in (("left", -0.18), ("right", 0.18)):
        hip = joint(f"{side}_hip", (x, 0, 0.62))
        parent_keep(hip, root)
        upper = cylinder(f"{side}_leg", (x, 0, 0.40), 0.12, 0.45, robe, 14)
        parent_keep(upper, hip)
        knee = joint(f"{side}_knee", (x, 0, 0.21))
        parent_keep(knee, hip)
        parent_keep(cube(f"{side}_sandal", (x, -0.10, 0.08), (0.24, 0.42, 0.15), dark, 0.04), knee)
    for side, x in (("left", -0.39), ("right", 0.39)):
        shoulder = joint(f"{side}_shoulder", (x, 0, 1.52))
        parent_keep(shoulder, root)
        sleeve = cube(f"{side}_sleeve", (x * 1.12, 0, 1.25), (0.30, 0.43, 0.53), robe, 0.06)
        parent_keep(sleeve, shoulder)
        hand = sphere(f"{side}_hand", (x * 1.18, -0.03, 0.96), 0.09, skin, 16, 10)
        parent_keep(hand, shoulder)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(ASSETS / f"{name}.glb"), export_format="GLB")


character("player", (0.29, 0.17, 0.28), (0.21, 0.13, 0.09))
character("attendant", (0.15, 0.35, 0.47), (0.10, 0.09, 0.08))
print("Created Blender files and GLB assets in", ROOT)
