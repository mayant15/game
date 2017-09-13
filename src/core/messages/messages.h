#pragma once

HA_SUPPRESS_WARNINGS

// common
HA_CONST_MULTI_MSG_2(common, void, serialize_mixins, cstr, concrete_mixin, JsonData&, out)
HA_MULTI_MSG_1(common, void, deserialize_mixins, const sajson::value&, in)
HA_MULTI_MSG_3(common, void, set_attribute_mixins, cstr, mixin, cstr, attr, const sajson::value&,
               in)
HA_MULTI_MSG_0(common, void, imgui_bind_attributes_mixins)

// transform
HA_MSG_1(tr, void, set_pos, const yama::vector3&, pos)
HA_MSG_1(tr, void, set_scl, const yama::vector3&, scl)
HA_MSG_1(tr, void, set_rot, const yama::quaternion&, rot)
HA_CONST_MSG_0(tr, yama::vector3, get_pos)
HA_CONST_MSG_0(tr, yama::vector3, get_scl)
HA_CONST_MSG_0(tr, yama::quaternion, get_rot)
HA_MSG_1(tr, void, set_transform_local, const transform&, in)
HA_MSG_1(tr, void, set_transform, const transform&, in)
HA_CONST_MSG_0(tr, transform, get_transform_local)
HA_CONST_MSG_0(tr, transform, get_transform)
HA_MSG_1(tr, void, move, const yama::vector3&, pos)

#define Interface_transform                                                                        \
    tr::set_pos_msg& tr::set_scl_msg& tr::set_rot_msg& tr::get_pos_msg& tr::get_scl_msg&           \
            tr::get_rot_msg& tr::set_transform_local_msg& tr::set_transform_msg&                   \
                    tr::get_transform_local_msg& tr::get_transform_msg& tr::move_msg

// parental
DYNAMIX_EXPORTED_CONST_MESSAGE_0(HAPI, oid, get_parent)
DYNAMIX_EXPORTED_CONST_MESSAGE_0(HAPI, const std::vector<oid>&, get_children)
DYNAMIX_EXPORTED_MESSAGE_1(HAPI, void, set_parent, oid, _parent)

#define Interface_parental get_parent_msg& get_children_msg& set_parent_msg

// selected
HA_CONST_MULTI_MSG_0(sel, void, no_gizmo) // for simulating a mixin fact - see dynamix roadmap
HA_MSG_0(sel, transform&, get_transform_on_gizmo_start)
HA_MSG_0(sel, transform&, get_transform_local_on_gizmo_start)

#define Interface_selected                                                                         \
    sel::get_transform_on_gizmo_start_msg& sel::get_transform_local_on_gizmo_start_msg

HA_SUPPRESS_WARNINGS_END
