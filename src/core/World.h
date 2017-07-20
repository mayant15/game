#pragma once

class HAPI World : public Singleton<World>
{
    HA_SINGLETON(World);

private:
    float m_width  = 100.f;
    float m_height = 100.f;

    eid    m_camera;
    Entity m_editor;

public:
    World();

    void update();

    eid     camera() const { return m_camera; }
    Entity& editor() { return m_editor; }

    float width() const { return m_width; }
    float height() const { return m_height; }
};
