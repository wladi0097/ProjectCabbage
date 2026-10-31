# Shared by the desk assets: vertex-colour tinted machine_paint / machine_metal, as on the console.
E, K, H, R, F, B, P = range(7)   # enamel, bakelite, chrome, red bakelite, felt, brass, pale enamel
COLOURS = {E: (0.15, 0.19, 0.16), K: (0.025, 0.025, 0.024), H: (0.62, 0.63, 0.65), R: (0.32, 0.045, 0.035),
           F: (0.035, 0.035, 0.038), B: (0.55, 0.42, 0.2), P: (0.27, 0.31, 0.28)}
SURFACE = {E: 0, K: 0, H: 1, R: 0, F: 0, B: 1, P: 0}


def vc_textured(name, rough, metal, scale):
    m = material(name, (1, 1, 1), metal, rough)
    textured(m, name, scale)
    nt = m.node_tree
    mix = next(n for n in nt.nodes if n.bl_idname == "ShaderNodeMix")
    col = nt.nodes.new("ShaderNodeVertexColor"); col.layer_name = "Col"
    nt.links.new(col.outputs["Color"], mix.inputs["B"])
    return m


paint = vc_textured("machine_paint", 0.45, 0.0, 4.0)
metal = vc_textured("machine_metal", 0.3, 1.0, 4.0)


def colourise(ob):
    me = ob.data
    col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = me.color_attributes.find("Col")
    for poly in me.polygons:
        for li in poly.loop_indices:
            col.data[li].color = (*COLOURS[poly.material_index], 1)
        poly.material_index = SURFACE[poly.material_index]
